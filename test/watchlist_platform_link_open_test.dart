import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/watchlist/models/streaming_platform.dart';
import 'package:personal_app/features/watchlist/models/watch_item.dart';
import 'package:personal_app/features/watchlist/pages/watch_item_detail_page.dart';
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

Future<void> _pumpDetail(
  WidgetTester tester, {
  required WatchItem item,
  required List<StreamingPlatform> platforms,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        watchlistProvider.overrideWith(() => _FakeWatchlistNotifier([item])),
        streamingPlatformsProvider.overrideWith(
          () => _FakePlatformsNotifier(platforms),
        ),
      ],
      child: MaterialApp(home: WatchItemDetailPage(itemId: item.id)),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _tooltip(String message) =>
    find.byWidgetPredicate((w) => w is Tooltip && w.message == message);

void main() {
  group('StreamingPlatform app link (WISH-0105)', () {
    test('round-trips the app link', () {
      final platform = StreamingPlatform(
        name: 'Netflix',
        url: 'https://netflix.com',
        appUrl: 'nflx://',
      );

      final restored = StreamingPlatform.fromMap(platform.toMap());
      expect(restored.appUrl, 'nflx://');
      expect(restored.url, 'https://netflix.com');
    });

    test('a platform saved before app links loads without one', () {
      final restored = StreamingPlatform.fromMap({
        'id': 'p1',
        'name': 'Videoland',
        'url': 'https://videoland.com',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(restored.appUrl, isNull);
      expect(restored.hasLink, isTrue);
    });

    test('copyWith can clear the app link independently of the url', () {
      final platform = StreamingPlatform(
        name: 'Netflix',
        url: 'https://netflix.com',
        appUrl: 'nflx://',
      );

      final cleared = platform.copyWith(clearAppUrl: true);
      expect(cleared.appUrl, isNull);
      expect(cleared.url, 'https://netflix.com');
    });

    group('hasLink', () {
      test('is false with neither link', () {
        expect(StreamingPlatform(name: 'Netflix').hasLink, isFalse);
      });

      test('is true with either link', () {
        expect(
          StreamingPlatform(name: 'A', url: 'https://a.com').hasLink,
          isTrue,
        );
        expect(StreamingPlatform(name: 'B', appUrl: 'b://').hasLink, isTrue);
      });

      test('ignores blank strings', () {
        expect(
          StreamingPlatform(name: 'A', url: '   ', appUrl: '').hasLink,
          isFalse,
        );
      });
    });
  });

  group('Opening a platform from an entry (WISH-0105)', () {
    final netflix = StreamingPlatform(
      name: 'Netflix',
      url: 'https://netflix.com',
      appUrl: 'nflx://',
    );
    final linkless = StreamingPlatform(name: 'Homemade');

    testWidgets('a linked platform is tappable and says so', (tester) async {
      await _pumpDetail(
        tester,
        item: WatchItem(title: 'Heat', platformIds: [netflix.id]),
        platforms: [netflix],
      );

      expect(_tooltip('Open Netflix'), findsOneWidget);
      expect(
        find.descendant(
          of: _tooltip('Open Netflix'),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a platform with no links is not tappable', (tester) async {
      await _pumpDetail(
        tester,
        item: WatchItem(title: 'Heat', platformIds: [linkless.id]),
        platforms: [linkless],
      );

      // Plain name, not "Open …", and nothing to tap.
      expect(_tooltip('Homemade'), findsOneWidget);
      expect(_tooltip('Open Homemade'), findsNothing);
      expect(
        find.descendant(
          of: _tooltip('Homemade'),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });

    testWidgets('the list page keeps its icons non-interactive', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchlistProvider.overrideWith(
              () => _FakeWatchlistNotifier([
                WatchItem(title: 'Heat', platformIds: [netflix.id]),
              ]),
            ),
            streamingPlatformsProvider.overrideWith(
              () => _FakePlatformsNotifier([netflix]),
            ),
          ],
          child: const MaterialApp(home: WatchlistPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Tapping a row on the list opens the entry, so the icons there stay
      // decorative rather than competing for the tap.
      expect(_tooltip('Netflix'), findsOneWidget);
      expect(_tooltip('Open Netflix'), findsNothing);
    });
  });
}
