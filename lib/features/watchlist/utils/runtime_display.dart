import '../models/watch_item.dart';

/// The runtime figure a row shows for [item], and whether it is the
/// still-to-watch number rather than the whole length (WISH-0103).
///
/// A partly watched series shows what is left, since that is what has to
/// fit into an evening. A finished one falls back to its total length —
/// "0m left" says nothing useful — and an untouched one shows its total
/// too, which is the same number as its remaining time anyway.
///
/// Sorting reads the same function as the list and detail pages, so the
/// order can never disagree with the numbers shown on the rows.
({int? minutes, bool isRemaining}) runtimeForDisplay(WatchItem item) {
  final total = item.totalRuntimeMinutes;
  if (item.isFullyWatched) return (minutes: total, isRemaining: false);

  final remaining = item.remainingRuntimeMinutes;
  return (minutes: remaining, isRemaining: remaining != total);
}
