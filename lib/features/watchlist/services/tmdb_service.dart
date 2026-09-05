import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../services/log_service.dart';
import '../models/watch_item.dart';

/// Raised when TMDB rejects the configured API key, so the UI can point
/// the user at Settings instead of showing a bare HTTP error.
class TmdbAuthException implements Exception {
  final String message;
  const TmdbAuthException(this.message);

  @override
  String toString() => message;
}

/// Poster/backdrop base. w500 is the smallest size that still looks right
/// on a detail page; the app's `memCacheWidth` caps decode size from there.
const _imageBase = 'https://image.tmdb.org/t/p/w500';

String? _posterUrl(String? path) =>
    path == null || path.isEmpty ? null : '$_imageBase$path';

int? _yearOf(String? date) {
  if (date == null || date.length < 4) return null;
  return int.tryParse(date.substring(0, 4));
}

/// TMDB reports 0 for a title nobody has voted on, which would read as
/// "rated zero" rather than "unrated" (WISH-0101).
double? _voteAverage(Object? value) {
  final rating = (value as num?)?.toDouble();
  return rating == null || rating <= 0 ? null : rating;
}

/// Source label stored alongside a fetched rating. TMDB's API does not
/// expose IMDb's rating — `vote_average` is TMDB's own score — so the
/// number is labelled with where it actually came from.
const tmdbRatingSource = 'TMDB';

/// One hit from a title search, enough to show a pick-list row.
class TmdbSearchResult {
  final int tmdbId;
  final WatchItemType type;
  final String title;
  final int? year;
  final String? posterUrl;

  const TmdbSearchResult({
    required this.tmdbId,
    required this.type,
    required this.title,
    this.year,
    this.posterUrl,
  });

  /// Returns null for anything that is not a movie or show — `search/multi`
  /// also returns people, which have no place on a watchlist.
  static TmdbSearchResult? fromJson(Map<String, dynamic> json) {
    final mediaType = json['media_type'] as String?;
    final isMovie = mediaType == 'movie';
    final isTv = mediaType == 'tv';
    if (!isMovie && !isTv) return null;

    final title = (isMovie ? json['title'] : json['name']) as String?;
    if (title == null || title.isEmpty) return null;

    return TmdbSearchResult(
      tmdbId: (json['id'] as num).toInt(),
      type: isMovie ? WatchItemType.movie : WatchItemType.series,
      title: title,
      year: _yearOf(
        (isMovie ? json['release_date'] : json['first_air_date']) as String?,
      ),
      posterUrl: _posterUrl(json['poster_path'] as String?),
    );
  }
}

/// Everything fetched about one title, shaped for applying onto a
/// [WatchItem]. Seasons carry metadata only — merging them with the
/// user's watched state is the caller's job (see `mergeSeasons`).
class TmdbDetails {
  final WatchItemType type;
  final String title;
  final String? description;
  final int? year;
  final int? runtimeMinutes;
  final String? posterUrl;
  final String? imdbId;

  /// TMDB's own average vote out of 10, or null when nobody has voted.
  final double? externalRating;

  final List<Season> seasons;

  const TmdbDetails({
    required this.type,
    required this.title,
    this.description,
    this.year,
    this.runtimeMinutes,
    this.posterUrl,
    this.imdbId,
    this.externalRating,
    this.seasons = const [],
  });

