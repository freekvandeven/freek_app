import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/calendar/models/calendar_event.dart';
import 'package:personal_app/features/calendar/utils/sync_compare.dart';

CalendarEvent _event({
  required String title,
  String? description,
  required DateTime date,
  DateTime? endDate,
  bool isAllDay = false,
  String? googleEventId,
}) {
  return CalendarEvent(
    id: 'local-1',
    title: title,
    description: description,
    date: date,
    endDate: endDate,
    isAllDay: isAllDay,
    type: EventType.custom,
    googleEventId: googleEventId,
  );
}

void main() {
  group('sameMoment', () {
    test('two nulls are the same moment', () {
      expect(sameMoment(null, null), isTrue);
    });

    test('null vs concrete is not the same moment', () {
      expect(sameMoment(null, DateTime(2026)), isFalse);
      expect(sameMoment(DateTime(2026), null), isFalse);
    });

    test(
      'UTC and matching local DateTime compare equal (BUG-0032 regression)',
      () {
        final utc = DateTime.utc(2026, 5, 15, 8, 0, 0);
        final local = utc.toLocal();
        // Dart's default == considers isUtc, so this would normally be false:
        expect(utc == local, isFalse);
        // sameMoment uses microsecondsSinceEpoch and ignores the flag.
        expect(sameMoment(utc, local), isTrue);
      },
    );

    test('truly different moments are not equal', () {
      final a = DateTime(2026, 5, 15, 8);
      final b = DateTime(2026, 5, 15, 9);
      expect(sameMoment(a, b), isFalse);
    });

    test('Firestore round-trip (toIso → parse) is the same moment', () {
      final original = DateTime.utc(2026, 5, 15, 8, 0, 0).toLocal();
      final roundTripped = DateTime.parse(original.toIso8601String());
      expect(sameMoment(original, roundTripped), isTrue);
    });
  });

  group('eventInSyncWithGoogle', () {
    final base = DateTime.utc(2026, 5, 15, 8);
    test('identical local + Google events are in sync', () {
      final local = _event(title: 'A', description: 'd', date: base);
      final google = _event(title: 'A', description: 'd', date: base);
      expect(eventInSyncWithGoogle(local, google), isTrue);
    });

    test('null description and empty description are treated equal', () {
      final local = _event(title: 'A', description: null, date: base);
      final google = _event(title: 'A', description: '', date: base);
      expect(eventInSyncWithGoogle(local, google), isTrue);
    });

    test('title difference fails the check', () {
      final local = _event(title: 'A', date: base);
      final google = _event(title: 'B', date: base);
      expect(eventInSyncWithGoogle(local, google), isFalse);
    });

    test('date difference fails the check', () {
      final local = _event(title: 'A', date: base);
      final google = _event(
        title: 'A',
        date: base.add(const Duration(hours: 1)),
      );
      expect(eventInSyncWithGoogle(local, google), isFalse);
    });

    test('endDate difference fails the check', () {
      final end1 = base.add(const Duration(hours: 1));
      final end2 = base.add(const Duration(hours: 2));
      final local = _event(title: 'A', date: base, endDate: end1);
      final google = _event(title: 'A', date: base, endDate: end2);
      expect(eventInSyncWithGoogle(local, google), isFalse);
    });

    test('isAllDay difference fails the check', () {
      final local = _event(title: 'A', date: base, isAllDay: true);
      final google = _event(title: 'A', date: base, isAllDay: false);
      expect(eventInSyncWithGoogle(local, google), isFalse);
    });

    test(
      'Firestore round-tripped date still equals Google date (BUG-0032)',
      () {
        final googleDate = DateTime.utc(2026, 5, 15, 8).toLocal();
        final storedDate = DateTime.parse(googleDate.toIso8601String());
        final local = _event(title: 'A', date: storedDate);
        final google = _event(title: 'A', date: googleDate);
        expect(
          eventInSyncWithGoogle(local, google),
          isTrue,
          reason:
              'Before BUG-0032 follow-up, this returned false because '
              'DateTime == considers isUtc — causing endless re-patches.',
        );
      },
    );
  });
}
