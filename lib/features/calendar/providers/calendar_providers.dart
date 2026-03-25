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
    final customEvents = await ref.watch(calendarServiceProvider).getEvents();

    // Pull task due dates as events
    final tasks = ref.watch(taskListProvider).valueOrNull ?? [];
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

    // Pull recurring transactions as events
    final transactions = ref.watch(transactionListProvider).valueOrNull ?? [];
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

    // Pull Google Calendar events
    final googleEvents =
        ref.watch(googleCalendarEventsProvider).valueOrNull ?? [];

    return [...customEvents, ...taskEvents, ...financeEvents, ...googleEvents]
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<void> addEvent(CalendarEvent event) async {
    await ref.read(calendarServiceProvider).addEvent(event);
    LogService.instance.info('Calendar event created: ${event.title}');
    ref.invalidateSelf();
  }

  Future<void> updateEvent(CalendarEvent event) async {
    await ref.read(calendarServiceProvider).updateEvent(event);
    LogService.instance.info('Calendar event updated: ${event.id}');
    ref.invalidateSelf();
  }

  Future<void> deleteEvent(String id) async {
    // Delete associated images from Storage
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
    ref.invalidateSelf();
  }
}

final calendarEventsProvider =
    AsyncNotifierProvider<CalendarEventsNotifier, List<CalendarEvent>>(
      CalendarEventsNotifier.new,
    );

/// Events grouped by day for calendar marker display.
final calendarEventsByDayProvider =
    Provider<AsyncValue<Map<DateTime, List<CalendarEvent>>>>((ref) {
      return ref.watch(calendarEventsProvider).whenData((events) {
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
  final events = ref.watch(calendarEventsProvider).valueOrNull ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // Monday = 1, so subtract (weekday - 1) to get Monday
  final monday = today.subtract(Duration(days: now.weekday - 1));
  final sunday = monday.add(const Duration(days: 7));

  return events.where((e) {
    final d = DateTime(e.date.year, e.date.month, e.date.day);
    return !d.isBefore(monday) && d.isBefore(sunday);
  }).toList()..sort((a, b) => a.date.compareTo(b.date));
});
