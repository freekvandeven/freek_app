import 'package:uuid/uuid.dart';

/// Whether a watchlist entry is a single film or a multi-season show.
enum WatchItemType { movie, series }

/// How far through an entry the user is. Always derived from the entry's
/// seasons (or its [WatchItem.watched] flag), never stored — so adding a
/// newly-released season to a finished series automatically drops it back
/// to [partiallyWatched] instead of silently staying "watched"
/// (WISH-0098).
enum WatchStatus { unwatched, partiallyWatched, watched }

/// One season of a series, tracked individually so a show that gained a
/// season still reads as unfinished (WISH-0098).
class Season {
  final int number;
  final String? title;
  final int? episodeCount;

  /// Whole-season watched flag. Authoritative until individual episodes
  /// are ticked, after which [watchedEpisodes] wins — see [status].
  final bool watched;

  final DateTime? watchedAt;

  /// Episode numbers watched within this season (WISH-0104). Empty means
  /// the season is not tracked episode by episode, so [watched] decides;
  /// that is what keeps per-episode tracking optional and lets seasons
  /// recorded before it existed carry on unchanged.
  final List<int> watchedEpisodes;

  const Season({
    required this.number,
    this.title,
    this.episodeCount,
    this.watched = false,
    this.watchedAt,
    this.watchedEpisodes = const [],
  });

  /// Whether this season is tracked episode by episode rather than by its
  /// single [watched] flag.
  bool get tracksEpisodes => watchedEpisodes.isNotEmpty;

  /// How many episodes are watched. Ticks outside the known run are
  /// ignored — a TMDB refresh can shrink a season, and a stale tick
  /// should not read as "11 of 10 watched".
  int get watchedEpisodeCount {
    final count = episodeCount;
    if (!tracksEpisodes) return watched ? (count ?? 0) : 0;
    final ticked = watchedEpisodes.toSet();
    if (count == null) return ticked.length;
    return ticked.where((e) => e >= 1 && e <= count).length;
  }

  /// Whether episode [number] counts as watched. A season ticked off as a
  /// whole reads as all-episodes-watched, so expanding it for the first
  /// time shows what you would expect rather than an empty list.
  bool isEpisodeWatched(int number) =>
      tracksEpisodes ? watchedEpisodes.contains(number) : watched;

  /// Progress through the season, derived the same way [WatchItem.status]
  /// is derived from its seasons: the finer-grained record wins when there
  /// is one, and the flag is the fallback.
  WatchStatus get status {
    final count = episodeCount;
    if (!tracksEpisodes || count == null) {
      return watched ? WatchStatus.watched : WatchStatus.unwatched;
    }
    final done = watchedEpisodeCount;
    if (done == 0) return WatchStatus.unwatched;
    if (done >= count) return WatchStatus.watched;
    return WatchStatus.partiallyWatched;
  }

  bool get isFullyWatched => status == WatchStatus.watched;

  /// Episodes still to watch, or null when the season's length is unknown
  /// and it has not simply been ticked off.
  int? get remainingEpisodes {
    if (isFullyWatched) return 0;
    final count = episodeCount;
    if (count == null) return null;
    return (count - watchedEpisodeCount).clamp(0, count);
  }

  /// Returns a copy with episode [number] marked as [isWatched].
  ///
  /// A season that was ticked off as a whole starts from "every episode
  /// watched", so unticking one leaves the rest ticked instead of wiping
  /// the record. The [watched] flag is kept in step with the episodes so
  /// the two can never disagree.
  Season withEpisodeWatched(int number, bool isWatched) {
    final count = episodeCount;
    final ticked = tracksEpisodes
        ? watchedEpisodes.toSet()
        : (watched && count != null
              ? {for (var e = 1; e <= count; e++) e}
              : <int>{});

    if (isWatched) {
      ticked.add(number);
    } else {
      ticked.remove(number);
    }

    final sorted = ticked.toList()..sort();
    final nowComplete = count != null && sorted.length >= count;
    return copyWith(
      watchedEpisodes: sorted,
      watched: nowComplete,
      watchedAt: nowComplete ? (watchedAt ?? DateTime.now()) : null,
      clearWatchedAt: !nowComplete,
    );
  }

  Season copyWith({
    int? number,
    String? title,
    int? episodeCount,
    bool? watched,
    DateTime? watchedAt,
    List<int>? watchedEpisodes,
    bool clearTitle = false,
    bool clearEpisodeCount = false,
    bool clearWatchedAt = false,
  }) {
    return Season(
      number: number ?? this.number,
      title: clearTitle ? null : (title ?? this.title),
      episodeCount: clearEpisodeCount
          ? null
          : (episodeCount ?? this.episodeCount),
      watched: watched ?? this.watched,
      watchedAt: clearWatchedAt ? null : (watchedAt ?? this.watchedAt),
      watchedEpisodes: watchedEpisodes ?? this.watchedEpisodes,
    );
  }

