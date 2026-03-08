import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../../finances/providers/finance_providers.dart';
import '../../finances/models/finance_models.dart';
import '../models/calendar_event.dart';
import '../services/calendar_service.dart';
import '../services/firestore_calendar_service.dart';

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
    final customEvents = await ref.read(calendarServiceProvider).getEvents();

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

    return [...customEvents, ...taskEvents, ...financeEvents]
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<void> addEvent(CalendarEvent event) async {
    await ref.read(calendarServiceProvider).addEvent(event);
    ref.invalidateSelf();
  }

  Future<void> updateEvent(CalendarEvent event) async {
    await ref.read(calendarServiceProvider).updateEvent(event);
    ref.invalidateSelf();
  }

  Future<void> deleteEvent(String id) async {
    await ref.read(calendarServiceProvider).deleteEvent(id);
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
