import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/watchlist/models/streaming_platform.dart';
import 'package:personal_app/features/watchlist/models/watch_item.dart';
import 'package:personal_app/features/watchlist/pages/watchlist_page.dart';
import 'package:personal_app/features/watchlist/providers/streaming_platform_providers.dart';
import 'package:personal_app/features/watchlist/providers/watchlist_providers.dart';

class _FakeWatchlistNotifier extends WatchlistNotifier {
  final List<WatchItem> items;
  _FakeWatchlistNotifier(this.items);

  @override
  Stream<List<WatchItem>> build() => Stream.value(items);
}

class _FakePlatformsNotifier extends StreamingPlatformsNotifier {
  final List<StreamingPlatform> platforms;
  _FakePlatformsNotifier(this.platforms);

  @override
  Stream<List<StreamingPlatform>> build() => Stream.value(platforms);
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required List<WatchItem> items,
  required List<StreamingPlatform> platforms,
}) async {
  final container = ProviderContainer(
    overrides: [
      watchlistProvider.overrideWith(() => _FakeWatchlistNotifier(items)),
      streamingPlatformsProvider.overrideWith(
        () => _FakePlatformsNotifier(platforms),
      ),
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

void main() {
  final netflix = StreamingPlatform(name: 'Netflix');
  final videoland = StreamingPlatform(name: 'Videoland');

  group('Watchlist platform links (WISH-0099)', () {
    testWidgets('hides the platform filter bar until one is configured', (
      tester,
    ) async {
      await _pump(
        tester,
        items: [WatchItem(title: 'Heat')],
        platforms: [],
      );

      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('offers a filter chip per configured platform', (tester) async {
      await _pump(
        tester,
        items: [WatchItem(title: 'Heat')],
        platforms: [netflix, videoland],
      );

      expect(find.widgetWithText(FilterChip, 'Netflix'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Videoland'), findsOneWidget);
    });

    testWidgets('filtering by platform narrows the list', (tester) async {
      await _pump(
        tester,
        items: [
          WatchItem(title: 'Heat', platformIds: [netflix.id]),
          WatchItem(title: 'Arrival', platformIds: [videoland.id]),
          WatchItem(title: 'Unlinked'),
        ],
        platforms: [netflix, videoland],
      );

      expect(find.text('Heat'), findsOneWidget);
      expect(find.text('Arrival'), findsOneWidget);
      expect(find.text('Unlinked'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Netflix'));
      await tester.pumpAndSettle();

      expect(find.text('Heat'), findsOneWidget);
      expect(find.text('Arrival'), findsNothing);
      expect(find.text('Unlinked'), findsNothing);
    });

    testWidgets('tapping the selected chip again clears the filter', (
      tester,
    ) async {
      final container = await _pump(
        tester,
        items: [
          WatchItem(title: 'Heat', platformIds: [netflix.id]),
        ],
        platforms: [netflix],
      );

      await tester.tap(find.widgetWithText(FilterChip, 'Netflix'));
      await tester.pumpAndSettle();
      expect(container.read(watchlistPlatformFilterProvider), netflix.id);

      await tester.tap(find.widgetWithText(FilterChip, 'Netflix'));
      await tester.pumpAndSettle();
      expect(container.read(watchlistPlatformFilterProvider), isNull);
    });

    testWidgets('shows a platform icon on entries linked to one', (
      tester,
    ) async {
      await _pump(
        tester,
        items: [
          WatchItem(title: 'Heat', platformIds: [netflix.id]),
        ],
        platforms: [netflix],
      );

      // Lettered fallback avatar, since the fake platform has no icon URL.
      expect(find.widgetWithText(CircleAvatar, 'N'), findsOneWidget);
    });

    testWidgets('ignores links to a platform that has been deleted', (
      tester,
    ) async {
      await _pump(
        tester,
        items: [
          WatchItem(title: 'Heat', platformIds: const ['gone']),
        ],
        platforms: [netflix],
      );

      expect(find.text('Heat'), findsOneWidget);
      expect(find.widgetWithText(CircleAvatar, 'N'), findsNothing);
    });
  });
}
