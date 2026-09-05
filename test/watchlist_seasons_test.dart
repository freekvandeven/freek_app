import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/watchlist/models/watch_item.dart';
import 'package:personal_app/features/watchlist/pages/watch_item_detail_page.dart';
import 'package:personal_app/features/watchlist/providers/watchlist_providers.dart';
import 'package:personal_app/features/watchlist/widgets/seasons_editor.dart';

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
  group('WatchItem.withSeasonWatched (WISH-0098)', () {
    final show = WatchItem(
      type: WatchItemType.series,
      title: 'Severance',
      seasons: const [Season(number: 1), Season(number: 2)],
    );

    test('marks one season watched and stamps its date', () {
      final updated = show.withSeasonWatched(1, true);

      expect(updated.seasons[0].watched, isTrue);
      expect(updated.seasons[0].watchedAt, isNotNull);
      expect(updated.seasons[1].watched, isFalse);
      expect(updated.status, WatchStatus.partiallyWatched);
    });

    test('marking the last season watched completes the series', () {
      final updated = show
          .withSeasonWatched(1, true)
          .withSeasonWatched(2, true);

      expect(updated.status, WatchStatus.watched);
    });

    test('unmarking a season clears its date and reopens the series', () {
      final finished = show
          .withSeasonWatched(1, true)
          .withSeasonWatched(2, true);

      final reopened = finished.withSeasonWatched(2, false);

      expect(reopened.seasons[1].watched, isFalse);
      expect(reopened.seasons[1].watchedAt, isNull);
      expect(reopened.status, WatchStatus.partiallyWatched);
    });

    test('an unknown season number leaves the entry untouched', () {
      final updated = show.withSeasonWatched(99, true);

      expect(updated.seasons.every((s) => !s.watched), isTrue);
      expect(updated.status, WatchStatus.unwatched);
    });
  });

  group('SeasonsEditor (WISH-0098)', () {
    Future<List<Season>> pumpEditor(
      WidgetTester tester,
      List<Season> seasons,
    ) async {
      var current = seasons;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SeasonsEditor(
                seasons: current,
                onChanged: (updated) => setState(() => current = updated),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return current;
    }

    testWidgets('prompts when a series has no seasons yet', (tester) async {
      await pumpEditor(tester, const []);

      expect(find.textContaining('No seasons yet'), findsOneWidget);
    });

    testWidgets('lists seasons with their episode counts', (tester) async {
      await pumpEditor(tester, const [
        Season(number: 1, episodeCount: 9),
        Season(number: 2, title: 'The Return', episodeCount: 10),
      ]);

      expect(find.text('Season 1'), findsOneWidget);
      expect(find.text('9 episodes'), findsOneWidget);
      expect(find.text('The Return'), findsOneWidget);
    });

    testWidgets('adding a season defaults to the next number', (tester) async {
      await pumpEditor(tester, const [Season(number: 1)]);

      await tester.tap(find.text('Add Season'));
      await tester.pumpAndSettle();

      expect(find.text('Add Season'), findsWidgets);
      final numberField = tester.widget<TextField>(
        find.widgetWithText(TextField, '2'),
      );
      expect(numberField.controller!.text, '2');

      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text('Season 2'), findsOneWidget);
    });

    testWidgets('removing a season drops it from the list', (tester) async {
      await pumpEditor(tester, const [Season(number: 1), Season(number: 2)]);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(find.text('Season 1'), findsNothing);
      expect(find.text('Season 2'), findsOneWidget);
    });

    testWidgets('editing a season keeps its watched state', (tester) async {
      await pumpEditor(tester, const [
        Season(number: 1, watched: true, episodeCount: 9),
      ]);

      await tester.tap(find.text('Season 1'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, '9'), '10');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('10 episodes'), findsOneWidget);
    });
  });

  group('WatchItemDetailPage seasons (WISH-0098)', () {
    testWidgets('toggling a season persists it through the notifier', (
      tester,
    ) async {
      final show = WatchItem(
        type: WatchItemType.series,
        title: 'Severance',
        seasons: const [Season(number: 1), Season(number: 2)],
      );
      final notifier = _FakeWatchlistNotifier([show]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [watchlistProvider.overrideWith(() => notifier)],
          child: MaterialApp(home: WatchItemDetailPage(itemId: show.id)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Season 1'), findsOneWidget);
      expect(find.text('Season 2'), findsOneWidget);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      expect(notifier.updated, hasLength(1));
      final saved = notifier.updated.single;
      expect(saved.seasons[0].watched, isTrue);
      expect(saved.seasons[1].watched, isFalse);
      expect(saved.status, WatchStatus.partiallyWatched);
    });
  });
}
