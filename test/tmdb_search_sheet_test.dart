import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/watchlist/models/watch_item.dart';
import 'package:personal_app/features/watchlist/providers/tmdb_providers.dart';
import 'package:personal_app/features/watchlist/services/tmdb_service.dart';
import 'package:personal_app/features/watchlist/widgets/tmdb_search_sheet.dart';

class _FakeTmdbService implements TmdbService {
  final List<TmdbSearchResult> results;
  final Object? throws;
  final queries = <String>[];

  _FakeTmdbService({this.results = const [], this.throws});

  @override
  Future<List<TmdbSearchResult>> search(String query) async {
    queries.add(query);
    if (throws != null) throw throws!;
    return results;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<TmdbSearchResult?> _openSheet(
  WidgetTester tester,
  _FakeTmdbService service,
) async {
  TmdbSearchResult? picked;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tmdbServiceProvider.overrideWithValue(service),
        tmdbApiKeyProvider.overrideWith((ref) async => 'test-key'),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await showTmdbSearchSheet(context);
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

/// Types [query] and waits out the 400ms debounce. The bare pump first
/// lets the rebuild register the debounce timer — advancing the clock
/// before that would skip straight past it.
Future<void> _type(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField).last, query);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  const heat = TmdbSearchResult(
    tmdbId: 949,
    type: WatchItemType.movie,
    title: 'Heat',
    year: 1995,
  );
  const severance = TmdbSearchResult(
    tmdbId: 95396,
    type: WatchItemType.series,
    title: 'Severance',
    year: 2022,
  );

  group('TmdbSearchSheet (WISH-0100)', () {
    testWidgets('prompts before anything is typed, without searching', (
      tester,
    ) async {
      final service = _FakeTmdbService();
      await _openSheet(tester, service);

      expect(find.text('Search movies and series by title'), findsOneWidget);
      expect(service.queries, isEmpty);
    });

    testWidgets('shows matches once typing settles', (tester) async {
      final service = _FakeTmdbService(results: const [heat, severance]);
      await _openSheet(tester, service);

      await _type(tester, 'hea');

      expect(service.queries, ['hea']);
      expect(find.text('Heat'), findsOneWidget);
      expect(find.text('Movie • 1995'), findsOneWidget);
      expect(find.text('Series • 2022'), findsOneWidget);
    });

    testWidgets('debounces so keystrokes do not each fire a request', (
      tester,
    ) async {
      final service = _FakeTmdbService(results: const [heat]);
      await _openSheet(tester, service);

      for (final partial in ['h', 'he']) {
        await tester.enterText(find.byType(TextField).last, partial);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _type(tester, 'hea');

      expect(service.queries, ['hea']);
    });

    testWidgets('reports when nothing matches', (tester) async {
      final service = _FakeTmdbService();
      await _openSheet(tester, service);

      await _type(tester, 'zzzz');

      expect(find.text('No matches'), findsOneWidget);
    });

    testWidgets('surfaces a rejected API key in plain language', (
      tester,
    ) async {
      final service = _FakeTmdbService(
        throws: const TmdbAuthException(
          'TMDB rejected the API key. Check it in Settings → Watchlist.',
        ),
      );
      await _openSheet(tester, service);

      await _type(tester, 'heat');

      expect(find.textContaining('TMDB rejected the API key'), findsOneWidget);
    });

    testWidgets('picking a result closes the sheet with it', (tester) async {
      final service = _FakeTmdbService(results: const [heat]);
      await _openSheet(tester, service);

      await _type(tester, 'heat');
      await tester.tap(find.text('Heat'));
      await tester.pumpAndSettle();

      expect(find.text('Search TMDB'), findsNothing);
    });
  });
}