  Map<String, dynamic> toMap() => {
    'number': number,
    'title': title,
    'episodeCount': episodeCount,
    'watched': watched,
    'watchedAt': watchedAt?.toIso8601String(),
    'watchedEpisodes': watchedEpisodes,
  };

  factory Season.fromMap(Map<String, dynamic> map) {
    return Season(
      number: (map['number'] as num).toInt(),
      title: map['title'] as String?,
      episodeCount: (map['episodeCount'] as num?)?.toInt(),
      watched: map['watched'] as bool? ?? false,
      watchedAt: map['watchedAt'] == null
          ? null
          : DateTime.parse(map['watchedAt'] as String),
      watchedEpisodes:
          (map['watchedEpisodes'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
    );
  }
}

/// A movie or series on the watchlist (WISH-0098).
class WatchItem {
  final String id;
  final WatchItemType type;
  final String title;
  final String? description;

  /// IMDb title id (e.g. `tt0111161`). Stored on its own so the entry can
  /// link out to IMDb and later have its details fetched (WISH-0100).
  final String? imdbId;

  final int? year;

  /// Movie length, or the length of a single episode for a series — see
  /// [totalRuntimeMinutes] for the whole-series figure.
  final int? runtimeMinutes;

  final String? posterUrl;

  /// Free-form link to wherever the entry can be watched or obtained.
  /// Deliberately unvalidated: the user wants to point it at anything,
  /// including the location of a torrent file.
  final String? sourceUrl;

  /// Ids of the streaming platforms this is available on (WISH-0099).
  final List<String> platformIds;

  /// Whole-entry watched flag. Authoritative for movies, and for series
  /// the user ticks off without tracking seasons; once [seasons] is
  /// non-empty the per-season flags win — see [status].
  final bool watched;

  final DateTime? watchedAt;

  /// Optional user rating, 0.0 – 5.0 in 0.5 increments, matching
  /// `Recipe.rating` and `CatalogItem.rating`. `null` means "not rated".
  final double? rating;

  /// Public rating out of 10, shown next to the personal [rating] so the
  /// quality of a title is visible at a glance (WISH-0101). Filled from
  /// TMDB on a lookup, and editable by hand for entries added without one.
  final double? externalRating;

  /// Where [externalRating] came from (e.g. `TMDB`). Null when the user
  /// typed the number in themselves — TMDB's API does not expose IMDb's
  /// rating, so the source is labelled rather than assumed.
  final String? externalRatingSource;

  final String? review;
  final List<Season> seasons;

  /// Manual priority order — lower sorts first, so the top of the list is
  /// "watch this next". Maintained by drag-to-reorder on the list page.
  final int sortOrder;

  final DateTime createdAt;
  final DateTime updatedAt;

  WatchItem({
    String? id,
    this.type = WatchItemType.movie,
    required this.title,
    this.description,
    this.imdbId,
    this.year,
    this.runtimeMinutes,
    this.posterUrl,
    this.sourceUrl,
    this.platformIds = const [],
    this.watched = false,
    this.watchedAt,
    this.rating,
    this.externalRating,
    this.externalRatingSource,
    this.review,
    this.seasons = const [],
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Watch progress, derived rather than stored. A series with seasons is
  /// judged purely on those seasons, so adding an unwatched season to a
  /// finished show reopens it (WISH-0098).
  WatchStatus get status {
    if (seasons.isEmpty) {
      return watched ? WatchStatus.watched : WatchStatus.unwatched;
    }
    // Reads each season's own derived status, so a season that is only
    // part-watched at episode level counts as progress (WISH-0104).
    if (seasons.every((s) => s.status == WatchStatus.watched)) {
      return WatchStatus.watched;
    }
    if (seasons.every((s) => s.status == WatchStatus.unwatched)) {
      return WatchStatus.unwatched;
    }
    return WatchStatus.partiallyWatched;
  }

  bool get isFullyWatched => status == WatchStatus.watched;

  /// Total viewing time, for deciding what fits into an evening: the
  /// runtime itself for a movie, and runtime × total episodes for a
  /// series. Null when there is not enough information to compute it.
  int? get totalRuntimeMinutes {
    if (runtimeMinutes == null) return null;
    if (type == WatchItemType.movie || seasons.isEmpty) return runtimeMinutes;
    if (seasons.any((s) => s.episodeCount == null)) return null;
    final episodes = seasons.fold<int>(0, (sum, s) => sum + s.episodeCount!);
    return runtimeMinutes! * episodes;
  }

  /// Time still to watch, for deciding what to fit into an evening
  /// (WISH-0103): the unwatched seasons only, rather than the whole show.
  /// Zero once everything has been watched, and null on the same terms as
  /// [totalRuntimeMinutes] — an unknown runtime or episode count makes the
  /// sum meaningless rather than zero.
  int? get remainingRuntimeMinutes {
    if (runtimeMinutes == null) return null;
    if (type == WatchItemType.movie || seasons.isEmpty) {
      return watched ? 0 : runtimeMinutes;
    }
    var episodes = 0;
    for (final season in seasons) {
      final remaining = season.remainingEpisodes;
      if (remaining == null) return null;
      episodes += remaining;
    }
    return runtimeMinutes! * episodes;
  }

  String? get imdbUrl =>
      imdbId == null ? null : 'https://www.imdb.com/title/$imdbId/';

  /// Returns a copy with the season numbered [number] marked as [watched],
  /// stamping (or clearing) its watch date. Unknown season numbers are
  /// left alone rather than added (WISH-0098).
  WatchItem withSeasonWatched(int number, bool watched) {
    return copyWith(
      seasons: [
        for (final season in seasons)
          if (season.number == number)
            season.copyWith(
              watched: watched,
              watchedAt: watched ? DateTime.now() : null,
              clearWatchedAt: !watched,
              // Ticking the season as a whole replaces any episode-level
              // record rather than leaving a contradictory one behind.
              watchedEpisodes: const [],
            )
          else
            season,
      ],
    );
  }

  WatchItem copyWith({
    WatchItemType? type,
    String? title,
    String? description,
    String? imdbId,
    int? year,
    int? runtimeMinutes,
    String? posterUrl,
    String? sourceUrl,
    List<String>? platformIds,
    bool? watched,
    DateTime? watchedAt,
    double? rating,
    double? externalRating,
    String? externalRatingSource,
    String? review,
    List<Season>? seasons,
    int? sortOrder,
    bool clearDescription = false,
    bool clearImdbId = false,
    bool clearYear = false,
    bool clearRuntimeMinutes = false,
    bool clearPosterUrl = false,
    bool clearSourceUrl = false,
    bool clearWatchedAt = false,
    bool clearRating = false,
    bool clearExternalRating = false,
    bool clearReview = false,
  }) {
    return WatchItem(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      imdbId: clearImdbId ? null : (imdbId ?? this.imdbId),
      year: clearYear ? null : (year ?? this.year),
      runtimeMinutes: clearRuntimeMinutes
          ? null
          : (runtimeMinutes ?? this.runtimeMinutes),
      posterUrl: clearPosterUrl ? null : (posterUrl ?? this.posterUrl),
      sourceUrl: clearSourceUrl ? null : (sourceUrl ?? this.sourceUrl),
      platformIds: platformIds ?? this.platformIds,
      watched: watched ?? this.watched,
      watchedAt: clearWatchedAt ? null : (watchedAt ?? this.watchedAt),
      rating: clearRating ? null : (rating ?? this.rating),
      externalRating: clearExternalRating
          ? null
          : (externalRating ?? this.externalRating),
      externalRatingSource: clearExternalRating
          ? null
          : (externalRatingSource ?? this.externalRatingSource),
      review: clearReview ? null : (review ?? this.review),
      seasons: seasons ?? this.seasons,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'title': title,
    'description': description,
    'imdbId': imdbId,
    'year': year,
    'runtimeMinutes': runtimeMinutes,
    'posterUrl': posterUrl,
    'sourceUrl': sourceUrl,
    'platformIds': platformIds,
    'watched': watched,
    'watchedAt': watchedAt?.toIso8601String(),
    'rating': rating,
    'externalRating': externalRating,
    'externalRatingSource': externalRatingSource,
    'review': review,
    'seasons': seasons.map((s) => s.toMap()).toList(),
    'sortOrder': sortOrder,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory WatchItem.fromMap(Map<String, dynamic> map) {
    return WatchItem(
      id: map['id'] as String,
      type: WatchItemType.values.byName(map['type'] as String? ?? 'movie'),
      title: map['title'] as String,
      description: map['description'] as String?,
      imdbId: map['imdbId'] as String?,
      year: (map['year'] as num?)?.toInt(),
      runtimeMinutes: (map['runtimeMinutes'] as num?)?.toInt(),
      posterUrl: map['posterUrl'] as String?,
      sourceUrl: map['sourceUrl'] as String?,
      platformIds:
          (map['platformIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      watched: map['watched'] as bool? ?? false,
      watchedAt: map['watchedAt'] == null
          ? null
          : DateTime.parse(map['watchedAt'] as String),
      rating: (map['rating'] as num?)?.toDouble(),
      externalRating: (map['externalRating'] as num?)?.toDouble(),
      externalRatingSource: map['externalRatingSource'] as String?,
      review: map['review'] as String?,
      seasons:
          (map['seasons'] as List<dynamic>?)
              ?.map((e) => Season.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
