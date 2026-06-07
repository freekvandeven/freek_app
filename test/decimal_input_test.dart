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
}
