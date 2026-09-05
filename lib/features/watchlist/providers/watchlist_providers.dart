import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../services/log_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/watch_item.dart';
import '../services/firestore_watchlist_service.dart';
import '../services/watchlist_service.dart';

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

final filteredWatchlistProvider = Provider<AsyncValue<List<WatchItem>>>((ref) {
  final items = ref.watch(watchlistProvider);
  final search = ref.watch(watchlistSearchProvider).toLowerCase();

  return items.whenData((list) {
    if (search.isEmpty) return list;
    return list
        .where(
          (i) =>
              i.title.toLowerCase().contains(search) ||
              (i.description?.toLowerCase().contains(search) ?? false),
        )
        .toList();
  });
});
