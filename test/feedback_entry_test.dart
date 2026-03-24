import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/feedback/models/feedback_entry.dart';

void main() {
  group('FeedbackEntry', () {
    final now = DateTime(2025, 3, 10, 14, 0);

    FeedbackEntry createEntry() => FeedbackEntry(
      id: 'fb-001',
      type: FeedbackType.bug,
      title: 'App crashes on login',
      description: 'When I tap sign in, the app freezes.',
      status: FeedbackStatus.open,
      isPrivate: true,
      isManual: true,
      userId: 'user-123',
      attachedLogs: 'Error: null pointer',
      imageUrls: ['https://example.com/screenshot.png'],
      createdAt: now,
      updatedAt: now,
    );

    test('toMap and fromMap round-trip', () {
      final entry = createEntry();
      final map = entry.toMap();
      final restored = FeedbackEntry.fromMap(map);

      expect(restored.id, 'fb-001');
      expect(restored.type, FeedbackType.bug);
      expect(restored.title, 'App crashes on login');
      expect(restored.description, 'When I tap sign in, the app freezes.');
      expect(restored.status, FeedbackStatus.open);
      expect(restored.isPrivate, isTrue);
      expect(restored.isManual, isTrue);
      expect(restored.userId, 'user-123');
      expect(restored.attachedLogs, 'Error: null pointer');
      expect(restored.imageUrls, ['https://example.com/screenshot.png']);
      expect(restored.createdAt, now);
      expect(restored.updatedAt, now);
    });

    test('fromMap defaults isPrivate to false when missing', () {
      final entry = FeedbackEntry.fromMap({
        'id': 'fb-002',
        'type': 'wish',
        'title': 'Add dark mode',
        'description': 'I want dark mode',
        'status': 'open',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
      expect(entry.isPrivate, isFalse);
      expect(entry.isManual, isFalse);
      expect(entry.imageUrls, isEmpty);
      expect(entry.attachedLogs, isNull);
    });

    test('auto-generates id when not provided', () {
      final entry = FeedbackEntry(
        type: FeedbackType.wish,
        title: 'Feature request',
        description: 'Details',
      );
      expect(entry.id, isNotEmpty);
      expect(entry.id.length, greaterThan(10));
    });

    test('auto-generates timestamps when not provided', () {
      final before = DateTime.now();
      final entry = FeedbackEntry(
        type: FeedbackType.bug,
        title: 'Bug',
        description: 'Details',
      );
      final after = DateTime.now();

      expect(
        entry.createdAt.isAfter(before.subtract(Duration(seconds: 1))),
        isTrue,
      );
      expect(entry.createdAt.isBefore(after.add(Duration(seconds: 1))), isTrue);
    });

    test('copyWith replaces fields', () {
      final entry = createEntry();
      final updated = entry.copyWith(
        title: 'Updated title',
        status: FeedbackStatus.resolved,
      );
      expect(updated.title, 'Updated title');
      expect(updated.status, FeedbackStatus.resolved);
      expect(updated.id, 'fb-001'); // unchanged
      expect(updated.type, FeedbackType.bug); // unchanged
    });

    test('copyWith clearAttachedLogs sets null', () {
      final entry = createEntry();
      expect(entry.attachedLogs, isNotNull);
      final updated = entry.copyWith(clearAttachedLogs: true);
      expect(updated.attachedLogs, isNull);
    });

    test('toMap serializes enums as name strings', () {
      final entry = createEntry();
      final map = entry.toMap();
      expect(map['type'], 'bug');
      expect(map['status'], 'open');
    });

    group('toClipboardText', () {
      test('formats bug entry correctly', () {
        final entry = createEntry();
        final text = entry.toClipboardText();
        expect(text, contains('[Bug]'));
        expect(text, contains('App crashes on login'));
        expect(text, contains('When I tap sign in, the app freezes.'));
        expect(text, contains('Status: Open'));
        expect(text, contains('Attached Logs:'));
        expect(text, contains('Error: null pointer'));
        expect(text, contains('Attached Images (1):'));
        expect(text, contains('https://example.com/screenshot.png'));
      });

      test('formats wish entry without logs or images', () {
        final entry = FeedbackEntry(
          id: 'fb-003',
          type: FeedbackType.wish,
          title: 'Add feature',
          description: 'I want this feature',
          createdAt: now,
          updatedAt: now,
        );
        final text = entry.toClipboardText();
        expect(text, contains('[Wish]'));
        expect(text, contains('Add feature'));
        expect(text, isNot(contains('Attached Logs:')));
        expect(text, isNot(contains('Attached Images')));
      });
    });
  });
}
