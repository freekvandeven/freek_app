import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/inventory/models/inventory_item.dart';

void main() {
  group('InventoryItem.fillPercent', () {
    test('defaults to null when not set', () {
      final item = InventoryItem(name: 'Soy sauce');
      expect(item.fillPercent, isNull);
    });

    test('roundtrips through toMap/fromMap', () {
      final item = InventoryItem(name: 'Flour bag', fillPercent: 50);
      final copy = InventoryItem.fromMap(item.toMap());
      expect(copy.fillPercent, 50);
    });

    test('fromMap tolerates missing fillPercent (legacy data)', () {
      final legacy = InventoryItem(name: 'Old item').toMap()
        ..remove('fillPercent');
      final restored = InventoryItem.fromMap(legacy);
      expect(restored.fillPercent, isNull);
    });

    test('copyWith updates the value', () {
      final item = InventoryItem(name: 'a', fillPercent: 80);
      final updated = item.copyWith(fillPercent: 25);
      expect(updated.fillPercent, 25);
    });

    test('copyWith clearFillPercent resets to null', () {
      final item = InventoryItem(name: 'a', fillPercent: 80);
      final updated = item.copyWith(clearFillPercent: true);
      expect(updated.fillPercent, isNull);
    });

    test('copyWith leaves quantity untouched when changing fillPercent', () {
      final item = InventoryItem(name: 'a', quantity: 3, fillPercent: 75);
      final updated = item.copyWith(fillPercent: 50);
      expect(updated.quantity, 3);
      expect(updated.fillPercent, 50);
    });
  });

  group('InventoryItem.isOpened', () {
    test('defaults to false when not set', () {
      final item = InventoryItem(name: 'Soy sauce');
      expect(item.isOpened, isFalse);
    });

    test('roundtrips through toMap/fromMap', () {
      final item = InventoryItem(name: 'Flour bag', isOpened: true);
      final copy = InventoryItem.fromMap(item.toMap());
      expect(copy.isOpened, isTrue);
    });

    test('fromMap tolerates missing isOpened (legacy data)', () {
      final legacy = InventoryItem(name: 'Old item').toMap()
        ..remove('isOpened');
      final restored = InventoryItem.fromMap(legacy);
      expect(restored.isOpened, isFalse);
    });

    test('copyWith updates the value', () {
      final item = InventoryItem(name: 'a');
      final updated = item.copyWith(isOpened: true);
      expect(updated.isOpened, isTrue);
    });

    test('is independent of fillPercent', () {
      final item = InventoryItem(name: 'a', isOpened: true);
      expect(item.fillPercent, isNull);
      final withFill = item.copyWith(fillPercent: 40);
      expect(withFill.isOpened, isTrue);
      expect(withFill.fillPercent, 40);
    });
  });
}
