import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:personal_app/presentation/widgets/app_snackbar.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/calendar_event.dart';
import '../providers/calendar_providers.dart';
import '../providers/google_calendar_providers.dart';
import '../services/google_calendar_service.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tryRestoreGoogleCalendar();
  }

  Future<void> _tryRestoreGoogleCalendar() async {
    final service = ref.read(googleCalendarServiceProvider);
    final wasConnected = await service.isConnected;
    if (wasConnected) {
      final success = await service.trySilentSignIn();
      if (success && mounted) {
        ref.read(googleCalendarConnectedProvider.notifier).state = true;
      }
    }
  }

  Future<void> _toggleGoogleCalendar() async {
    if (!GoogleCalendarService.isSupported) {
      context.showSnackbar(
        'Google Calendar is not supported on this platform. '
        'Use Android, iOS, macOS, or web.',
      );
      return;
    }

    final service = ref.read(googleCalendarServiceProvider);
    final connected = ref.read(googleCalendarConnectedProvider);

    if (connected) {
      await service.disconnect();
      if (!mounted) return;
      ref.read(googleCalendarConnectedProvider.notifier).state = false;
      context.showSnackbar('Google Calendar disconnected');
    } else {
      final success = await service.signIn();
      if (!mounted) return;
      if (success) {
        ref.read(googleCalendarConnectedProvider.notifier).state = true;
        context.showSuccessSnackbar('Google Calendar connected');
      } else {
        context.showErrorSnackbar('Failed to connect Google Calendar');
      }
    }
  }

  Future<void> _syncFromGoogle() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        content: Text('Syncing from Google Calendar…'),
      ),
    );
    final result = await ref
        .read(calendarEventsProvider.notifier)
        .syncFromGoogle(force: true);
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    final patched = result.patched;
    final deleted = result.deleted;
    final parts = <String>[
      if (patched > 0) '$patched updated',
      if (deleted > 0) '$deleted deleted',
    ];
    final summary = parts.isEmpty
        ? 'Already up to date'
        : 'Sync complete: ${parts.join(', ')}';
    messenger.showSnackBar(SnackBar(content: Text(summary)));
  }

  Future<void> _showMonthYearPicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _focusedDay,
      firstDate: DateTime.utc(2020, 1, 1),
      lastDate: DateTime.utc(2100, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null && mounted) {
      setState(() => _focusedDay = picked);
      ref.read(selectedDayProvider.notifier).state = DateTime(
        picked.year,
        picked.month,
        picked.day,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = ref.watch(selectedDayProvider);
    final eventsByDay = ref.watch(calendarEventsByDayProvider);
    final selectedEvents = ref.watch(selectedDayEventsProvider);
    final googleConnected = ref.watch(googleCalendarConnectedProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Calendar')),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sync),
            tooltip: 'Calendar integrations',
            onSelected: (value) {
              if (value == 'google') _toggleGoogleCalendar();
              if (value == 'sync') _syncFromGoogle();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'google',
                enabled: GoogleCalendarService.isSupported,
                child: ListTile(
                  enabled: GoogleCalendarService.isSupported,
                  leading: Icon(
                    Icons.calendar_month,
                    color: GoogleCalendarService.isSupported
                        ? (googleConnected ? Colors.green : Colors.blue)
                        : Colors.grey,
                  ),
                  title: Text(
                    googleConnected
                        ? 'Disconnect Google Calendar'
                        : 'Connect Google Calendar',
                  ),
                  subtitle: GoogleCalendarService.isSupported
                      ? null
                      : const Text('Not supported on this platform'),
                  dense: true,
                ),
              ),
              if (googleConnected)
                const PopupMenuItem(
                  value: 'sync',
                  child: ListTile(
                    leading: Icon(Icons.refresh, color: Colors.blue),
                    title: Text('Sync from Google now'),
                    subtitle: Text('Pull recent edits made in Google Calendar'),
                    dense: true,
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Today',
            onPressed: () {
              final now = DateTime.now();
              setState(() => _focusedDay = now);
              ref.read(selectedDayProvider.notifier).state = DateTime(
                now.year,
                now.month,
                now.day,
              );
            },
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            TableCalendar<CalendarEvent>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2100, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              startingDayOfWeek: StartingDayOfWeek.monday,
              selectedDayPredicate: (day) => isSameDay(selectedDay, day),
              eventLoader: (day) {
                final normalizedDay = DateTime(day.year, day.month, day.day);
                return eventsByDay.valueOrNull?[normalizedDay] ?? [];
              },
              onDaySelected: (selected, focused) {
                ref.read(selectedDayProvider.notifier).state = DateTime(
                  selected.year,
                  selected.month,
                  selected.day,
                );
                setState(() => _focusedDay = focused);
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              calendarStyle: CalendarStyle(
                markersMaxCount: 3,
                markerDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(formatButtonShowsNext: false),
              onHeaderTapped: (_) => _showMonthYearPicker(),
            ),

            const Divider(height: 1),

            // Selected day header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat.yMMMEd().format(selectedDay),
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    '${selectedEvents.length} event${selectedEvents.length == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            // Events for selected day
            Expanded(
              child: selectedEvents.isEmpty
                  ? const Center(
                      child: Text(
                        'No events for this day',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: selectedEvents.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final event = selectedEvents[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: event.color != null
                                  ? Color(int.parse(event.color!))
                                  : theme.colorScheme.primaryContainer,
                              child: Icon(
                                _eventTypeIcon(event.type),
                                color: event.color != null
                                    ? Colors.white
                                    : theme.colorScheme.onPrimaryContainer,
                                size: 20,
                              ),
                            ),
                            title: Text(event.title),
                            subtitle: Text(
                              _eventSubtitle(event),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: event.type == EventType.custom
                                ? IconButton(
                                    icon: const Icon(Icons.delete, size: 20),
                                    onPressed: () =>
                                        _confirmDelete(context, ref, event),
                                  )
                                : null,
                            onTap: () => _navigateToSource(context, event),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final dateStr =
              '${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}';
          context.push('/calendar/new?date=$dateStr');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  IconData _eventTypeIcon(EventType type) {
    return switch (type) {
      EventType.task => Icons.check_circle_outline,
      EventType.finance => Icons.attach_money,
      EventType.custom => Icons.event,
      EventType.googleCalendar => Icons.calendar_month,
    };
  }

  void _navigateToSource(BuildContext context, CalendarEvent event) {
    if (event.type == EventType.custom) {
      context.push('/calendar/${event.id}');
    } else if (event.type == EventType.task && event.sourceId != null) {
      context.push('/tasks/${event.sourceId}');
    }
  }

  String _eventSubtitle(CalendarEvent event) {
    final parts = <String>[];
    if (!event.isAllDay) {
      final time = TimeOfDay(hour: event.date.hour, minute: event.date.minute);
      parts.add(
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      );
      if (event.endDate != null) {
        final endTime = TimeOfDay(
          hour: event.endDate!.hour,
          minute: event.endDate!.minute,
        );
        parts.add(
          '– ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
        );
      }
    }
    if (event.description != null && event.description!.isNotEmpty) {
      parts.add(event.description!);
    } else if (parts.isEmpty) {
      parts.add(event.type.name);
    }
    return parts.join(' ');
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(calendarEventsProvider.notifier).deleteEvent(event.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
