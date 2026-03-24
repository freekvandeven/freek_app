import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/calendar_event.dart';
import '../services/google_calendar_service.dart';

final googleCalendarServiceProvider = Provider<GoogleCalendarService>((ref) {
  return GoogleCalendarService();
});

final googleCalendarConnectedProvider = StateProvider<bool>((ref) => false);

final googleCalendarEventsProvider = FutureProvider<List<CalendarEvent>>((
  ref,
) async {
  final connected = ref.watch(googleCalendarConnectedProvider);
  if (!connected) return [];

  final service = ref.read(googleCalendarServiceProvider);
  final now = DateTime.now();
  final timeMin = DateTime(now.year, now.month - 1, 1);
  final timeMax = DateTime(now.year, now.month + 2, 0);

  return service.fetchEvents(timeMin: timeMin, timeMax: timeMax);
});
