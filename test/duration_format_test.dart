import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/utils/duration_format.dart';

void main() {
  group('formatDuration (WISH-0094)', () {
    test('shows only minutes under an hour', () {
      expect(formatDuration(5), '5m');
      expect(formatDuration(45), '45m');
    });

    test('shows only hours on whole-hour amounts', () {
      expect(formatDuration(60), '1h');
      expect(formatDuration(180), '3h');
    });

    test('shows both hours and minutes otherwise', () {
      expect(formatDuration(90), '1h 30m');
      expect(formatDuration(135), '2h 15m');
    });

    test('handles zero', () {
      expect(formatDuration(0), '0m');
    });
  });
}
