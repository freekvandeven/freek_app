import '../models/inventory_item.dart';

/// Sort orders for the inventory list (WISH-0085).
enum InventorySort {
  /// Alphabetical by name (case-insensitive) — the default.
  name,

  /// Soonest expiry first, so "eat/drink this first" items float to
  /// the top. Items without an expiry date sink to the bottom,
  /// alphabetical within each group.
  expirySoonest,
}

/// Returns a sorted copy of [items] per [sort]. Pure function so the
/// null-handling and tie-breaking are unit-testable.
List<InventoryItem> sortInventoryItems(
  List<InventoryItem> items,
  InventorySort sort,
) {
  int byName(InventoryItem a, InventoryItem b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  final sorted = items.toList();
  switch (sort) {
    case InventorySort.name:
      sorted.sort(byName);
    case InventorySort.expirySoonest:
      sorted.sort((a, b) {
        final ae = a.expiryDate;
        final be = b.expiryDate;
        if (ae == null && be == null) return byName(a, b);
        if (ae == null) return 1;
        if (be == null) return -1;
        final cmp = ae.compareTo(be);
        return cmp != 0 ? cmp : byName(a, b);
      });
  }
  return sorted;
}
