import '../models/watch_item.dart';

/// Moves the entry at [oldIndex] to [newIndex] within [items] and renumbers
/// every entry's `sortOrder` to match its new position (WISH-0098).
///
/// [newIndex] is the item's final index once it has been lifted out of its
/// old slot, matching `ReorderableListView.onReorderItem` (which does that
/// adjustment for us, unlike the deprecated `onReorder`).
///
/// Returns only the entries whose `sortOrder` actually changed, so a drag
/// writes the minimum number of documents instead of the whole list.
List<WatchItem> reorderWatchItems(
  List<WatchItem> items,
  int oldIndex,
  int newIndex,
) {
  if (oldIndex < 0 || oldIndex >= items.length) return const [];
  if (newIndex < 0 || newIndex >= items.length || newIndex == oldIndex) {
    return const [];
  }

  final reordered = List.of(items);
  reordered.insert(newIndex, reordered.removeAt(oldIndex));

  final changed = <WatchItem>[];
  for (var i = 0; i < reordered.length; i++) {
    if (reordered[i].sortOrder != i) {
      changed.add(reordered[i].copyWith(sortOrder: i));
    }
  }
  return changed;
}
