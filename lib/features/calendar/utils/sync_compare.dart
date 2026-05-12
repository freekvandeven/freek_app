import '../models/calendar_event.dart';

/// Returns true when [local] already matches [google] on the fields we
/// sync from Google → Firestore (title, description, date, endDate,
/// isAllDay). Used by `CalendarEventsNotifier.syncFromGoogle` to skip
/// no-op patches.
///
/// Date fields are compared by [sameMoment] so a naive Firestore-
/// round-tripped DateTime equals Google's `.toLocal()`'d DateTime when
/// they represent the same instant — see BUG-0032 follow-up.
bool eventInSyncWithGoogle(CalendarEvent local, CalendarEvent google) {
  return local.title == google.title &&
      (local.description ?? '') == (google.description ?? '') &&
      sameMoment(local.date, google.date) &&
      sameMoment(local.endDate, google.endDate) &&
      local.isAllDay == google.isAllDay;
}

/// Compares two [DateTime]s by absolute instant rather than Dart's
/// default `==` (which also checks the `isUtc` flag, so a UTC and a
/// local DateTime representing the same moment compare unequal).
bool sameMoment(DateTime? a, DateTime? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return a.microsecondsSinceEpoch == b.microsecondsSinceEpoch;
}
