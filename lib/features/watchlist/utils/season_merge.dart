import '../models/watch_item.dart';

/// Merges freshly [fetched] season metadata onto the seasons the user
/// already has, keeping their watched state (WISH-0100).
///
/// This is the point where the wish's headline behaviour falls out: a show
/// that has gained a season keeps every season the user already ticked off
/// and gains the new one as unwatched, so its derived status drops from
/// watched back to partially watched.
///
/// Seasons the user added by hand that TMDB does not know about are kept
/// rather than deleted — losing watched history to a metadata refresh
/// would be worse than carrying an extra row.
List<Season> mergeSeasons(List<Season> existing, List<Season> fetched) {
  final existingByNumber = {
    for (final season in existing) season.number: season,
  };
  final fetchedNumbers = fetched.map((s) => s.number).toSet();

  final merged = <Season>[
    for (final season in fetched)
      if (existingByNumber[season.number] case final previous?)
        season.copyWith(
          watched: previous.watched,
          watchedAt: previous.watchedAt,
          clearWatchedAt: previous.watchedAt == null,
          // Episode ticks are watch history too — a metadata refresh
          // must not wipe them (WISH-0104).
          watchedEpisodes: previous.watchedEpisodes,
        )
      else
        season,
    for (final season in existing)
      if (!fetchedNumbers.contains(season.number)) season,
  ]..sort((a, b) => a.number.compareTo(b.number));

  return merged;
}
