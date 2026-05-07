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

final calendarServiceProvider = Provider<CalendarService>((ref) {
  if (AppConfig.useFirebase) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return FirestoreCalendarService(userId);
  }
  return MockCalendarService();
});

class CalendarEventsNotifier extends AsyncNotifier<List<CalendarEvent>> {
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
