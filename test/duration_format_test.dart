import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/tasks/utils/duration_format.dart';

void main() {
  group('formatTaskDuration (WISH-0094)', () {
    test('shows only minutes under an hour', () {
      expect(formatTaskDuration(5), '5m');
      expect(formatTaskDuration(45), '45m');
    });

    test('shows only hours on whole-hour amounts', () {
      expect(formatTaskDuration(60), '1h');
      expect(formatTaskDuration(180), '3h');
    });

    test('shows both hours and minutes otherwise', () {
      expect(formatTaskDuration(90), '1h 30m');
      expect(formatTaskDuration(135), '2h 15m');
    });

    test('handles zero', () {
      expect(formatTaskDuration(0), '0m');
    });
  });
}
