import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../services/image_upload_service.dart';
import '../../../services/log_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../../finances/models/finance_models.dart';
import '../../finances/providers/finance_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../models/calendar_event.dart';
import '../services/calendar_service.dart';
import '../services/firestore_calendar_service.dart';
import 'google_calendar_providers.dart';

/// Result of [CalendarEventsNotifier.syncFromGoogle].
class GoogleSyncResult {
  final int patched;
  final int deleted;
  const GoogleSyncResult({required this.patched, required this.deleted});
}

final calendarServiceProvider = Provider<CalendarService>((ref) {
  if (AppConfig.useFirebase) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return FirestoreCalendarService(userId);
  }
  return MockCalendarService();
});

class CalendarEventsNotifier extends AsyncNotifier<List<CalendarEvent>> {
  bool _syncing = false;
  DateTime? _lastSyncAt;
  static const _autoSyncCooldown = Duration(seconds: 10);

  @override
  Future<List<CalendarEvent>> build() async {
    // Watch sync-derived providers only — no FutureProvider dependencies here.
    // Mixing await + ref.watch(FutureProvider) causes ConcurrentModificationError
    // in Riverpod's listener graph. Google events are merged in allCalendarEventsProvider.
    final service = ref.watch(calendarServiceProvider);
    final tasks = ref.watch(taskListProvider).valueOrNull ?? [];
    final transactions = ref.watch(transactionListProvider).valueOrNull ?? [];

    final customEvents = await service.getEvents();

    final taskEvents = tasks
        .where((t) => t.dueDate != null && !t.isCompleted)
        .map(
          (t) => CalendarEvent(
            id: 'task_${t.id}',
            title: t.title,
            description: t.description,
            date: t.dueDate!,
            type: EventType.task,
            sourceId: t.id,
            color: '0xFFFF9800',
          ),
        )
        .toList();

    final financeEvents = transactions
        .where((t) => t.isRecurring)
        .map(
          (t) => CalendarEvent(
            id: 'fin_${t.id}',
            title: '${t.type == TransactionType.income ? '+' : '-'} ${t.title}',
            date: t.date,
            type: EventType.finance,
            sourceId: t.id,
            color: t.type == TransactionType.income
                ? '0xFF4CAF50'
                : '0xFFF44336',
          ),
        )
        .toList();

    LogService.instance.info(
      'Calendar built: ${customEvents.length} custom, '
      '${taskEvents.length} tasks, ${financeEvents.length} finance',
    );

    return [...customEvents, ...taskEvents, ...financeEvents]
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<void> addEvent(CalendarEvent event) async {
    final service = ref.read(calendarServiceProvider);
    await service.addEvent(event);
    LogService.instance.info('Calendar event created: ${event.title}');

    final connected = ref.read(googleCalendarConnectedProvider);
    final syncEnabled =
        ref.read(currentUserProvider)?.settings.syncToGoogleCalendar ?? true;
    if (connected && syncEnabled) {
      final googleId = await ref
          .read(googleCalendarServiceProvider)
          .createEvent(event);
      if (googleId != null) {
        // Persist the Google ID on the local copy so future fetches dedup
        // and subsequent edits/deletes can reach the Google event.
        await service.updateEvent(event.copyWith(googleEventId: googleId));
      }
    }

    ref.invalidateSelf();
  }

  Future<void> updateEvent(CalendarEvent event) async {
    await ref.read(calendarServiceProvider).updateEvent(event);
    LogService.instance.info('Calendar event updated: ${event.id}');

    final connected = ref.read(googleCalendarConnectedProvider);
    if (connected && event.googleEventId != null) {
      await ref
          .read(googleCalendarServiceProvider)
          .updateEvent(event.googleEventId!, event);
    }
    ref.invalidateSelf();
  }

  /// Pulls fresh Google Calendar data and reconciles linked local events.
  /// Google is treated as last-write-wins for title, description, date,
  /// endDate, and isAllDay; local-only fields (imageUrls, sourceId, color)
  /// are preserved. Linked locals whose date falls inside the fetch window
  /// but no longer exist in Google are deleted locally too. No-ops when
  /// not connected.
  Future<GoogleSyncResult> syncFromGoogle({bool force = false}) async {
    final connected = ref.read(googleCalendarConnectedProvider);
    if (!connected) return const GoogleSyncResult(patched: 0, deleted: 0);
    // Re-entry guard: if a sync is already running, skip rather than fire a
    // second concurrent fetch. Prevents the OAuth-popup loop from BUG-0032
    // where lifecycle resume kept stacking sync calls on top of each other.
    if (_syncing) return const GoogleSyncResult(patched: 0, deleted: 0);
    // Cooldown: automatic triggers can fire in bursts (initial-on-connect +
    // calendar-page-mount + provider listeners all colliding). Skip auto
    // syncs that arrive within [_autoSyncCooldown] of the previous one.
    // The manual "Sync from Google now" action passes force: true.
    if (!force && _lastSyncAt != null) {
      final since = DateTime.now().difference(_lastSyncAt!);
      if (since < _autoSyncCooldown) {
        return const GoogleSyncResult(patched: 0, deleted: 0);
      }
    }
    _syncing = true;
    _lastSyncAt = DateTime.now();
    try {
      ref.invalidate(googleCalendarEventsProvider);
      final googleEvents = await ref.read(googleCalendarEventsProvider.future);
      final localEvents = state.valueOrNull ?? [];
      final byGoogleId = <String, CalendarEvent>{
        for (final g in googleEvents)
          if (g.id.startsWith('gcal_')) g.id.substring(5): g,
      };

      // Window the Google fetch covers (must match googleCalendarEventsProvider)
      final now = DateTime.now();
      final windowStart = DateTime(now.year, now.month - 1, 1);
      final windowEnd = DateTime(now.year, now.month + 2, 0);

      final service = ref.read(calendarServiceProvider);
      var patched = 0;
      var deleted = 0;
      for (final local in localEvents) {
        final gid = local.googleEventId;
        if (gid == null) continue;
        final google = byGoogleId[gid];
        if (google == null) {
          // Possibly deleted on Google — only act if the event sat inside the
          // window we actually fetched. Outside the window the absence is
          // ambiguous.
          final inWindow =
              !local.date.isBefore(windowStart) &&
              local.date.isBefore(windowEnd);
          if (inWindow) {
            await service.deleteEvent(local.id);
            deleted++;
          }
          continue;
        }
        if (_isInSyncWithGoogle(local, google)) continue;

        final updated = local.copyWith(
          title: google.title,
          description: google.description,
          clearDescription: google.description == null,
          date: google.date,
          endDate: google.endDate,
          clearEndDate: google.endDate == null,
          isAllDay: google.isAllDay,
        );
        await service.updateEvent(updated);
        patched++;
      }
      if (patched > 0 || deleted > 0) {
        LogService.instance.info(
          'Calendar sync from Google: patched $patched, deleted $deleted',
        );
        ref.invalidateSelf();
      }
      return GoogleSyncResult(patched: patched, deleted: deleted);
    } finally {
      _syncing = false;
    }
  }

  static bool _isInSyncWithGoogle(CalendarEvent local, CalendarEvent google) {
    return local.title == google.title &&
        (local.description ?? '') == (google.description ?? '') &&
        _sameMoment(local.date, google.date) &&
        _sameMoment(local.endDate, google.endDate) &&
        local.isAllDay == google.isAllDay;
  }

  /// Compare two [DateTime]s by their absolute moment in time rather than
  /// Dart's default == (which considers `isUtc`). Without this, a naive
  /// DateTime read back from Firestore won't equal Google's `.toLocal()`'d
  /// DateTime even when they represent the same instant — causing
  /// syncFromGoogle to patch the same event on every poll forever.
  static bool _sameMoment(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.microsecondsSinceEpoch == b.microsecondsSinceEpoch;
  }

  Future<void> deleteEvent(String id) async {
    final events = state.valueOrNull ?? [];
    final event = events.where((e) => e.id == id).firstOrNull;
    if (event != null && event.imageUrls.isNotEmpty) {
      final uploader = ref.read(imageUploadServiceProvider);
      for (final url in event.imageUrls) {
        await uploader.deleteImage(url);
      }
    }
    await ref.read(calendarServiceProvider).deleteEvent(id);
    LogService.instance.info('Calendar event deleted: $id');

    final connected = ref.read(googleCalendarConnectedProvider);
    if (connected && event?.googleEventId != null) {
      await ref
          .read(googleCalendarServiceProvider)
          .deleteEvent(event!.googleEventId!);
    }
    ref.invalidateSelf();
  }
}

final calendarEventsProvider =
    AsyncNotifierProvider<CalendarEventsNotifier, List<CalendarEvent>>(
      CalendarEventsNotifier.new,
    );

/// Merges local events (Firestore + tasks + finance) with Google Calendar events.
/// Kept as a sync Provider so it never participates in the async rebuild cycle
/// that causes ConcurrentModificationError in Riverpod's listener graph.
///
/// Dedups by [CalendarEvent.googleEventId]: any Google event whose raw ID is
/// already referenced by a local event is dropped from the merge so synced
/// events appear exactly once. Local events are preserved as-is so any
/// app-only fields (imageUrls, sourceId) stay visible.
final allCalendarEventsProvider = Provider<AsyncValue<List<CalendarEvent>>>((
  ref,
) {
  final base = ref.watch(calendarEventsProvider);
  final google = ref.watch(googleCalendarEventsProvider);

  return base.whenData((baseEvents) {
    final googleEvents = google.valueOrNull ?? [];
    final linkedGoogleIds = <String>{
      for (final e in baseEvents)
        if (e.googleEventId != null) e.googleEventId!,
    };
    final filteredGoogle = linkedGoogleIds.isEmpty
        ? googleEvents
        : googleEvents.where((g) {
            // Display IDs are prefixed `gcal_<rawId>` — strip the prefix.
            const prefix = 'gcal_';
            final raw = g.id.startsWith(prefix)
                ? g.id.substring(prefix.length)
                : g.id;
            return !linkedGoogleIds.contains(raw);
          }).toList();
    final combined = [...baseEvents, ...filteredGoogle];
    combined.sort((a, b) => a.date.compareTo(b.date));
    return combined;
  });
});

/// Events grouped by day for calendar marker display.
final calendarEventsByDayProvider =
    Provider<AsyncValue<Map<DateTime, List<CalendarEvent>>>>((ref) {
      return ref.watch(allCalendarEventsProvider).whenData((events) {
        final Map<DateTime, List<CalendarEvent>> result = {};
        for (final event in events) {
          final day = DateTime(
            event.date.year,
            event.date.month,
            event.date.day,
          );
          result.putIfAbsent(day, () => []).add(event);
        }
        return result;
      });
    });

final selectedDayProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final selectedDayEventsProvider = Provider<List<CalendarEvent>>((ref) {
  final day = ref.watch(selectedDayProvider);
  final eventsByDay = ref.watch(calendarEventsByDayProvider);
  return eventsByDay.valueOrNull?[day] ?? [];
});

/// Events for the current week (Monday–Sunday).
final thisWeekEventsProvider = Provider<List<CalendarEvent>>((ref) {
  final events = ref.watch(allCalendarEventsProvider).valueOrNull ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: now.weekday - 1));
  final sunday = monday.add(const Duration(days: 7));

  return events.where((e) {
    final d = DateTime(e.date.year, e.date.month, e.date.day);
    return !d.isBefore(monday) && d.isBefore(sunday);
  }).toList()..sort((a, b) => a.date.compareTo(b.date));
});
