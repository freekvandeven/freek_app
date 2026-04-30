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
  static const _calendarScope =
      'https://www.googleapis.com/auth/calendar.readonly';

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
