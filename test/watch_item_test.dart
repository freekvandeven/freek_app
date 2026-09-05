import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/watchlist/models/watch_item.dart';
import 'package:personal_app/features/watchlist/services/watchlist_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  group('WatchItem model (WISH-0098)', () {
    test('defaults to an unwatched movie with no priority', () {
      final item = WatchItem(title: 'Arrival');

      expect(item.type, WatchItemType.movie);
      expect(item.status, WatchStatus.unwatched);
      expect(item.isFullyWatched, isFalse);
      expect(item.seasons, isEmpty);
      expect(item.platformIds, isEmpty);
      expect(item.sortOrder, 0);
      expect(item.imdbUrl, isNull);
    });

    test('toMap/fromMap round-trips every field', () {
      final item = WatchItem(
        type: WatchItemType.series,
        title: 'Severance',
        description: 'Work-life balance, surgically enforced.',
        imdbId: 'tt11280740',
        year: 2022,
        runtimeMinutes: 50,
        posterUrl: 'https://example.com/poster.jpg',
        sourceUrl: 'magnet:?xt=urn:btih:example',
        platformIds: const ['apple-tv'],
        watched: true,
        watchedAt: DateTime(2026, 3, 1),
        rating: 4.5,
        review: 'Best cold open on television.',
        seasons: const [
          Season(number: 1, title: 'Season 1', episodeCount: 9, watched: true),
          Season(number: 2, episodeCount: 10),
        ],
        sortOrder: 3,
      );

      final restored = WatchItem.fromMap(item.toMap());

      expect(restored.id, item.id);
      expect(restored.type, WatchItemType.series);
      expect(restored.title, 'Severance');
      expect(restored.description, item.description);
      expect(restored.imdbId, 'tt11280740');
      expect(restored.year, 2022);
      expect(restored.runtimeMinutes, 50);
      expect(restored.posterUrl, item.posterUrl);
      expect(restored.sourceUrl, 'magnet:?xt=urn:btih:example');
      expect(restored.platformIds, ['apple-tv']);
      expect(restored.watched, isTrue);
      expect(restored.watchedAt, DateTime(2026, 3, 1));
      expect(restored.rating, 4.5);
      expect(restored.review, item.review);
      expect(restored.sortOrder, 3);
      expect(restored.seasons, hasLength(2));
      expect(restored.seasons[0].title, 'Season 1');
      expect(restored.seasons[0].episodeCount, 9);
      expect(restored.seasons[0].watched, isTrue);
      expect(restored.seasons[1].number, 2);
      expect(restored.seasons[1].watched, isFalse);
    });

    test('fromMap tolerates a document missing the newer fields', () {
      final restored = WatchItem.fromMap({
        'id': 'legacy-id',
        'title': 'Heat',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(restored.title, 'Heat');
      expect(restored.type, WatchItemType.movie);
      expect(restored.watched, isFalse);
      expect(restored.seasons, isEmpty);
      expect(restored.platformIds, isEmpty);
      expect(restored.sortOrder, 0);
    });

    test('copyWith updates values and the clear flags null them out', () {
      final item = WatchItem(
        title: 'Dune',
        imdbId: 'tt1160419',
        rating: 4.0,
        runtimeMinutes: 155,
      );

      final rated = item.copyWith(rating: 5.0, title: 'Dune: Part One');
      expect(rated.title, 'Dune: Part One');
      expect(rated.rating, 5.0);
      expect(rated.imdbId, 'tt1160419');
      expect(rated.id, item.id);

      final cleared = item.copyWith(clearRating: true, clearImdbId: true);
      expect(cleared.rating, isNull);
      expect(cleared.imdbId, isNull);
      expect(cleared.runtimeMinutes, 155);
    });

    test('builds an IMDb url from the stored code', () {
      final item = WatchItem(title: 'Alien', imdbId: 'tt0078748');
      expect(item.imdbUrl, 'https://www.imdb.com/title/tt0078748/');
    });
  });

  group('WatchItem.status (WISH-0098)', () {
    WatchItem series(List<Season> seasons, {bool watched = false}) => WatchItem(
      type: WatchItemType.series,
      title: 'Show',
      watched: watched,
      seasons: seasons,
    );

    test('a movie follows its own watched flag', () {
      expect(WatchItem(title: 'Heat').status, WatchStatus.unwatched);
      expect(
        WatchItem(title: 'Heat', watched: true).status,
        WatchStatus.watched,
      );
    });

    test('a series without seasons falls back to the watched flag', () {
      expect(series(const []).status, WatchStatus.unwatched);
      expect(series(const [], watched: true).status, WatchStatus.watched);
    });

    test('a series is partially watched when only some seasons are', () {
      final show = series(const [
        Season(number: 1, watched: true),
        Season(number: 2),
      ]);
      expect(show.status, WatchStatus.partiallyWatched);
      expect(show.isFullyWatched, isFalse);
    });

    test('a series is watched only when every season is', () {
      final show = series(const [
        Season(number: 1, watched: true),
        Season(number: 2, watched: true),
      ]);
      expect(show.status, WatchStatus.watched);
      expect(show.isFullyWatched, isTrue);
    });

    test('adding a new season reopens a finished series', () {
      final finished = series(const [
        Season(number: 1, watched: true),
        Season(number: 2, watched: true),
      ], watched: true);
      expect(finished.status, WatchStatus.watched);

      final withNewSeason = finished.copyWith(
        seasons: [...finished.seasons, const Season(number: 3)],
      );

      // The stale whole-entry flag must not win over the new season.
      expect(withNewSeason.watched, isTrue);
      expect(withNewSeason.status, WatchStatus.partiallyWatched);
      expect(withNewSeason.isFullyWatched, isFalse);
    });
  });

  group('WatchItem.totalRuntimeMinutes (WISH-0098)', () {
    test('is the plain runtime for a movie', () {
      expect(
        WatchItem(title: 'Heat', runtimeMinutes: 170).totalRuntimeMinutes,
        170,
      );
    });

    test('is runtime times total episodes for a series', () {
      final show = WatchItem(
        type: WatchItemType.series,
        title: 'Severance',
        runtimeMinutes: 50,
        seasons: const [
          Season(number: 1, episodeCount: 9),
          Season(number: 2, episodeCount: 10),
        ],
      );
      expect(show.totalRuntimeMinutes, 950);
    });

    test('is null when runtime or any episode count is unknown', () {
      expect(WatchItem(title: 'Unknown').totalRuntimeMinutes, isNull);

      final partial = WatchItem(
        type: WatchItemType.series,
        title: 'Show',
        runtimeMinutes: 45,
        seasons: const [Season(number: 1, episodeCount: 8), Season(number: 2)],
      );
      expect(partial.totalRuntimeMinutes, isNull);
    });
  });

  group('MockWatchlistService (WISH-0098)', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('emits on listen and again after every mutation', () async {
      final service = MockWatchlistService();
      addTearDown(service.dispose);

      final emissions = <List<WatchItem>>[];
      final sub = service.watchItems().listen(emissions.add);
      await pumpEventQueue();

      final item = WatchItem(title: 'Arrival');
      await service.addItem(item);
      await service.updateItem(item.copyWith(watched: true));
      await service.deleteItem(item.id);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.length, 4);
      expect(emissions[0], isEmpty);
      expect(emissions[1].single.title, 'Arrival');
      expect(emissions[2].single.watched, isTrue);
      expect(emissions[3], isEmpty);
    });

    test('sorts by priority, falling back to title', () async {
      final service = MockWatchlistService();
      addTearDown(service.dispose);

      await service.addItem(WatchItem(title: 'Zodiac', sortOrder: 2));
      await service.addItem(WatchItem(title: 'Whiplash', sortOrder: 0));
      await service.addItem(WatchItem(title: 'Amadeus', sortOrder: 0));

      final items = await service.getItems();
      expect(items.map((i) => i.title), ['Amadeus', 'Whiplash', 'Zodiac']);
    });

    test('getItem returns null for an unknown id', () async {
      final service = MockWatchlistService();
      addTearDown(service.dispose);

      expect(await service.getItem('nope'), isNull);
    });
  });
}
