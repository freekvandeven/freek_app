import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/watchlist/models/watch_item.dart';
import 'package:personal_app/features/watchlist/pages/watch_item_detail_page.dart';
import 'package:personal_app/features/watchlist/providers/watchlist_providers.dart';
import 'package:personal_app/features/watchlist/utils/runtime_display.dart';
import 'package:personal_app/features/watchlist/utils/season_merge.dart';

class _FakeWatchlistNotifier extends WatchlistNotifier {
  final List<WatchItem> items;
  final updated = <WatchItem>[];
  _FakeWatchlistNotifier(this.items);

  @override
  Stream<List<WatchItem>> build() => Stream.value(items);

  @override
  Future<void> updateItem(WatchItem item) async => updated.add(item);
}

void main() {
  group('Season episode tracking (WISH-0104)', () {
    const untracked = Season(number: 1, episodeCount: 10);

    test('a season with no ticks falls back to its watched flag', () {
      expect(untracked.tracksEpisodes, isFalse);
      expect(untracked.status, WatchStatus.unwatched);
      expect(untracked.watchedEpisodeCount, 0);
      expect(untracked.remainingEpisodes, 10);

      const ticked = Season(number: 1, episodeCount: 10, watched: true);
      expect(ticked.status, WatchStatus.watched);
      expect(ticked.watchedEpisodeCount, 10);
      expect(ticked.remainingEpisodes, 0);
    });

    test('ticking episodes makes the season partially watched', () {
      final season = untracked.withEpisodeWatched(1, true);

      expect(season.tracksEpisodes, isTrue);
      expect(season.status, WatchStatus.partiallyWatched);
      expect(season.watchedEpisodeCount, 1);
      expect(season.remainingEpisodes, 9);
      expect(season.watched, isFalse);
    });

    test('ticking the last episode completes the season', () {
      var season = untracked;
      for (var episode = 1; episode <= 10; episode++) {
        season = season.withEpisodeWatched(episode, true);
      }

      expect(season.status, WatchStatus.watched);
      expect(season.remainingEpisodes, 0);
      // The flag is kept in step so nothing reading it disagrees.
      expect(season.watched, isTrue);
      expect(season.watchedAt, isNotNull);
    });

    test('a season marked watched reads as every episode watched', () {
      const season = Season(number: 1, episodeCount: 4, watched: true);

      expect(season.isEpisodeWatched(1), isTrue);
      expect(season.isEpisodeWatched(4), isTrue);
    });

    test('unticking one episode of a watched season keeps the rest', () {
      const watchedSeason = Season(number: 1, episodeCount: 4, watched: true);

      final season = watchedSeason.withEpisodeWatched(3, false);

      expect(season.watchedEpisodes, [1, 2, 4]);
      expect(season.status, WatchStatus.partiallyWatched);
      expect(season.watched, isFalse);
      expect(season.watchedAt, isNull);
      expect(season.remainingEpisodes, 1);
    });

    test('ticks outside the known run are ignored', () {
      // A TMDB refresh can shrink a season; a stale tick must not read
      // as "11 of 10 watched".
      const season = Season(
        number: 1,
        episodeCount: 3,
        watchedEpisodes: [1, 2, 3, 9],
      );

      expect(season.watchedEpisodeCount, 3);
      expect(season.status, WatchStatus.watched);
      expect(season.remainingEpisodes, 0);
    });

    test('duplicate ticks are not double counted', () {
      const season = Season(
        number: 1,
        episodeCount: 5,
        watchedEpisodes: [2, 2, 3],
      );

      expect(season.watchedEpisodeCount, 2);
    });

    test('an unknown episode count keeps the season on its flag', () {
      const season = Season(number: 1, watchedEpisodes: [1, 2]);

      expect(season.status, WatchStatus.unwatched);
      expect(season.remainingEpisodes, isNull);
    });

    test('round-trips through toMap/fromMap', () {
      const season = Season(
        number: 2,
        episodeCount: 8,
        watchedEpisodes: [1, 2, 5],
      );

      final restored = Season.fromMap(season.toMap());
      expect(restored.watchedEpisodes, [1, 2, 5]);
      expect(restored.watchedEpisodeCount, 3);
    });

    test('a season stored before episode tracking loads unchanged', () {
      final restored = Season.fromMap({
        'number': 1,
        'episodeCount': 9,
        'watched': true,
      });

      expect(restored.watchedEpisodes, isEmpty);
      expect(restored.tracksEpisodes, isFalse);
      expect(restored.status, WatchStatus.watched);
    });
  });

  group('Show status with part-watched seasons (WISH-0104)', () {
    test('a show with a part-watched season is partially watched', () {
      final show = WatchItem(
        type: WatchItemType.series,
        title: 'Severance',
        seasons: [
          const Season(number: 1, episodeCount: 9).withEpisodeWatched(1, true),
          const Season(number: 2, episodeCount: 10),
        ],
      );

      // Before episode tracking this read as unwatched, since no whole
      // season was done.
      expect(show.status, WatchStatus.partiallyWatched);
    });

    test('a show is watched only when every season is complete', () {
      final show = WatchItem(
        type: WatchItemType.series,
        title: 'Show',
        seasons: const [
          Season(number: 1, episodeCount: 2, watchedEpisodes: [1, 2]),
          Season(number: 2, episodeCount: 2, watchedEpisodes: [1]),
        ],
      );
      expect(show.status, WatchStatus.partiallyWatched);

      final finished = show.copyWith(
        seasons: [
          show.seasons.first,
          show.seasons.last.withEpisodeWatched(2, true),
        ],
      );
      expect(finished.status, WatchStatus.watched);
    });
  });

  group('Remaining runtime with episodes (WISH-0104)', () {
    WatchItem show(List<Season> seasons) => WatchItem(
      type: WatchItemType.series,
      title: 'Severance',
      runtimeMinutes: 50,
      seasons: seasons,
    );

    test('being halfway through a season shortens the time left', () {
      final halfway = show([
        const Season(
          number: 1,
          episodeCount: 10,
          watchedEpisodes: [1, 2, 3, 4, 5],
        ),
        const Season(number: 2, episodeCount: 10),
      ]);

      // 15 episodes left of 20, not 10 (which whole-season counting gave).
      expect(halfway.remainingRuntimeMinutes, 750);
      expect(halfway.totalRuntimeMinutes, 1000);
      expect(runtimeForDisplay(halfway).isRemaining, isTrue);
    });

    test('is zero once every episode is watched', () {
      final done = show([
        const Season(number: 1, episodeCount: 2, watchedEpisodes: [1, 2]),
      ]);

      expect(done.remainingRuntimeMinutes, 0);
      // A finished show falls back to its total for display.
      expect(runtimeForDisplay(done).minutes, 100);
      expect(runtimeForDisplay(done).isRemaining, isFalse);
    });

    test('an unwatched season of unknown length still blocks the sum', () {
      final unknown = show([
        const Season(number: 1, episodeCount: 4, watchedEpisodes: [1]),
        const Season(number: 2),
      ]);

      expect(unknown.remainingRuntimeMinutes, isNull);
    });
  });

  group('mergeSeasons keeps episode ticks (WISH-0104)', () {
    test('a metadata refresh does not wipe watched episodes', () {
      const existing = [
        Season(number: 1, episodeCount: 9, watchedEpisodes: [1, 2, 3]),
      ];

      final merged = mergeSeasons(existing, const [
        Season(number: 1, title: 'Season 1', episodeCount: 9),
        Season(number: 2, episodeCount: 10),
      ]);

      expect(merged.first.watchedEpisodes, [1, 2, 3]);
      expect(merged.first.title, 'Season 1');
      expect(merged.last.watchedEpisodes, isEmpty);
    });
  });

  group('Season toggle clears episode ticks (WISH-0104)', () {
    test('marking the whole season replaces the episode record', () {
      final show = WatchItem(
        type: WatchItemType.series,
        title: 'Show',
        seasons: const [
          Season(number: 1, episodeCount: 5, watchedEpisodes: [1, 2]),
        ],
      );

      final watched = show.withSeasonWatched(1, true);
      expect(watched.seasons.first.watchedEpisodes, isEmpty);
      expect(watched.seasons.first.status, WatchStatus.watched);

      final cleared = watched.withSeasonWatched(1, false);
      expect(cleared.seasons.first.watchedEpisodes, isEmpty);
      expect(cleared.seasons.first.status, WatchStatus.unwatched);
    });
  });

  group('WatchItemDetailPage episodes (WISH-0104)', () {
    Future<_FakeWatchlistNotifier> pump(
      WidgetTester tester,
      WatchItem item,
    ) async {
      final notifier = _FakeWatchlistNotifier([item]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [watchlistProvider.overrideWith(() => notifier)],
          child: MaterialApp(home: WatchItemDetailPage(itemId: item.id)),
        ),
      );
      await tester.pumpAndSettle();
      return notifier;
    }

    WatchItem show(List<Season> seasons) => WatchItem(
      type: WatchItemType.series,
      title: 'Severance',
      runtimeMinutes: 50,
      seasons: seasons,
    );

    testWidgets('a season expands into one chip per episode', (tester) async {
      await pump(tester, show(const [Season(number: 1, episodeCount: 3)]));

      expect(find.text('1'), findsNothing);
      await tester.tap(find.text('Season 1'));
      await tester.pumpAndSettle();

      for (final episode in ['1', '2', '3']) {
        expect(find.widgetWithText(FilterChip, episode), findsOneWidget);
      }
    });

    testWidgets('tapping an episode persists just that episode', (
      tester,
    ) async {
      final notifier = await pump(
        tester,
        show(const [Season(number: 1, episodeCount: 3)]),
      );

      await tester.tap(find.text('Season 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, '2'));
      await tester.pumpAndSettle();

      expect(notifier.updated, hasLength(1));
      final season = notifier.updated.single.seasons.single;
      expect(season.watchedEpisodes, [2]);
      expect(season.status, WatchStatus.partiallyWatched);
    });

    testWidgets('shows how far through a part-watched season you are', (
      tester,
    ) async {
      await pump(
        tester,
        show(const [
          Season(number: 1, episodeCount: 10, watchedEpisodes: [1, 2, 3]),
        ]),
      );

      expect(find.text('3 of 10 episodes'), findsOneWidget);
    });

    testWidgets('a season with no episode count stays a plain row', (
      tester,
    ) async {
      await pump(tester, show(const [Season(number: 1)]));

      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('Season 1'), findsOneWidget);
    });
  });
}