  factory TmdbDetails.fromMovieJson(Map<String, dynamic> json) {
    return TmdbDetails(
      type: WatchItemType.movie,
      title: json['title'] as String? ?? '',
      description: (json['overview'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['overview'] as String).trim(),
      year: _yearOf(json['release_date'] as String?),
      runtimeMinutes: (json['runtime'] as num?)?.toInt(),
      posterUrl: _posterUrl(json['poster_path'] as String?),
      imdbId: json['imdb_id'] as String?,
      externalRating: _voteAverage(json['vote_average']),
    );
  }

  factory TmdbDetails.fromTvJson(Map<String, dynamic> json, {String? imdbId}) {
    // episode_run_time is a list of typical lengths; the first is the
    // usual one, and plenty of shows report none at all.
    final runTimes = (json['episode_run_time'] as List<dynamic>?) ?? const [];
    final seasons = <Season>[];
    for (final raw in (json['seasons'] as List<dynamic>?) ?? const []) {
      final season = raw as Map<String, dynamic>;
      final number = (season['season_number'] as num?)?.toInt();
      // Season 0 is TMDB's "Specials" bucket — not part of the run.
      if (number == null || number == 0) continue;
      seasons.add(
        Season(
          number: number,
          title: season['name'] as String?,
          episodeCount: (season['episode_count'] as num?)?.toInt(),
        ),
      );
    }
    seasons.sort((a, b) => a.number.compareTo(b.number));

    return TmdbDetails(
      type: WatchItemType.series,
      title: json['name'] as String? ?? '',
      description: (json['overview'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['overview'] as String).trim(),
      year: _yearOf(json['first_air_date'] as String?),
      runtimeMinutes: runTimes.isEmpty ? null : (runTimes.first as num).toInt(),
      posterUrl: _posterUrl(json['poster_path'] as String?),
      imdbId: imdbId,
      externalRating: _voteAverage(json['vote_average']),
      seasons: seasons,
    );
  }
}

/// Reads movie and series metadata from TMDB (WISH-0100).
///
/// IMDb has no free public API, so TMDB stands in: it can look a title up
/// *by its IMDb id* (`find/{id}?external_source=imdb_id`), which keeps the
/// IMDb code the user pastes as the thing the app stores and links to.
class TmdbService {
  static const _base = 'https://api.themoviedb.org/3';

  final String apiKey;
  final http.Client _client;

  TmdbService(this.apiKey, {http.Client? client})
    : _client = client ?? http.Client();

  bool get isConfigured => apiKey.isNotEmpty;

  Uri _uri(String path, [Map<String, String> params = const {}]) => Uri.parse(
    '$_base$path',
  ).replace(queryParameters: {'api_key': apiKey, ...params});

  Future<Map<String, dynamic>?> _get(Uri uri, String op) async {
    final response = await _client.get(uri);
    if (response.statusCode == 401) {
      throw const TmdbAuthException(
        'TMDB rejected the API key. Check it in Settings → Watchlist.',
      );
    }
    if (response.statusCode != 200) {
      LogService.instance.warning(
        'TMDB $op failed (${response.statusCode}): ${response.body}',
      );
      return null;
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Looks up a title by its IMDb code (`tt...`). Returns null when TMDB
  /// knows nothing about it.
  Future<TmdbDetails?> fetchByImdbId(String imdbId) async {
    final trimmed = imdbId.trim();
    if (trimmed.isEmpty) return null;

    final found = await _get(
      _uri('/find/$trimmed', {'external_source': 'imdb_id'}),
      'find',
    );
    if (found == null) return null;

    final movies = (found['movie_results'] as List<dynamic>?) ?? const [];
    if (movies.isNotEmpty) {
      final id = ((movies.first as Map<String, dynamic>)['id'] as num).toInt();
      return fetchDetails(id, WatchItemType.movie);
    }
    final shows = (found['tv_results'] as List<dynamic>?) ?? const [];
    if (shows.isNotEmpty) {
      final id = ((shows.first as Map<String, dynamic>)['id'] as num).toInt();
      return fetchDetails(id, WatchItemType.series);
    }
    return null;
  }

  /// Full details for a TMDB id. Movies carry their IMDb id directly;
  /// shows need a second call to `external_ids` for it.
  Future<TmdbDetails?> fetchDetails(int tmdbId, WatchItemType type) async {
    if (type == WatchItemType.movie) {
      final json = await _get(_uri('/movie/$tmdbId'), 'movie details');
      return json == null ? null : TmdbDetails.fromMovieJson(json);
    }

    final json = await _get(_uri('/tv/$tmdbId'), 'tv details');
    if (json == null) return null;
    final externalIds = await _get(
      _uri('/tv/$tmdbId/external_ids'),
      'tv external ids',
    );
    return TmdbDetails.fromTvJson(
      json,
      imdbId: externalIds?['imdb_id'] as String?,
    );
  }

  /// Title search for the type-ahead. Returns an empty list for a blank
  /// query rather than asking TMDB for everything.
  Future<List<TmdbSearchResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final json = await _get(
      _uri('/search/multi', {'query': trimmed, 'include_adult': 'false'}),
      'search',
    );
    if (json == null) return const [];

    return ((json['results'] as List<dynamic>?) ?? const [])
        .map((e) => TmdbSearchResult.fromJson(e as Map<String, dynamic>))
        .nonNulls
        .toList();
  }
}
