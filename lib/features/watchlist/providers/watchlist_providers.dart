import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../services/log_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/watch_item.dart';
import '../services/firestore_watchlist_service.dart';
import '../services/watchlist_service.dart';
import '../utils/watchlist_order.dart';

final watchlistServiceProvider = Provider<WatchlistService>((ref) {
  if (AppConfig.useFirebase) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return FirestoreWatchlistService(userId);
  }
  final service = MockWatchlistService();
  ref.onDispose(service.dispose);
  return service;
});

class WatchlistNotifier extends StreamNotifier<List<WatchItem>> {
  @override
  Stream<List<WatchItem>> build() {
    return ref.watch(watchlistServiceProvider).watchItems();
  }

  /// Adds [item] at the bottom of the priority order, so a new entry
  /// never jumps ahead of things already queued up.
  Future<void> addItem(WatchItem item) async {
    final current = state.valueOrNull ?? const <WatchItem>[];
    final nextOrder = current.isEmpty
        ? 0
        : current.map((i) => i.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    await ref
        .read(watchlistServiceProvider)
        .addItem(item.copyWith(sortOrder: nextOrder));
    LogService.instance.info('Watchlist item added: ${item.title}');
  }

  Future<void> updateItem(WatchItem item) async {
    await ref.read(watchlistServiceProvider).updateItem(item);
    LogService.instance.info('Watchlist item updated: ${item.id}');
  }

  Future<void> deleteItem(String id) async {
    await ref.read(watchlistServiceProvider).deleteItem(id);
    LogService.instance.info('Watchlist item deleted: $id');
  }

  /// Moves the entry at [oldIndex] to [newIndex] in the priority order and
  /// persists the renumbering. Only entries whose position actually changed
  /// are written (WISH-0098).
  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final changed = reorderWatchItems(current, oldIndex, newIndex);
    final service = ref.read(watchlistServiceProvider);
    for (final item in changed) {
      await service.updateItem(item);
    }
  }

  /// Marks one season of a series watched or unwatched. The entry's own
  /// status follows from its seasons, so this is all that is needed to
  /// move a show between unwatched, partially watched and watched.
  Future<void> setSeasonWatched(
    WatchItem item,
    int seasonNumber,
    bool watched,
  ) async {
    await updateItem(item.withSeasonWatched(seasonNumber, watched));
  }

  /// Ticks an entry off (or back on) from the list, stamping [watchedAt]
  /// so "when did I see this" survives the toggle.
  Future<void> toggleWatched(WatchItem item) async {
    final nowWatched = !item.watched;
    await updateItem(
      nowWatched
          ? item.copyWith(watched: true, watchedAt: DateTime.now())
          : item.copyWith(watched: false, clearWatchedAt: true),
    );
  }
}

final watchlistProvider =
    StreamNotifierProvider<WatchlistNotifier, List<WatchItem>>(
      WatchlistNotifier.new,
    );

final watchlistSearchProvider = StateProvider<String>((_) => '');

/// Id of the streaming platform to narrow the list to, or null for all
/// (WISH-0099).
final watchlistPlatformFilterProvider = StateProvider<String?>((_) => null);

/// Watch-progress filter. [WatchStatusFilter.all] is the default so the
/// list stays a complete queue until the user narrows it (WISH-0098).
enum WatchStatusFilter { all, unwatched, inProgress, watched }

enum WatchSort { priority, title, year, rating, externalRating, runtime }

final watchlistStatusFilterProvider = StateProvider<WatchStatusFilter>(
  (_) => WatchStatusFilter.all,
);

final watchlistSortProvider = StateProvider<WatchSort>(
  (_) => WatchSort.priority,
);

bool _matchesStatus(WatchItem item, WatchStatusFilter filter) =>
    switch (filter) {
      WatchStatusFilter.all => true,
      WatchStatusFilter.unwatched => item.status == WatchStatus.unwatched,
      WatchStatusFilter.inProgress =>
        item.status == WatchStatus.partiallyWatched,
      WatchStatusFilter.watched => item.status == WatchStatus.watched,
    };

/// Comparator for [sort]. Entries missing the sorted-on value sink to the
/// bottom rather than sorting as zero, the same way the task list handles
/// missing due dates.
int compareWatchItems(WatchItem a, WatchItem b, WatchSort sort) {
  int nullsLast(num? x, num? y, int Function(num, num) compare) {
    if (x == null && y == null) return a.title.compareTo(b.title);
    if (x == null) return 1;
    if (y == null) return -1;
    final result = compare(x, y);
    return result != 0 ? result : a.title.compareTo(b.title);
  }

  return switch (sort) {
    WatchSort.priority => compareByPriority(a, b),
    WatchSort.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    // Newest first — a 2026 release is the interesting one.
    WatchSort.year => nullsLast(a.year, b.year, (x, y) => y.compareTo(x)),
    // Best first, for both the personal and the public rating.
    WatchSort.rating => nullsLast(a.rating, b.rating, (x, y) => y.compareTo(x)),
    WatchSort.externalRating => nullsLast(
      a.externalRating,
      b.externalRating,
      (x, y) => y.compareTo(x),
    ),
    // Shortest first, for "what fits before bed".
    WatchSort.runtime => nullsLast(
      a.totalRuntimeMinutes,
      b.totalRuntimeMinutes,
      (x, y) => x.compareTo(y),
    ),
  };
}

final filteredWatchlistProvider = Provider<AsyncValue<List<WatchItem>>>((ref) {
  final items = ref.watch(watchlistProvider);
  final search = ref.watch(watchlistSearchProvider).toLowerCase();
  final platformId = ref.watch(watchlistPlatformFilterProvider);
  final statusFilter = ref.watch(watchlistStatusFilterProvider);
  final sort = ref.watch(watchlistSortProvider);

  return items.whenData((list) {
    var filtered = list;
    if (search.isNotEmpty) {
      filtered = filtered
          .where(
            (i) =>
                i.title.toLowerCase().contains(search) ||
                (i.description?.toLowerCase().contains(search) ?? false),
          )
          .toList();
    }
    if (platformId != null) {
      filtered = filtered
          .where((i) => i.platformIds.contains(platformId))
          .toList();
    }
    if (statusFilter != WatchStatusFilter.all) {
      filtered = filtered
          .where((i) => _matchesStatus(i, statusFilter))
          .toList();
    }
    return List.of(filtered)..sort((a, b) => compareWatchItems(a, b, sort));
  });
});
