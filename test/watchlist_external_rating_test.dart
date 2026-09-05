import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/watchlist/models/watch_item.dart';
import 'package:personal_app/features/watchlist/pages/watchlist_page.dart';
import 'package:personal_app/features/watchlist/providers/watchlist_providers.dart';
import 'package:personal_app/features/watchlist/services/tmdb_service.dart';
import 'package:personal_app/features/watchlist/utils/external_rating.dart';
import 'package:personal_app/features/watchlist/widgets/external_rating_badge.dart';

class _FakeWatchlistNotifier extends WatchlistNotifier {
  final List<WatchItem> items;
  _FakeWatchlistNotifier(this.items);

  @override
  Stream<List<WatchItem>> build() => Stream.value(items);
}

void main() {
  group('WatchItem external rating (WISH-0101)', () {
    test('round-trips the rating and its source', () {
      final item = WatchItem(
        title: 'Heat',
        rating: 4.5,
        externalRating: 7.8,
        externalRatingSource: 'TMDB',
      );

      final restored = WatchItem.fromMap(item.toMap());

      expect(restored.rating, 4.5);
      expect(restored.externalRating, 7.8);
      expect(restored.externalRatingSource, 'TMDB');
    });

    test('defaults to no public rating', () {
      final item = WatchItem(title: 'Heat');

      expect(item.externalRating, isNull);
      expect(item.externalRatingSource, isNull);
    });

    test('an entry written before the field existed still loads', () {
      final restored = WatchItem.fromMap({
        'id': 'legacy',
        'title': 'Heat',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(restored.externalRating, isNull);
      expect(restored.externalRatingSource, isNull);
    });

    test('the two ratings are independent', () {
      final item = WatchItem(
        title: 'Heat',
        rating: 5.0,
        externalRating: 6.1,
        externalRatingSource: 'TMDB',
      );

      final rerated = item.copyWith(rating: 2.0);
      expect(rerated.externalRating, 6.1);

      final cleared = item.copyWith(clearExternalRating: true);
      expect(cleared.rating, 5.0);
      expect(cleared.externalRating, isNull);
      // Clearing the number clears the claim about where it came from.
      expect(cleared.externalRatingSource, isNull);
    });
  });

  group('validateExternalRating (WISH-0101)', () {
    test('accepts an empty value and anything on the 0-10 scale', () {
      expect(validateExternalRating(null), isNull);
      expect(validateExternalRating(''), isNull);
      expect(validateExternalRating('0'), isNull);
      expect(validateExternalRating('7.8'), isNull);
      expect(validateExternalRating('7,8'), isNull);
      expect(validateExternalRating('10'), isNull);
    });

    test('rejects nonsense and out-of-scale numbers', () {
      expect(validateExternalRating('abc'), 'Invalid number');
      expect(validateExternalRating('78'), 'Must be between 0 and 10');
      expect(validateExternalRating('-1'), 'Must be between 0 and 10');
    });
  });

  group('TMDB vote_average mapping (WISH-0101)', () {
    test('carries the vote average through as the public rating', () {
      final movie = TmdbDetails.fromMovieJson({
        'title': 'Heat',
        'vote_average': 7.9,
      });
      expect(movie.externalRating, 7.9);

      final show = TmdbDetails.fromTvJson({
        'name': 'Severance',
        'vote_average': 8.4,
      });
      expect(show.externalRating, 8.4);
    });

    test('treats TMDB\'s zero for an unvoted title as no rating', () {
      final movie = TmdbDetails.fromMovieJson({
        'title': 'Obscure',
        'vote_average': 0,
      });

      expect(movie.externalRating, isNull);
    });

    test('handles a response with no vote_average at all', () {
      expect(
        TmdbDetails.fromMovieJson({'title': 'Heat'}).externalRating,
        isNull,
      );
    });
  });

  group('Sorting by public rating (WISH-0101)', () {
    test('sorts best first, independently of the personal rating', () {
      final items = [
        WatchItem(title: 'Loved by me', rating: 5.0, externalRating: 5.5),
        WatchItem(title: 'Acclaimed', rating: 1.0, externalRating: 9.1),
      ];

      final byPublic = List.of(items)
        ..sort((a, b) => compareWatchItems(a, b, WatchSort.externalRating));
      expect(byPublic.map((i) => i.title), ['Acclaimed', 'Loved by me']);

      final byMine = List.of(items)
        ..sort((a, b) => compareWatchItems(a, b, WatchSort.rating));
      expect(byMine.map((i) => i.title), ['Loved by me', 'Acclaimed']);
    });

    test('unrated entries sink to the bottom', () {
      final items = [
        WatchItem(title: 'Unrated'),
        WatchItem(title: 'Rated', externalRating: 6.0),
      ];

      final sorted = List.of(items)
        ..sort((a, b) => compareWatchItems(a, b, WatchSort.externalRating));
      expect(sorted.map((i) => i.title), ['Rated', 'Unrated']);
    });
  });

  group('ExternalRatingBadge (WISH-0101)', () {
    Future<void> pumpBadge(
      WidgetTester tester,
      double? rating, {
      String? source,
    }) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExternalRatingBadge(rating: rating, source: source),
        ),
      ),
    );

    testWidgets('renders nothing without a rating', (tester) async {
      await pumpBadge(tester, null);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('shows the score out of ten, trimming a trailing .0', (
      tester,
    ) async {
      await pumpBadge(tester, 8.0);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('/10'), findsOneWidget);

      await pumpBadge(tester, 7.8);
      expect(find.text('7.8'), findsOneWidget);
    });

    testWidgets('names the source in the tooltip rather than assuming IMDb', (
      tester,
    ) async {
      await pumpBadge(tester, 7.8, source: 'TMDB');
      expect(
        tester.widget<Tooltip>(find.byType(Tooltip)).message,
        'TMDB rating: 7.8/10',
      );

      await pumpBadge(tester, 7.8);
      expect(
        tester.widget<Tooltip>(find.byType(Tooltip)).message,
        'Public rating: 7.8/10',
      );
    });
  });

  group('WatchlistPage public rating (WISH-0101)', () {
    testWidgets('shows the public rating in the list overview', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchlistProvider.overrideWith(
              () => _FakeWatchlistNotifier([
                WatchItem(
                  title: 'Heat',
                  rating: 4.0,
                  externalRating: 7.8,
                  externalRatingSource: 'TMDB',
                ),
              ]),
            ),
          ],
          child: const MaterialApp(home: WatchlistPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Both ratings are visible at once: stars for mine, score for public.
      expect(find.text('7.8'), findsOneWidget);
      expect(find.byType(ExternalRatingBadge), findsOneWidget);
    });
  });
}
