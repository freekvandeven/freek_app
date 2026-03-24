import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_event.dart';

class GoogleCalendarService {
  static const _connectedKey = 'google_calendar_connected';
  static const _calendarScope =
      'https://www.googleapis.com/auth/calendar.readonly';

  final _prefs = SharedPreferencesAsync();
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: [_calendarScope]);

  GoogleSignInAccount? _account;

  Future<bool> get isConnected async {
    if (_account != null) return true;
    return await _prefs.getBool(_connectedKey) ?? false;
  }

  Future<bool> signIn() async {
    try {
      _account = await _googleSignIn.signIn();
      if (_account != null) {
        await _prefs.setBool(_connectedKey, true);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnect() async {
    await _googleSignIn.disconnect();
    _account = null;
    await _prefs.setBool(_connectedKey, false);
  }

  /// Try silent sign-in (no UI prompt).
  Future<bool> trySilentSignIn() async {
    try {
      _account = await _googleSignIn.signInSilently();
      return _account != null;
    } catch (_) {
      return false;
    }
  }

  /// Fetch events from the user's primary Google Calendar.
  /// Returns events within [timeMin, timeMax].
  Future<List<CalendarEvent>> fetchEvents({
    required DateTime timeMin,
    required DateTime timeMax,
  }) async {
    _account ??= await _googleSignIn.signInSilently();
    if (_account == null) return [];

    final headers = await _account!.authHeaders;
    final uri = Uri.https(
      'www.googleapis.com',
      '/calendar/v3/calendars/primary/events',
      {
        'timeMin': timeMin.toUtc().toIso8601String(),
        'timeMax': timeMax.toUtc().toIso8601String(),
        'singleEvents': 'true',
        'orderBy': 'startTime',
        'maxResults': '250',
      },
    );

    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];

    return items
        .map((item) => _parseEvent(item as Map<String, dynamic>))
        .whereType<CalendarEvent>()
        .toList();
  }

  CalendarEvent? _parseEvent(Map<String, dynamic> item) {
    final summary = item['summary'] as String?;
    if (summary == null) return null;

    final start = item['start'] as Map<String, dynamic>?;
    if (start == null) return null;

    DateTime date;
    bool isAllDay;

    if (start.containsKey('dateTime')) {
      date = DateTime.parse(start['dateTime'] as String).toLocal();
      isAllDay = false;
    } else if (start.containsKey('date')) {
      date = DateTime.parse(start['date'] as String);
      isAllDay = true;
    } else {
      return null;
    }

    DateTime? endDate;
    final end = item['end'] as Map<String, dynamic>?;
    if (end != null) {
      if (end.containsKey('dateTime')) {
        endDate = DateTime.parse(end['dateTime'] as String).toLocal();
      }
    }

    final id = item['id'] as String? ?? summary.hashCode.toString();

    return CalendarEvent(
      id: 'gcal_$id',
      title: summary,
      description: item['description'] as String?,
      date: date,
      endDate: endDate,
      isAllDay: isAllDay,
      type: EventType.googleCalendar,
      color: '0xFF4285F4', // Google blue
    );
  }
}
