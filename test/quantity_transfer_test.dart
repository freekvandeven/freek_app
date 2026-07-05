import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/inventory/utils/quantity_transfer.dart';

void main() {
  group('validateTransfer (WISH-0083)', () {
    test('allows a normal positive transfer', () {
      expect(
        validateTransfer(fromQuantity: 5, toQuantity: 2, amount: 3),
        isNull,
      );
    });

    test('allows a negative amount (reverse direction)', () {
      expect(
        validateTransfer(fromQuantity: 0, toQuantity: 4, amount: -2),
        isNull,
      );
    });

    test('allows draining the source to exactly zero', () {
      expect(
        validateTransfer(fromQuantity: 3, toQuantity: 0, amount: 3),
        isNull,
      );
    });

    test('rejects zero amount', () {
      expect(
        validateTransfer(fromQuantity: 5, toQuantity: 5, amount: 0),
        'Amount cannot be zero',
      );
    });

    test('rejects a transfer that would push the source negative', () {
      expect(
        validateTransfer(fromQuantity: 2, toQuantity: 0, amount: 3),
        contains('source item'),
      );
    });

    test('rejects a reverse transfer that would push the target negative', () {
      expect(
        validateTransfer(fromQuantity: 5, toQuantity: 1, amount: -2),
        contains('target item'),
      );
    });
  });

  group('applyTransfer', () {
    test('computes both new quantities for a positive amount', () {
      final outcome = applyTransfer(fromQuantity: 5, toQuantity: 2, amount: 3);
      expect(outcome.fromNewQuantity, 2);
      expect(outcome.toNewQuantity, 5);
    });

    test('computes both new quantities for a negative amount', () {
      final outcome = applyTransfer(fromQuantity: 1, toQuantity: 4, amount: -2);
      expect(outcome.fromNewQuantity, 3);
      expect(outcome.toNewQuantity, 2);
    });

    test('throws ArgumentError on an invalid transfer', () {
      expect(
        () => applyTransfer(fromQuantity: 1, toQuantity: 0, amount: 5),
        throwsArgumentError,
      );
    });
  });
}
