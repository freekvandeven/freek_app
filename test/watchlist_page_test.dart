import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/watchlist/models/watch_item.dart';
import 'package:personal_app/features/watchlist/pages/watchlist_page.dart';
import 'package:personal_app/features/watchlist/providers/watchlist_providers.dart';
import 'package:personal_app/features/watchlist/widgets/watch_status_chip.dart';

class _FakeWatchlistNotifier extends WatchlistNotifier {
  final List<WatchItem> items;
  final updated = <WatchItem>[];
  _FakeWatchlistNotifier(this.items);

  @override
  Stream<List<WatchItem>> build() => Stream.value(items);

  @override
  Future<void> updateItem(WatchItem item) async => updated.add(item);
}

Future<_FakeWatchlistNotifier> _pump(
  WidgetTester tester,
  List<WatchItem> items,
) async {
  final notifier = _FakeWatchlistNotifier(items);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [watchlistProvider.overrideWith(() => notifier)],
      child: const MaterialApp(home: WatchlistPage()),
    ),
  );
  await tester.pumpAndSettle();
  return notifier;
}

void main() {
  group('WatchlistPage (WISH-0098)', () {
    testWidgets('shows an empty state when nothing is queued', (tester) async {
      await _pump(tester, []);

      expect(find.text('Nothing on the watchlist yet'), findsOneWidget);
    });

    testWidgets('lists entries with year and runtime', (tester) async {
      await _pump(tester, [
        WatchItem(title: 'Heat', year: 1995, runtimeMinutes: 170),
      ]);

      expect(find.text('Heat'), findsOneWidget);
      expect(find.text('1995 • 2h 50m'), findsOneWidget);
    });

    testWidgets('shows the total runtime for a series, not the episode '
        'length', (tester) async {
      await _pump(tester, [
        WatchItem(
          type: WatchItemType.series,
          title: 'Severance',
          runtimeMinutes: 50,
          seasons: const [
            Season(number: 1, episodeCount: 9),
            Season(number: 2, episodeCount: 10),
          ],
        ),
      ]);

      // 50 x 19 episodes = 950 minutes.
      expect(find.text('15h 50m'), findsOneWidget);
    });

    testWidgets('filters by the search field', (tester) async {
      await _pump(tester, [
        WatchItem(title: 'Heat'),
        WatchItem(title: 'Arrival'),
      ]);

      await tester.enterText(find.byType(TextField), 'arr');
      await tester.pumpAndSettle();

      expect(find.text('Arrival'), findsOneWidget);
      expect(find.text('Heat'), findsNothing);
    });

    testWidgets('the trailing button toggles watched', (tester) async {
      final notifier = await _pump(tester, [WatchItem(title: 'Heat')]);

      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();

      expect(notifier.updated, hasLength(1));
      expect(notifier.updated.single.watched, isTrue);
      expect(notifier.updated.single.watchedAt, isNotNull);
    });

    testWidgets('badges a partially watched series', (tester) async {
      await _pump(tester, [
        WatchItem(
          type: WatchItemType.series,
          title: 'Severance',
          seasons: const [Season(number: 1, watched: true), Season(number: 2)],
        ),
      ]);

      expect(find.text('Partially watched'), findsOneWidget);
    });
  });

  group('WatchStatusChip (WISH-0098)', () {
    Future<void> pumpChip(WidgetTester tester, WatchStatus status) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: WatchStatusChip(status: status)),
          ),
        );

    testWidgets('renders nothing for an unwatched entry', (tester) async {
      await pumpChip(tester, WatchStatus.unwatched);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('labels partially watched and watched entries', (tester) async {
      await pumpChip(tester, WatchStatus.partiallyWatched);
      expect(find.text('Partially watched'), findsOneWidget);

      await pumpChip(tester, WatchStatus.watched);
      expect(find.text('Watched'), findsOneWidget);
    });
  });
}
