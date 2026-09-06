import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/dashboard/destination_picker.dart';
import 'package:personal_app/features/knowledge/models/knowledge_page.dart';
import 'package:personal_app/features/knowledge/providers/knowledge_providers.dart';
import 'package:personal_app/features/watchlist/models/watch_item.dart';
import 'package:personal_app/features/watchlist/providers/watchlist_providers.dart';

class _FakeKnowledgeNotifier extends KnowledgeListNotifier {
  final List<KnowledgePage> pages;
  _FakeKnowledgeNotifier(this.pages);

  @override
  Stream<List<KnowledgePage>> build() => Stream.value(pages);
}

class _FakeWatchlistNotifier extends WatchlistNotifier {
  final List<WatchItem> items;
  _FakeWatchlistNotifier(this.items);

  @override
  Stream<List<WatchItem>> build() => Stream.value(items);
}

Future<PickedDestination?> _open(
  WidgetTester tester, {
  List<KnowledgePage> pages = const [],
  List<WatchItem> watchlist = const [],
}) async {
  PickedDestination? picked;
  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        knowledgeListProvider.overrideWith(() => _FakeKnowledgeNotifier(pages)),
        watchlistProvider.overrideWith(() => _FakeWatchlistNotifier(watchlist)),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await showDestinationPicker(context);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return picked;
}

void main() {
  group('matchesQuery (WISH-0108)', () {
    test('matches case-insensitively and ignores surrounding space', () {
      expect(matchesQuery('Knowledge', 'know'), isTrue);
      expect(matchesQuery('Knowledge', '  KNOW '), isTrue);
      expect(matchesQuery('Knowledge', 'zzz'), isFalse);
    });

    test('an empty query matches everything', () {
      expect(matchesQuery('Anything', ''), isTrue);
    });
  });

  group('kPickableFeatures (WISH-0108)', () {
    test('every feature has a route starting with a slash', () {
      for (final feature in kPickableFeatures) {
        expect(feature.rootRoute, startsWith('/'), reason: feature.label);
      }
    });

    test('the vault is linkable but never enumerated', () {
      final vault = kPickableFeatures.firstWhere(
        (f) => f.rootRoute == '/passwords',
      );
      // Its contents are encrypted and may be locked, so the picker
      // offers the feature without listing entries.
      expect(vault.isBrowsable, isFalse);
    });
  });

  group('DestinationPicker (WISH-0108)', () {
    testWidgets('opens on the feature list', (tester) async {
      await _open(tester);

      expect(find.text('Choose a destination'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Knowledge'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Watchlist'), findsOneWidget);
    });

    testWidgets('searching narrows the feature list', (tester) async {
      await _open(tester);

      await tester.enterText(find.byType(TextField), 'know');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Knowledge'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Watchlist'), findsNothing);
    });

    testWidgets('picking a non-browsable feature returns its route', (
      tester,
    ) async {
      await _open(tester);

      await tester.enterText(find.byType(TextField), 'calendar');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Calendar'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a destination'), findsNothing);
    });

    testWidgets('a browsable feature opens its items', (tester) async {
      await _open(
        tester,
        pages: [
          KnowledgePage(title: 'Pasta notes', content: ''),
          KnowledgePage(title: 'Server setup', content: ''),
        ],
      );

      await tester.tap(find.widgetWithText(ListTile, 'Knowledge'));
      await tester.pumpAndSettle();

      // Second step: the feature itself plus each of its pages.
      expect(find.text('Open Knowledge'), findsOneWidget);
      expect(find.text('Pasta notes'), findsOneWidget);
      expect(find.text('Server setup'), findsOneWidget);
    });

    testWidgets('searching inside a feature narrows its items', (tester) async {
      await _open(
        tester,
        pages: [
          KnowledgePage(title: 'Pasta notes', content: ''),
          KnowledgePage(title: 'Server setup', content: ''),
        ],
      );

      await tester.tap(find.widgetWithText(ListTile, 'Knowledge'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'pasta');
      await tester.pumpAndSettle();

      expect(find.text('Pasta notes'), findsOneWidget);
      expect(find.text('Server setup'), findsNothing);
    });

    testWidgets('picking an item returns its route and title', (tester) async {
      final page = KnowledgePage(title: 'Pasta notes', content: '');
      await _open(tester, pages: [page]);

      await tester.tap(find.widgetWithText(ListTile, 'Knowledge'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pasta notes'));
      await tester.pumpAndSettle();

      // The sheet closed with a choice rather than leaving the user to
      // work out '/knowledge/<id>' themselves.
      expect(find.text('Choose a destination'), findsNothing);
    });

    testWidgets('back returns to the feature list', (tester) async {
      await _open(
        tester,
        pages: [KnowledgePage(title: 'Pasta notes', content: '')],
      );

      await tester.tap(find.widgetWithText(ListTile, 'Knowledge'));
      await tester.pumpAndSettle();
      expect(find.text('Open Knowledge'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Choose a destination'), findsOneWidget);
      expect(find.text('Open Knowledge'), findsNothing);
    });

    testWidgets('a feature with nothing in it still offers itself', (
      tester,
    ) async {
      await _open(tester);

      await tester.tap(find.widgetWithText(ListTile, 'Watchlist'));
      await tester.pumpAndSettle();

      expect(find.text('Open Watchlist'), findsOneWidget);
    });
  });
}
