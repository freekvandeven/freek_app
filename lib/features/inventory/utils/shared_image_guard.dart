import '../models/inventory_item.dart';

/// Since WISH-0088 two inventory items can reference the same Storage
/// image (transfer-to-new-item copies the URL list). Deleting an image
/// from Storage while another item still points at it would break that
/// item, so every cascade-delete must filter its candidates through
/// this helper first.
///
/// Returns the subset of [candidateUrls] that no item other than
/// [excludeItemId] references — i.e. the URLs that are actually safe
/// to remove from Storage.
List<String> imageUrlsSafeToDelete({
  required List<InventoryItem> allItems,
  required String? excludeItemId,
  required List<String> candidateUrls,
}) {
  final referencedElsewhere = <String>{
    for (final item in allItems)
      if (item.id != excludeItemId) ...item.imageUrls,
  };
  return candidateUrls
      .where((url) => !referencedElsewhere.contains(url))
      .toList();
}
