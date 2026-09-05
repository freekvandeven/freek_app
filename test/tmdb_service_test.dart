import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/watchlist/models/watch_item.dart';
import 'package:personal_app/features/watchlist/services/tmdb_service.dart';
import 'package:personal_app/features/watchlist/utils/season_merge.dart';

void main() {
  group('TmdbDetails.fromMovieJson (WISH-0100)', () {
    test('maps the fields the watchlist stores', () {
      final details = TmdbDetails.fromMovieJson({
        'title': 'Heat',
        'overview': 'A crew of thieves and the detective chasing them.',
        'release_date': '1995-12-15',
        'runtime': 170,
        'poster_path': '/poster.jpg',
        'imdb_id': 'tt0113277',
      });

      expect(details.type, WatchItemType.movie);
      expect(details.title, 'Heat');
      expect(details.description, startsWith('A crew of thieves'));
      expect(details.year, 1995);
      expect(details.runtimeMinutes, 170);
      expect(details.posterUrl, 'https://image.tmdb.org/t/p/w500/poster.jpg');
      expect(details.imdbId, 'tt0113277');
      expect(details.seasons, isEmpty);
    });

    test('tolerates missing optional fields', () {
      final details = TmdbDetails.fromMovieJson({'title': 'Untitled'});

      expect(details.title, 'Untitled');
      expect(details.description, isNull);
      expect(details.year, isNull);
      expect(details.runtimeMinutes, isNull);
      expect(details.posterUrl, isNull);
    });

    test('treats a blank overview as no description', () {
      final details = TmdbDetails.fromMovieJson({
        'title': 'Heat',
        'overview': '   ',
      });

      expect(details.description, isNull);
    });
  });

  group('TmdbDetails.fromTvJson (WISH-0100)', () {
    Map<String, dynamic> showJson() => {
      'name': 'Severance',
      'overview': 'Work-life balance, surgically enforced.',
      'first_air_date': '2022-02-18',
      'episode_run_time': [50],
      'poster_path': '/severance.jpg',
      'seasons': [
        {'season_number': 0, 'name': 'Specials', 'episode_count': 3},
        {'season_number': 2, 'name': 'Season 2', 'episode_count': 10},
        {'season_number': 1, 'name': 'Season 1', 'episode_count': 9},
      ],
    };

    test('maps a show and its seasons', () {
      final details = TmdbDetails.fromTvJson(showJson(), imdbId: 'tt11280740');

      expect(details.type, WatchItemType.series);
      expect(details.title, 'Severance');
      expect(details.year, 2022);
      expect(details.runtimeMinutes, 50);
      expect(details.imdbId, 'tt11280740');
      expect(details.seasons.map((s) => s.number), [1, 2]);
      expect(details.seasons.first.episodeCount, 9);
    });

    test('drops the specials bucket (season 0)', () {
      final details = TmdbDetails.fromTvJson(showJson());

      expect(details.seasons.any((s) => s.number == 0), isFalse);
    });

    test('fetched seasons start unwatched', () {
      final details = TmdbDetails.fromTvJson(showJson());

      expect(details.seasons.every((s) => !s.watched), isTrue);
    });

    test('handles a show that reports no episode runtime', () {
      final details = TmdbDetails.fromTvJson({
        'name': 'Unknown Show',
        'episode_run_time': <dynamic>[],
        'seasons': <dynamic>[],
      });

      expect(details.runtimeMinutes, isNull);
      expect(details.seasons, isEmpty);
    });
  });

  group('TmdbSearchResult.fromJson (WISH-0100)', () {
    test('maps a movie hit', () {
      final result = TmdbSearchResult.fromJson({
        'media_type': 'movie',
        'id': 949,
        'title': 'Heat',
        'release_date': '1995-12-15',
        'poster_path': '/poster.jpg',
      });

      expect(result, isNotNull);
      expect(result!.type, WatchItemType.movie);
      expect(result.tmdbId, 949);
      expect(result.title, 'Heat');
      expect(result.year, 1995);
      expect(result.posterUrl, 'https://image.tmdb.org/t/p/w500/poster.jpg');
    });

    test('maps a tv hit from its name field', () {
      final result = TmdbSearchResult.fromJson({
        'media_type': 'tv',
        'id': 95396,
        'name': 'Severance',
        'first_air_date': '2022-02-18',
      });

      expect(result!.type, WatchItemType.series);
      expect(result.title, 'Severance');
      expect(result.year, 2022);
    });

    test('skips people, who have no place on a watchlist', () {
      final result = TmdbSearchResult.fromJson({
        'media_type': 'person',
        'id': 1158,
        'name': 'Al Pacino',
      });

      expect(result, isNull);
    });

    test('skips a hit with no usable title', () {
      expect(
        TmdbSearchResult.fromJson({'media_type': 'movie', 'id': 1}),
        isNull,
      );
    });
  });

  group('mergeSeasons (WISH-0100)', () {
    test('keeps watched state when refreshing existing seasons', () {
      final existing = [
        Season(number: 1, watched: true, watchedAt: DateTime(2026, 1, 1)),
        const Season(number: 2, watched: true),
      ];
      const fetched = [
        Season(number: 1, title: 'Season 1', episodeCount: 9),
        Season(number: 2, title: 'Season 2', episodeCount: 10),
      ];

      final merged = mergeSeasons(existing, fetched);

      expect(merged, hasLength(2));
      expect(merged.every((s) => s.watched), isTrue);
      expect(merged[0].watchedAt, DateTime(2026, 1, 1));
      // Metadata still refreshed from TMDB.
      expect(merged[0].episodeCount, 9);
      expect(merged[1].title, 'Season 2');
    });

    test('a newly released season arrives unwatched and reopens the show', () {
      final show = WatchItem(
        type: WatchItemType.series,
        title: 'Severance',
        seasons: const [
          Season(number: 1, watched: true),
          Season(number: 2, watched: true),
        ],
      );
      expect(show.status, WatchStatus.watched);

      final merged = mergeSeasons(show.seasons, const [
        Season(number: 1, episodeCount: 9),
        Season(number: 2, episodeCount: 10),
        Season(number: 3, episodeCount: 10),
      ]);

      final refreshed = show.copyWith(seasons: merged);
      expect(refreshed.seasons, hasLength(3));
      expect(refreshed.seasons[2].watched, isFalse);
      expect(refreshed.status, WatchStatus.partiallyWatched);
    });

    test('keeps hand-added seasons TMDB does not know about', () {
      const existing = [
        Season(number: 1, watched: true),
        Season(number: 9, title: 'Fan edit', watched: true),
      ];

      final merged = mergeSeasons(existing, const [Season(number: 1)]);

      expect(merged.map((s) => s.number), [1, 9]);
      expect(merged.last.title, 'Fan edit');
      expect(merged.last.watched, isTrue);
    });

    test('populates an empty entry straight from the fetched seasons', () {
      final merged = mergeSeasons(const [], const [
        Season(number: 2, episodeCount: 10),
        Season(number: 1, episodeCount: 9),
      ]);

      expect(merged.map((s) => s.number), [1, 2]);
      expect(merged.every((s) => !s.watched), isTrue);
    });
  });
}
