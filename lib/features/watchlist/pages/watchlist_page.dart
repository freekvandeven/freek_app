import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';
import 'package:personal_app/presentation/widgets/star_rating.dart';

import '../../../presentation/hooks/use_synced_search_controller.dart';
import '../../../presentation/widgets/pullable_center.dart';
import '../../../utils/duration_format.dart';
import '../models/watch_item.dart';
import '../providers/watchlist_providers.dart';
import '../widgets/watch_status_chip.dart';

class WatchlistPage extends HookConsumerWidget {
  const WatchlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(filteredWatchlistProvider);
    final search = ref.watch(watchlistSearchProvider);
    final searchController = useSyncedSearchController(search);

    // Watchlist is a pushed route rather than a bottom-nav tab, so this
    // page is disposed when the user leaves for another feature — reset
    // the search then, but not when coming back from a detail/edit push
    // within the watchlist itself (BUG-0047).
    useEffect(() {
      if (ref.read(watchlistSearchProvider).isNotEmpty) {
        ref.read(watchlistSearchProvider.notifier).state = '';
      }
      return null;
    }, const []);

    return Scaffold(
      appBar: AppBar(title: const QuickActionsTitle(child: Text('Watchlist'))),
      body: ResponsiveCenter(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search watchlist...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              ref.read(watchlistSearchProvider.notifier).state =
                                  '',
                        )
                      : null,
                ),
                onChanged: (v) =>
                    ref.read(watchlistSearchProvider.notifier).state = v,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(watchlistProvider.future),
                child: items.when(
                  data: (list) => list.isEmpty
                      ? const PullableCenter(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.movie_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text('Nothing on the watchlist yet'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: list.length,
                          itemBuilder: (context, index) =>
                              _WatchItemTile(item: list[index]),
                        ),
                  loading: () =>
                      const PullableCenter(child: CircularProgressIndicator()),
                  error: (e, _) => PullableCenter(child: Text('Error: $e')),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/watchlist/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _WatchItemTile extends ConsumerWidget {
  final WatchItem item;
  const _WatchItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final runtime = item.totalRuntimeMinutes;
    final subtitleParts = [
      if (item.year != null) '${item.year}',
      if (runtime != null) formatDuration(runtime),
    ];

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove from Watchlist'),
          content: Text('Remove "${item.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
      onDismissed: (_) =>
          ref.read(watchlistProvider.notifier).deleteItem(item.id),
      child: ListTile(
        leading: _Poster(item: item),
        title: Row(
          children: [
            Expanded(child: Text(item.title)),
            WatchStatusChip(status: item.status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (subtitleParts.isNotEmpty)
              Text(
                subtitleParts.join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            if (item.rating != null)
              StarRating(value: item.rating, size: 14, showNumeric: false),
          ],
        ),
        trailing: IconButton(
          tooltip: item.watched ? 'Mark as unwatched' : 'Mark as watched',
          icon: Icon(
            item.watched ? Icons.check_circle : Icons.check_circle_outline,
            color: item.watched ? Colors.green : null,
          ),
          onPressed: () =>
              ref.read(watchlistProvider.notifier).toggleWatched(item),
        ),
        onTap: () => context.push('/watchlist/${item.id}'),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  final WatchItem item;
  const _Poster({required this.item});

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      child: Icon(
        item.type == WatchItemType.series ? Icons.tv : Icons.movie,
        size: 20,
      ),
    );
    if (item.posterUrl == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: item.posterUrl!,
        width: 40,
        height: 40,
        memCacheWidth: 120,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}
