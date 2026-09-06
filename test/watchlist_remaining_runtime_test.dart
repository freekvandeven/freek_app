import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/watchlist/models/watch_item.dart';
import 'package:personal_app/features/watchlist/pages/watchlist_page.dart';
import 'package:personal_app/features/watchlist/providers/watchlist_providers.dart';
import 'package:personal_app/features/watchlist/utils/runtime_display.dart';

class _FakeWatchlistNotifier extends WatchlistNotifier {
  final List<WatchItem> items;
  _FakeWatchlistNotifier(this.items);

  @override
  Stream<List<WatchItem>> build() => Stream.value(items);
}

/// Severance-shaped: 50 minute episodes, 9 + 10 = 19 episodes = 950 min.
WatchItem show({bool s1 = false, bool s2 = false}) => WatchItem(
  type: WatchItemType.series,
  title: 'Severance',
  runtimeMinutes: 50,
  seasons: [
    Season(number: 1, episodeCount: 9, watched: s1),
    Season(number: 2, episodeCount: 10, watched: s2),
  ],
);

void main() {
  group('WatchItem.remainingRuntimeMinutes (WISH-0103)', () {
    test('is the whole show when nothing has been watched', () {
      expect(show().remainingRuntimeMinutes, 950);
      expect(show().totalRuntimeMinutes, 950);
    });

    test('counts only the unwatched seasons', () {
      // Season 1 done: 10 episodes x 50 minutes left.
      expect(show(s1: true).remainingRuntimeMinutes, 500);
      // Season 2 done: 9 episodes x 50 minutes left.
      expect(show(s2: true).remainingRuntimeMinutes, 450);
    });

    test('is zero once every season has been watched', () {
      expect(show(s1: true, s2: true).remainingRuntimeMinutes, 0);
      // The whole-show figure is unaffected.
      expect(show(s1: true, s2: true).totalRuntimeMinutes, 950);
    });

    test('follows the watched flag for a movie', () {
      final movie = WatchItem(title: 'Heat', runtimeMinutes: 170);
      expect(movie.remainingRuntimeMinutes, 170);
      expect(movie.copyWith(watched: true).remainingRuntimeMinutes, 0);
    });

    test('is null when the runtime is unknown', () {
      expect(WatchItem(title: 'Mystery').remainingRuntimeMinutes, isNull);
    });

    test('is null when an unwatched season has no episode count', () {
      final partial = WatchItem(
        type: WatchItemType.series,
        title: 'Show',
        runtimeMinutes: 45,
        seasons: const [
          Season(number: 1, episodeCount: 8, watched: true),
          Season(number: 2),
        ],
      );

      expect(partial.remainingRuntimeMinutes, isNull);
    });

    test('ignores a missing episode count on an already watched season', () {
      // What is left is still knowable even if the watched part is not.
      final partial = WatchItem(
        type: WatchItemType.series,
        title: 'Show',
        runtimeMinutes: 45,
        seasons: const [
          Season(number: 1, watched: true),
          Season(number: 2, episodeCount: 10),
        ],
      );

      expect(partial.remainingRuntimeMinutes, 450);
      // The whole-show figure cannot be computed, though.
      expect(partial.totalRuntimeMinutes, isNull);
    });
  });

  group('runtimeForDisplay (WISH-0103)', () {
    test('shows the total, unlabelled, for an untouched show', () {
      final result = runtimeForDisplay(show());
      expect(result.minutes, 950);
      expect(result.isRemaining, isFalse);
    });

    test('shows what is left for a partly watched show', () {
      final result = runtimeForDisplay(show(s1: true));
      expect(result.minutes, 500);
      expect(result.isRemaining, isTrue);
    });

    test('falls back to the total once finished, rather than 0m left', () {
      final result = runtimeForDisplay(show(s1: true, s2: true));
      expect(result.minutes, 950);
      expect(result.isRemaining, isFalse);
    });
  });

  group('Watchlist runtime display and sort (WISH-0103)', () {
    Future<ProviderContainer> pump(
      WidgetTester tester,
      List<WatchItem> items,
    ) async {
      final container = ProviderContainer(
        overrides: [
          watchlistProvider.overrideWith(() => _FakeWatchlistNotifier(items)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: WatchlistPage()),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('labels the remaining time on a partly watched series', (
      tester,
    ) async {
      await pump(tester, [show(s1: true)]);

      // 10 remaining episodes x 50 minutes, not the full 15h 50m.
      expect(find.textContaining('8h 20m left'), findsOneWidget);
      expect(find.textContaining('15h 50m'), findsNothing);
    });

    testWidgets('shows the plain total for an untouched series', (
      tester,
    ) async {
      await pump(tester, [show()]);

      expect(find.textContaining('15h 50m'), findsOneWidget);
      expect(find.textContaining('left'), findsNothing);
    });

    testWidgets('sorts on the figure the rows actually show', (tester) async {
      final container = await pump(tester, [
        // 8h 20m left after season 1.
        show(s1: true),
        // A 10 hour film, longer than what is left of the series.
        WatchItem(title: 'Long Film', runtimeMinutes: 600),
      ]);

      container.read(watchlistSortProvider.notifier).state = WatchSort.runtime;
      await tester.pumpAndSettle();

      final titles = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((t) => t == 'Severance' || t == 'Long Film')
          .toList();
      // Shortest first: 500 minutes left beats the 600 minute film, even
      // though the whole series is 950 minutes.
      expect(titles.first, 'Severance');
    });
  });
}
