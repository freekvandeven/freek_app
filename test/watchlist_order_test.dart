import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/watchlist/models/watch_item.dart';
import 'package:personal_app/features/watchlist/pages/watchlist_page.dart';
import 'package:personal_app/features/watchlist/providers/watchlist_providers.dart';
import 'package:personal_app/features/watchlist/utils/watchlist_order.dart';

class _FakeWatchlistNotifier extends WatchlistNotifier {
  final List<WatchItem> items;
  _FakeWatchlistNotifier(this.items);

  @override
  Stream<List<WatchItem>> build() => Stream.value(items);
}

List<WatchItem> _queue(List<String> titles) => [
  for (var i = 0; i < titles.length; i++)
    WatchItem(title: titles[i], sortOrder: i),
];

void main() {
  group('reorderWatchItems (WISH-0098)', () {
    test('moving an entry up renumbers only the affected span', () {
      final items = _queue(['A', 'B', 'C', 'D']);

      // C (index 2) becomes the first thing to watch.
      final changed = reorderWatchItems(items, 2, 0);

      expect(changed.map((i) => i.title), ['C', 'A', 'B']);
      expect(changed.map((i) => i.sortOrder), [0, 1, 2]);
      // D never moved, so it is not rewritten.
      expect(changed.map((i) => i.title), isNot(contains('D')));
    });

    test('moving an entry down renumbers only the affected span', () {
      final items = _queue(['A', 'B', 'C', 'D']);

      final changed = reorderWatchItems(items, 0, 2);

      expect(changed.map((i) => i.title), ['B', 'C', 'A']);
      expect(changed.map((i) => i.sortOrder), [0, 1, 2]);
    });

    test('moving to the end puts the entry last', () {
      final items = _queue(['A', 'B', 'C']);

      final changed = reorderWatchItems(items, 0, 2);
      final byTitle = {for (final i in changed) i.title: i.sortOrder};

      expect(byTitle['A'], 2);
      expect(byTitle['B'], 0);
      expect(byTitle['C'], 1);
    });

    test('is a no-op when the entry does not move', () {
      final items = _queue(['A', 'B', 'C']);
      expect(reorderWatchItems(items, 1, 1), isEmpty);
    });

    test('is a no-op for out-of-range indexes', () {
      final items = _queue(['A', 'B']);

      expect(reorderWatchItems(items, -1, 0), isEmpty);
      expect(reorderWatchItems(items, 0, 5), isEmpty);
      expect(reorderWatchItems(items, 5, 0), isEmpty);
      expect(reorderWatchItems(const [], 0, 0), isEmpty);
    });

    test('renumbers a list whose sort orders start out duplicated', () {
      // Everything defaults to sortOrder 0 until the list is first
      // reordered, so the first drag has to assign real positions.
      final items = [
        WatchItem(title: 'A'),
        WatchItem(title: 'B'),
        WatchItem(title: 'C'),
      ];

      final changed = reorderWatchItems(items, 2, 0);

      expect(changed.map((i) => i.title), ['A', 'B']);
      expect(changed.map((i) => i.sortOrder), [1, 2]);
    });

    test('keeps the rest of each entry intact', () {
      final items = [
        WatchItem(title: 'A', sortOrder: 0, rating: 4.0, watched: true),
        WatchItem(title: 'B', sortOrder: 1),
      ];

      final changed = reorderWatchItems(items, 0, 1);
      final moved = changed.firstWhere((i) => i.title == 'A');

      expect(moved.sortOrder, 1);
      expect(moved.rating, 4.0);
      expect(moved.watched, isTrue);
      expect(moved.id, items[0].id);
    });
  });

  group('WatchlistPage reorder mode (WISH-0098)', () {
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

    testWidgets('toggling reorder mode swaps in drag handles', (tester) async {
      await pump(tester, _queue(['A', 'B']));

      expect(find.byIcon(Icons.drag_handle), findsNothing);

      await tester.tap(find.byIcon(Icons.swap_vert));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
      // The watched toggles step aside so a drag is unambiguous.
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    });

    testWidgets('reordering is disabled while a search is active', (
      tester,
    ) async {
      await pump(tester, _queue(['Heat', 'Arrival']));

      await tester.enterText(find.byType(TextField), 'heat');
      await tester.pumpAndSettle();

      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.swap_vert),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('an active search leaves reorder mode', (tester) async {
      await pump(tester, _queue(['Heat', 'Arrival']));

      await tester.tap(find.byIcon(Icons.swap_vert));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));

      await tester.enterText(find.byType(TextField), 'heat');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.drag_handle), findsNothing);
    });
  });
}
