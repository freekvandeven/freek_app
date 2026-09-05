import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/watchlist/models/watch_item.dart';
import 'package:personal_app/features/watchlist/pages/watchlist_page.dart';
import 'package:personal_app/features/watchlist/providers/watchlist_providers.dart';

class _FakeWatchlistNotifier extends WatchlistNotifier {
  final List<WatchItem> items;
  _FakeWatchlistNotifier(this.items);

  @override
  Stream<List<WatchItem>> build() => Stream.value(items);
}

List<WatchItem> _sorted(List<WatchItem> items, WatchSort sort) =>
    List.of(items)..sort((a, b) => compareWatchItems(a, b, sort));

void main() {
  group('compareWatchItems (WISH-0098)', () {
    test('priority uses sortOrder, falling back to title', () {
      final items = [
        WatchItem(title: 'Zodiac', sortOrder: 1),
        WatchItem(title: 'Arrival', sortOrder: 0),
        WatchItem(title: 'Amadeus', sortOrder: 0),
      ];

      expect(_sorted(items, WatchSort.priority).map((i) => i.title), [
        'Amadeus',
        'Arrival',
        'Zodiac',
      ]);
    });

    test('title sorts case-insensitively', () {
      final items = [WatchItem(title: 'zodiac'), WatchItem(title: 'Arrival')];

      expect(_sorted(items, WatchSort.title).map((i) => i.title), [
        'Arrival',
        'zodiac',
      ]);
    });

    test('year sorts newest first', () {
      final items = [
        WatchItem(title: 'Old', year: 1995),
        WatchItem(title: 'New', year: 2026),
      ];

      expect(_sorted(items, WatchSort.year).map((i) => i.title), [
        'New',
        'Old',
      ]);
    });

    test('rating sorts best first', () {
      final items = [
        WatchItem(title: 'Fine', rating: 3.0),
        WatchItem(title: 'Great', rating: 5.0),
      ];

      expect(_sorted(items, WatchSort.rating).map((i) => i.title), [
        'Great',
        'Fine',
      ]);
    });

    test('runtime sorts shortest first, using the whole-series length', () {
      final items = [
        WatchItem(title: 'Movie', runtimeMinutes: 170),
        WatchItem(
          type: WatchItemType.series,
          title: 'Series',
          runtimeMinutes: 50,
          seasons: const [Season(number: 1, episodeCount: 9)],
        ),
      ];

      // The series is 450 minutes in total, so the movie comes first.
      expect(_sorted(items, WatchSort.runtime).map((i) => i.title), [
        'Movie',
        'Series',
      ]);
    });

    test('entries missing the sorted value sink to the bottom', () {
      final items = [
        WatchItem(title: 'Unrated'),
        WatchItem(title: 'Rated', rating: 2.0),
      ];

      expect(_sorted(items, WatchSort.rating).map((i) => i.title), [
        'Rated',
        'Unrated',
      ]);
    });
  });

  group('WatchlistPage filtering and sorting (WISH-0098)', () {
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

    testWidgets('filters to unwatched entries', (tester) async {
      await pump(tester, [
        WatchItem(title: 'Seen', watched: true),
        WatchItem(title: 'Unseen'),
      ]);

      await tester.tap(find.text('Unwatched'));
      await tester.pumpAndSettle();

      expect(find.text('Unseen'), findsOneWidget);
      expect(find.text('Seen'), findsNothing);
    });

    testWidgets('the in-progress filter catches part-watched series', (
      tester,
    ) async {
      await pump(tester, [
        WatchItem(
          type: WatchItemType.series,
          title: 'Halfway',
          seasons: const [Season(number: 1, watched: true), Season(number: 2)],
        ),
        WatchItem(title: 'Untouched'),
        WatchItem(title: 'Done', watched: true),
      ]);

      await tester.tap(find.text('In progress'));
      await tester.pumpAndSettle();

      expect(find.text('Halfway'), findsOneWidget);
      expect(find.text('Untouched'), findsNothing);
      expect(find.text('Done'), findsNothing);
    });

    testWidgets('sorting by title reorders the visible list', (tester) async {
      final container = await pump(tester, [
        WatchItem(title: 'Zodiac', sortOrder: 0),
        WatchItem(title: 'Arrival', sortOrder: 1),
      ]);

      container.read(watchlistSortProvider.notifier).state = WatchSort.title;
      await tester.pumpAndSettle();

      final titles = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((t) => t == 'Arrival' || t == 'Zodiac')
          .toList();
      expect(titles.first, 'Arrival');
    });

    testWidgets('reordering is disabled unless sorted by priority', (
      tester,
    ) async {
      final container = await pump(tester, [WatchItem(title: 'Heat')]);

      IconButton reorderButton() => tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.swap_vert),
          matching: find.byType(IconButton),
        ),
      );

      expect(reorderButton().onPressed, isNotNull);

      container.read(watchlistSortProvider.notifier).state = WatchSort.title;
      await tester.pumpAndSettle();

      expect(reorderButton().onPressed, isNull);
    });

    testWidgets('reordering is disabled while a status filter is active', (
      tester,
    ) async {
      await pump(tester, [WatchItem(title: 'Heat')]);

      await tester.tap(find.text('Unwatched'));
      await tester.pumpAndSettle();

      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.swap_vert),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });
}
