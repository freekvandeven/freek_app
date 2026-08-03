import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/tasks/models/task.dart';

void main() {
  group('Task.estimatedMinutes (WISH-0094)', () {
    test('defaults to null when not set', () {
      final task = Task(title: 'Wash the car');
      expect(task.estimatedMinutes, isNull);
    });

    test('roundtrips through toMap/fromMap', () {
      final task = Task(title: 'Write report', estimatedMinutes: 90);
      final copy = Task.fromMap(task.toMap());
      expect(copy.estimatedMinutes, 90);
    });

    test('fromMap tolerates missing estimatedMinutes (legacy data)', () {
      final legacy = Task(title: 'Old task').toMap()
        ..remove('estimatedMinutes');
      final restored = Task.fromMap(legacy);
      expect(restored.estimatedMinutes, isNull);
    });

    test('copyWith updates the value', () {
      final task = Task(title: 'a', estimatedMinutes: 30);
      final updated = task.copyWith(estimatedMinutes: 45);
      expect(updated.estimatedMinutes, 45);
    });

    test('copyWith clearEstimatedMinutes resets to null', () {
      final task = Task(title: 'a', estimatedMinutes: 30);
      final updated = task.copyWith(clearEstimatedMinutes: true);
      expect(updated.estimatedMinutes, isNull);
    });

    test('is independent of priority', () {
      final task = Task(
        title: 'a',
        priority: TaskPriority.high,
        estimatedMinutes: 15,
      );
      final updated = task.copyWith(estimatedMinutes: 120);
      expect(updated.priority, TaskPriority.high);
      expect(updated.estimatedMinutes, 120);
    });
  });
}
