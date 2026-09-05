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
import '../providers/streaming_platform_providers.dart';
import '../providers/watchlist_providers.dart';
import '../widgets/external_rating_badge.dart';
import '../widgets/platform_selector.dart';
import '../widgets/watch_status_chip.dart';

class WatchlistPage extends HookConsumerWidget {
  const WatchlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(filteredWatchlistProvider);
    final search = ref.watch(watchlistSearchProvider);
    final searchController = useSyncedSearchController(search);
    final reordering = useState(false);

    // Dragging only makes sense against the full list in priority order:
    // with a filter applied, or sorted by anything else, "above the third
    // visible row" has no unambiguous meaning in the underlying priority
    // order (WISH-0098).
    final isFiltered =
        search.isNotEmpty ||
        ref.watch(watchlistPlatformFilterProvider) != null ||
        ref.watch(watchlistStatusFilterProvider) != WatchStatusFilter.all ||
        ref.watch(watchlistSortProvider) != WatchSort.priority;
    if (isFiltered && reordering.value) reordering.value = false;

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
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Watchlist')),
        actions: [
          PopupMenuButton<WatchSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: ref.watch(watchlistSortProvider),
            onSelected: (sort) =>
                ref.read(watchlistSortProvider.notifier).state = sort,
            itemBuilder: (context) => const [
              PopupMenuItem(value: WatchSort.priority, child: Text('Priority')),
              PopupMenuItem(value: WatchSort.title, child: Text('Title')),
              PopupMenuItem(value: WatchSort.year, child: Text('Year')),
              PopupMenuItem(value: WatchSort.rating, child: Text('My rating')),
              PopupMenuItem(
                value: WatchSort.externalRating,
                child: Text('Public rating'),
              ),
              PopupMenuItem(value: WatchSort.runtime, child: Text('Runtime')),
            ],
          ),
          IconButton(
            tooltip: isFiltered
                ? 'Clear the filters and sort by priority to reorder'
                : reordering.value
                ? 'Done reordering'
                : 'Reorder priority',
            isSelected: reordering.value,
            icon: const Icon(Icons.swap_vert),
            selectedIcon: const Icon(Icons.check),
            onPressed: isFiltered
                ? null
                : () => reordering.value = !reordering.value,
          ),
          IconButton(
            tooltip: 'Streaming platforms',
            icon: const Icon(Icons.subscriptions_outlined),
            onPressed: () => context.push('/watchlist/platforms'),
          ),
        ],
      ),
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
            const _StatusFilterBar(),
            const _PlatformFilterBar(),
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
                      : reordering.value
                      ? ReorderableListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: list.length,
                          itemBuilder: (context, index) => _WatchItemTile(
                            key: ValueKey(list[index].id),
                            item: list[index],
                            reordering: true,
                          ),
                          onReorderItem: (oldIndex, newIndex) => ref
                              .read(watchlistProvider.notifier)
                              .reorder(oldIndex, newIndex),
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

  /// While reordering the row loses swipe-to-remove and its watched
  /// toggle, so a drag is never mistaken for either gesture.
  final bool reordering;

  const _WatchItemTile({
    super.key,
    required this.item,
    this.reordering = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final runtime = item.totalRuntimeMinutes;
    final subtitleParts = [
      if (item.year != null) '${item.year}',
      if (runtime != null) formatDuration(runtime),
    ];

    if (reordering) return _buildTile(context, ref, theme, subtitleParts);

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
      child: _buildTile(context, ref, theme, subtitleParts),
    );
  }

  Widget _buildTile(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    List<String> subtitleParts,
  ) {
    return ListTile(
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
          if (item.rating != null || item.externalRating != null)
            Row(
              children: [
                if (item.rating != null)
                  StarRating(value: item.rating, size: 14, showNumeric: false),
                if (item.rating != null && item.externalRating != null)
                  const SizedBox(width: 8),
                ExternalRatingBadge(
                  rating: item.externalRating,
                  source: item.externalRatingSource,
                ),
              ],
            ),
          if (item.platformIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: PlatformIcons(platformIds: item.platformIds, size: 18),
            ),
        ],
      ),
      trailing: reordering
          ? const Icon(Icons.drag_handle)
          : IconButton(
              tooltip: item.watched ? 'Mark as unwatched' : 'Mark as watched',
              icon: Icon(
                item.watched ? Icons.check_circle : Icons.check_circle_outline,
                color: item.watched ? Colors.green : null,
              ),
              onPressed: () =>
                  ref.read(watchlistProvider.notifier).toggleWatched(item),
            ),
      onTap: reordering ? null : () => context.push('/watchlist/${item.id}'),
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

/// Narrows the list to one streaming platform. Hidden entirely until at
/// least one platform is configured (WISH-0099).
class _PlatformFilterBar extends ConsumerWidget {
  const _PlatformFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platforms = ref.watch(streamingPlatformsProvider).valueOrNull ?? [];
    if (platforms.isEmpty) return const SizedBox.shrink();

    final selected = ref.watch(watchlistPlatformFilterProvider);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final platform in platforms)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(platform.name),
                selected: selected == platform.id,
                onSelected: (isSelected) =>
                    ref.read(watchlistPlatformFilterProvider.notifier).state =
                        isSelected ? platform.id : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// Narrows the list by watch progress (WISH-0098).
class _StatusFilterBar extends ConsumerWidget {
  const _StatusFilterBar();

  static const _labels = {
    WatchStatusFilter.all: 'All',
    WatchStatusFilter.unwatched: 'Unwatched',
    WatchStatusFilter.inProgress: 'In progress',
    WatchStatusFilter.watched: 'Watched',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(watchlistStatusFilterProvider);
    // A scrolling chip row rather than a SegmentedButton: four labels of
    // this length do not fit across a phone, and a segmented button wraps
    // and clips them instead of scrolling. It also matches the platform
    // filter row directly below.
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final entry in _labels.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(entry.value),
                selected: selected == entry.key,
                // Re-tapping the active chip falls back to All rather than
                // leaving no status selected.
                onSelected: (isSelected) =>
                    ref.read(watchlistStatusFilterProvider.notifier).state =
                        isSelected ? entry.key : WatchStatusFilter.all,
              ),
            ),
        ],
      ),
    );
  }
}
