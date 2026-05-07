import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/log_service.dart';
import '../models/calendar_event.dart';

class GoogleCalendarService {
  static const _connectedKey = 'google_calendar_connected';
  // calendar.events grants read + write access to events on the user's calendars.
  static const _calendarScope =
      'https://www.googleapis.com/auth/calendar.events';

  /// True on platforms where google_sign_in has a native implementation.
  static bool get isSupported =>
      kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  final _prefs = SharedPreferencesAsync();
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: [_calendarScope]);

  GoogleSignInAccount? _account;

  Future<bool> get isConnected async {
    if (!isSupported) return false;
    if (_account != null) return true;
    return await _prefs.getBool(_connectedKey) ?? false;
  }

  Future<bool> signIn() async {
    if (!isSupported) return false;
    try {
      _account = await _googleSignIn.signIn();
      if (_account != null) {
        await _prefs.setBool(_connectedKey, true);
        LogService.instance.info(
          'Google Calendar signed in as ${_account!.email}',
        );
        return true;
      }
      LogService.instance.warning('Google Calendar sign-in cancelled by user');
      return false;
    } catch (ex, stack) {
      LogService.instance.error('Google Calendar sign-in failed: $ex\n$stack');
      return false;
    }
  }

  Future<void> disconnect() async {
    if (!isSupported) return;
    try {
      await _googleSignIn.disconnect();
      LogService.instance.info('Google Calendar disconnected');
    } catch (ex) {
      LogService.instance.warning('Google Calendar disconnect error: $ex');
    }
    _account = null;
    await _prefs.setBool(_connectedKey, false);
  }

  /// Try silent sign-in (no UI prompt).
  Future<bool> trySilentSignIn() async {
    if (!isSupported) return false;
    try {
      _account = await _googleSignIn.signInSilently();
      if (_account != null) {
        LogService.instance.info(
          'Google Calendar silent sign-in succeeded: ${_account!.email}',
        );
      }
      return _account != null;
    } catch (ex) {
      LogService.instance.warning('Google Calendar silent sign-in failed: $ex');
      return false;
    }
  }

  /// Fetch events from the user's primary Google Calendar.
  /// Returns events within [timeMin, timeMax].
  Future<List<CalendarEvent>> fetchEvents({
    required DateTime timeMin,
    required DateTime timeMax,
  }) async {
    if (!isSupported) return [];

    // Refresh current user in case the in-memory account was lost.
    _account ??= _googleSignIn.currentUser;
    _account ??= await _googleSignIn.signInSilently();
    if (_account == null) {
      LogService.instance.warning(
        'Google Calendar fetchEvents: no signed-in account',
      );
      return [];
    }

    // On web, signInSilently() restores authentication (ID token) but not the
    // OAuth access token for API scopes. requestScopes silently refreshes the
    // token when the scope is already granted; only prompts if not yet approved.
    final scopeGranted = await _googleSignIn.requestScopes([_calendarScope]);
    if (!scopeGranted) {
      LogService.instance.warning(
        'Google Calendar fetchEvents: calendar scope not granted',
      );
      return [];
    }
    // Re-read currentUser so _account holds the freshly-authorized token.
    _account = _googleSignIn.currentUser;
    if (_account == null) return [];

    Map<String, String> headers;
    try {
      headers = await _account!.authHeaders;
    } catch (ex) {
      LogService.instance.error(
        'Google Calendar failed to get auth headers: $ex',
      );
      _account = null;
      return [];
    }

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

    final http.Response response;
    try {
      response = await http.get(uri, headers: headers);
    } catch (ex) {
      LogService.instance.error('Google Calendar HTTP request failed: $ex');
      return [];
    }

    if (response.statusCode != 200) {
      LogService.instance.error(
        'Google Calendar API error ${response.statusCode}: ${response.body}',
      );
      return [];
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (ex) {
      LogService.instance.error('Google Calendar JSON parse error: $ex');
      return [];
    }

    final items = List<dynamic>.from(data['items'] as List? ?? []);
    final events = <CalendarEvent>[];
    for (final item in items) {
      try {
        final event = _parseEvent(item as Map<String, dynamic>);
        if (event != null) events.add(event);
      } catch (ex) {
        LogService.instance.warning(
          'Google Calendar skipped unparseable event: $ex',
        );
      }
    }

    LogService.instance.info(
      'Google Calendar fetched ${events.length} events '
      '(${timeMin.toIso8601String()} – ${timeMax.toIso8601String()})',
    );
    return events;
  }

  /// Creates an event in the user's primary Google Calendar.
  /// Returns the Google Calendar event ID on success, null on failure.
  Future<String?> createEvent(CalendarEvent event) async {
    if (!isSupported) return null;

    _account ??= _googleSignIn.currentUser;
    if (_account == null) return null;

    final scopeGranted = await _googleSignIn.requestScopes([_calendarScope]);
    if (!scopeGranted) {
      LogService.instance.warning(
        'Google Calendar createEvent: calendar scope not granted',
      );
      return null;
    }
    _account = _googleSignIn.currentUser;
    if (_account == null) return null;

    Map<String, String> headers;
    try {
      headers = await _account!.authHeaders;
    } catch (ex) {
      LogService.instance.error(
        'Google Calendar createEvent: failed to get auth headers: $ex',
      );
      return null;
    }

    final body = _buildEventBody(event);
    final uri = Uri.https(
      'www.googleapis.com',
      '/calendar/v3/calendars/primary/events',
    );

    final http.Response response;
    try {
      response = await http.post(
        uri,
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (ex) {
      LogService.instance.error('Google Calendar createEvent HTTP error: $ex');
      return null;
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      LogService.instance.error(
        'Google Calendar createEvent failed ${response.statusCode}: ${response.body}',
      );
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final id = data['id'] as String?;
    LogService.instance.info(
      'Google Calendar event created: "${event.title}" (gcal_id=$id)',
    );
    return id;
  }

  /// Patches an existing event in the user's primary Google Calendar.
  /// Returns true on success, false on failure.
  Future<bool> updateEvent(String googleEventId, CalendarEvent event) async {
    return _writeEvent(
      method: 'PATCH',
      googleEventId: googleEventId,
      body: _buildEventBody(event),
      op: 'updateEvent',
      title: event.title,
    );
  }

  /// Deletes an event from the user's primary Google Calendar.
  /// Returns true on success or if the remote event was already gone.
  Future<bool> deleteEvent(String googleEventId) async {
    return _writeEvent(
      method: 'DELETE',
      googleEventId: googleEventId,
      body: null,
      op: 'deleteEvent',
      title: googleEventId,
    );
  }

  Future<bool> _writeEvent({
    required String method,
    required String googleEventId,
    required Map<String, dynamic>? body,
    required String op,
    required String title,
  }) async {
    if (!isSupported) return false;
    _account ??= _googleSignIn.currentUser;
    if (_account == null) return false;

    final scopeGranted = await _googleSignIn.requestScopes([_calendarScope]);
    if (!scopeGranted) {
      LogService.instance.warning(
        'Google Calendar $op: calendar scope not granted',
      );
      return false;
    }
    _account = _googleSignIn.currentUser;
    if (_account == null) return false;

    Map<String, String> headers;
    try {
      headers = await _account!.authHeaders;
    } catch (ex) {
      LogService.instance.error(
        'Google Calendar $op: failed to get auth headers: $ex',
      );
      return false;
    }

    final uri = Uri.https(
      'www.googleapis.com',
      '/calendar/v3/calendars/primary/events/$googleEventId',
    );

    final http.Response response;
    try {
      switch (method) {
        case 'PATCH':
          response = await http.patch(
            uri,
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode(body),
          );
        case 'DELETE':
          response = await http.delete(uri, headers: headers);
        default:
          return false;
      }
    } catch (ex) {
      LogService.instance.error('Google Calendar $op HTTP error: $ex');
      return false;
    }

    // 200/204 success, 410 = already deleted (treat as success for delete)
    final ok =
        response.statusCode == 200 ||
        response.statusCode == 204 ||
        (method == 'DELETE' && response.statusCode == 410);
    if (!ok) {
      LogService.instance.error(
        'Google Calendar $op failed ${response.statusCode}: ${response.body}',
      );
      return false;
    }
    LogService.instance.info(
      'Google Calendar $op succeeded for "$title" (gcal_id=$googleEventId)',
    );
    return true;
  }

  Map<String, dynamic> _buildEventBody(CalendarEvent event) {
    final body = <String, dynamic>{'summary': event.title};
    if (event.description != null && event.description!.isNotEmpty) {
      body['description'] = event.description;
    }

    String dateStr(DateTime dt) =>
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

    if (event.isAllDay) {
      body['start'] = {'date': dateStr(event.date)};
      // Google Calendar all-day end date is exclusive, so add 1 day when no
      // explicit end is set.
      final endDt = event.endDate ?? event.date.add(const Duration(days: 1));
      body['end'] = {'date': dateStr(endDt)};
    } else {
      body['start'] = {'dateTime': event.date.toUtc().toIso8601String()};
      final endDt = event.endDate ?? event.date.add(const Duration(hours: 1));
      body['end'] = {'dateTime': endDt.toUtc().toIso8601String()};
    }

    return body;
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
    if (end != null && end.containsKey('dateTime')) {
      endDate = DateTime.parse(end['dateTime'] as String).toLocal();
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
      color: '0xFF4285F4',
    );
  }
}
