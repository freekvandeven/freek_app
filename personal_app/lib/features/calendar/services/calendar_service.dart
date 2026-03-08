import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_event.dart';

abstract class CalendarService {
  Future<List<CalendarEvent>> getEvents();
  Future<void> addEvent(CalendarEvent event);
  Future<void> updateEvent(CalendarEvent event);
  Future<void> deleteEvent(String id);
}

class MockCalendarService implements CalendarService {
  static const _eventsKey = 'calendar_events';
  final _prefs = SharedPreferencesAsync();

  @override
  Future<List<CalendarEvent>> getEvents() async {
    final data = await _prefs.getString(_eventsKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list
        .map((e) => CalendarEvent.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> addEvent(CalendarEvent event) async {
    final events = await getEvents();
    events.add(event);
    await _saveEvents(events);
  }

  @override
  Future<void> updateEvent(CalendarEvent event) async {
    final events = await getEvents();
    final index = events.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      events[index] = event;
      await _saveEvents(events);
    }
  }

  @override
  Future<void> deleteEvent(String id) async {
    final events = await getEvents();
    events.removeWhere((e) => e.id == id);
    await _saveEvents(events);
  }

  Future<void> _saveEvents(List<CalendarEvent> events) async {
    await _prefs.setString(
      _eventsKey,
      jsonEncode(events.map((e) => e.toMap()).toList()),
    );
  }
}
