import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/watchlist/models/watch_item.dart';
import 'package:personal_app/features/watchlist/pages/watchlist_page.dart';
import 'package:personal_app/features/watchlist/providers/watchlist_providers.dart';
import 'package:personal_app/presentation/theme/app_scroll_behavior.dart';

class _FakeWatchlistNotifier extends WatchlistNotifier {
  final List<WatchItem> items;
  final reorders = <({int from, int to})>[];
  int refreshes = 0;
  _FakeWatchlistNotifier(this.items);

  @override
  Stream<List<WatchItem>> build() {
    refreshes++;
    return Stream.value(items);
  }

  @override
  Future<void> reorder(int oldIndex, int newIndex) async {
    reorders.add((from: oldIndex, to: newIndex));
  }
}

/// Pumps the page with the app-wide scroll behaviour, which is what makes
/// a mouse a drag device and so what let a mis-aimed drag turn into a
/// pull-to-refresh (WISH-0090 / BUG-0053).
Future<_FakeWatchlistNotifier> _pump(
  WidgetTester tester,
  List<String> titles,
) async {
  final notifier = _FakeWatchlistNotifier([
    for (var i = 0; i < titles.length; i++)
      WatchItem(title: titles[i], sortOrder: i),
  ]);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [watchlistProvider.overrideWith(() => notifier)],
      child: MaterialApp(
        scrollBehavior: AppScrollBehavior(),
        home: const WatchlistPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return notifier;
}

Future<void> _enterReorderMode(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.swap_vert));
  await tester.pumpAndSettle();
}

void main() {
  group('Watchlist reorder gestures (BUG-0053)', () {
    testWidgets('the reorderable list is not wrapped in a RefreshIndicator', (
      tester,
    ) async {
      await _pump(tester, ['A', 'B']);
      expect(find.byType(RefreshIndicator), findsOneWidget);

      await _enterReorderMode(tester);

      // Pull-to-refresh would otherwise compete for the same drag.
      expect(find.byType(RefreshIndicator), findsNothing);
      expect(find.byType(ReorderableListView), findsOneWidget);
    });

    testWidgets('pull-to-refresh comes back on leaving reorder mode', (
      tester,
    ) async {
      await _pump(tester, ['A', 'B']);

      await _enterReorderMode(tester);
      expect(find.byType(RefreshIndicator), findsNothing);

      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('every row carries a real drag handle, not a look-alike', (
      tester,
    ) async {
      await _pump(tester, ['A', 'B', 'C']);
      await _enterReorderMode(tester);

      // Exactly one handle per row — the framework's own handles are
      // suppressed, so there is no second, real handle hiding under a
      // look-alike icon.
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
      // And every one of them is inside a listener that starts a drag.
      expect(
        find.descendant(
          of: find.byType(ReorderableDragStartListener),
          matching: find.byIcon(Icons.drag_handle),
        ),
        findsNWidgets(3),
      );
    });

    testWidgets('dragging a handle with a mouse reorders the list', (
      tester,
    ) async {
      final notifier = await _pump(tester, ['A', 'B', 'C']);
      await _enterReorderMode(tester);

      final firstHandle = find.byIcon(Icons.drag_handle).first;
      final gesture = await tester.startGesture(
        tester.getCenter(firstHandle),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 50));
      // Far enough to land past the second row.
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(notifier.reorders, isNotEmpty);
      expect(notifier.reorders.single.from, 0);
      expect(notifier.reorders.single.to, greaterThan(0));
    });

    testWidgets('a mouse drag while reordering does not trigger a refresh', (
      tester,
    ) async {
      final notifier = await _pump(tester, ['A', 'B', 'C']);
      await _enterReorderMode(tester);
      final buildsBefore = notifier.refreshes;

      // Drag downwards from the middle of a row, the gesture that used to
      // be swallowed by pull-to-refresh.
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('A')),
        kind: PointerDeviceKind.mouse,
      );
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 25));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(notifier.refreshes, buildsBefore);
    });
  });
}
