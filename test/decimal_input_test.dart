import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/utils/decimal_input.dart';

void main() {
  group('parseDecimal', () {
    test('parses standard dot decimal', () {
      expect(parseDecimal('1.5'), 1.5);
      expect(parseDecimal('0.99'), 0.99);
      expect(parseDecimal('1000'), 1000);
    });

    test('parses comma as decimal separator (BUG-0043)', () {
      expect(parseDecimal('1,5'), 1.5);
      expect(parseDecimal('0,99'), 0.99);
      expect(parseDecimal('123,45'), 123.45);
    });

    test('trims surrounding whitespace', () {
      expect(parseDecimal(' 1,5 '), 1.5);
      expect(parseDecimal('\t1.5\n'), 1.5);
    });

    test('returns null for null / empty / whitespace-only input', () {
      expect(parseDecimal(null), isNull);
      expect(parseDecimal(''), isNull);
      expect(parseDecimal('   '), isNull);
    });

    test('returns null for non-numeric input', () {
      expect(parseDecimal('abc'), isNull);
      expect(parseDecimal('1.2.3'), isNull);
      expect(parseDecimal('1,2,3'), isNull);
    });

    test('negative numbers parse with either separator', () {
      expect(parseDecimal('-1.5'), -1.5);
      expect(parseDecimal('-1,5'), -1.5);
    });

    test('integer-looking input parses to double', () {
      expect(parseDecimal('42'), 42.0);
    });
  });

  group('validateOptionalDecimal', () {
    test('returns null for empty / null (optional)', () {
      expect(validateOptionalDecimal(null), isNull);
      expect(validateOptionalDecimal(''), isNull);
      expect(validateOptionalDecimal('  '), isNull);
    });

    test('returns null for valid decimals using either separator', () {
      expect(validateOptionalDecimal('1.5'), isNull);
      expect(validateOptionalDecimal('1,5'), isNull);
    });

    test('returns error message for invalid input', () {
      expect(validateOptionalDecimal('abc'), 'Invalid number');
      expect(validateOptionalDecimal('1.2.3'), 'Invalid number');
    });
  });

  group('formatDecimal', () {
    test('whole numbers show with no trailing .0', () {
      expect(formatDecimal(2.0), '2');
      expect(formatDecimal(200.0), '200');
      expect(formatDecimal(0.0), '0');
    });

    test('fractional values keep up to 2 decimal places', () {
      expect(formatDecimal(1.5), '1.5');
      expect(formatDecimal(1.25), '1.25');
    });

    test('rounds to 2 decimal places', () {
      expect(formatDecimal(1.005), '1');
      expect(formatDecimal(1.239), '1.24');
    });

    test('trims a trailing .0 that only appears after rounding', () {
      expect(formatDecimal(1.999), '2');
    });
  });
}
