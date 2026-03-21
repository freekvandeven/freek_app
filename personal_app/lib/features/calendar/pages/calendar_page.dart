import 'package:flutter/material.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/calendar_event.dart';
import '../providers/calendar_providers.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final selectedDay = ref.watch(selectedDayProvider);
    final eventsByDay = ref.watch(calendarEventsByDayProvider);
    final selectedEvents = ref.watch(selectedDayEventsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Calendar')),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sync),
            tooltip: 'Calendar integrations',
            onSelected: (value) {
              switch (value) {
                case 'google':
                  launchUrl(
                    Uri.parse('https://calendar.google.com'),
                    mode: LaunchMode.externalApplication,
                  );
                case 'kerio':
                  launchUrl(
                    Uri.parse('https://mail.kerio.com'),
                    mode: LaunchMode.externalApplication,
                  );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'google',
                child: ListTile(
                  leading: Icon(Icons.calendar_month, color: Colors.blue),
                  title: Text('Google Calendar'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'kerio',
                child: ListTile(
                  leading: Icon(Icons.mail, color: Colors.orange),
                  title: Text('Kerio Connect'),
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
      body: Column(
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
                          subtitle: event.description != null
                              ? Text(
                                  event.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : Text(event.type.name),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventDialog(context, ref, selectedDay),
        child: const Icon(Icons.add),
      ),
    );
  }

  IconData _eventTypeIcon(EventType type) {
    return switch (type) {
      EventType.task => Icons.check_circle_outline,
      EventType.finance => Icons.attach_money,
      EventType.custom => Icons.event,
    };
  }

  void _navigateToSource(BuildContext context, CalendarEvent event) {
    if (event.type == EventType.task && event.sourceId != null) {
      context.push('/tasks/${event.sourceId}');
    }
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

  void _showAddEventDialog(BuildContext context, WidgetRef ref, DateTime day) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                ref
                    .read(calendarEventsProvider.notifier)
                    .addEvent(
                      CalendarEvent(
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                        date: day,
                      ),
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
