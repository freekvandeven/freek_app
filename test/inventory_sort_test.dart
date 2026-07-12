import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/inventory/models/inventory_item.dart';
import 'package:personal_app/features/inventory/utils/inventory_sort.dart';

void main() {
  InventoryItem item(String name, {DateTime? expiry}) =>
      InventoryItem(name: name, expiryDate: expiry);

  group('sortInventoryItems (WISH-0085)', () {
    test('name sort is alphabetical and case-insensitive', () {
      final sorted = sortInventoryItems([
        item('banana'),
        item('Apple'),
        item('cherry'),
      ], InventorySort.name);
      expect(sorted.map((i) => i.name).toList(), ['Apple', 'banana', 'cherry']);
    });

    test('expirySoonest puts the earliest expiry first', () {
      final sorted = sortInventoryItems([
        item('later', expiry: DateTime(2026, 8, 1)),
        item('soon', expiry: DateTime(2026, 7, 15)),
        item('middle', expiry: DateTime(2026, 7, 20)),
      ], InventorySort.expirySoonest);
      expect(sorted.map((i) => i.name).toList(), ['soon', 'middle', 'later']);
    });

    test('items without expiry sink to the bottom', () {
      final sorted = sortInventoryItems([
        item('no expiry'),
        item('expiring', expiry: DateTime(2026, 7, 15)),
      ], InventorySort.expirySoonest);
      expect(sorted.first.name, 'expiring');
      expect(sorted.last.name, 'no expiry');
    });

    test('same expiry ties break alphabetically', () {
      final d = DateTime(2026, 7, 15);
      final sorted = sortInventoryItems([
        item('b', expiry: d),
        item('a', expiry: d),
      ], InventorySort.expirySoonest);
      expect(sorted.map((i) => i.name).toList(), ['a', 'b']);
    });

    test('no-expiry group is alphabetical too', () {
      final sorted = sortInventoryItems([
        item('zeta'),
        item('alpha'),
      ], InventorySort.expirySoonest);
      expect(sorted.map((i) => i.name).toList(), ['alpha', 'zeta']);
    });

    test('does not mutate the input list', () {
      final input = [item('b'), item('a')];
      sortInventoryItems(input, InventorySort.name);
      expect(input.map((i) => i.name).toList(), ['b', 'a']);
    });
  });
}
