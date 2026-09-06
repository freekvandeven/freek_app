import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_app/presentation/widgets/app_snackbar.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../presentation/widgets/fullscreen_image_viewer.dart';
import '../../../presentation/widgets/star_rating.dart';
import '../../../utils/duration_format.dart';
import '../models/watch_item.dart';
import '../providers/watchlist_providers.dart';
import '../utils/runtime_display.dart';
import '../widgets/external_rating_badge.dart';
import '../widgets/platform_selector.dart';
import '../widgets/season_progress_tile.dart';
import '../widgets/watch_status_chip.dart';

class WatchItemDetailPage extends ConsumerWidget {
  final String itemId;
  const WatchItemDetailPage({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(watchlistProvider);

    return itemsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (items) {
        final item = items.where((i) => i.id == itemId).firstOrNull;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Entry not found')),
          );
        }
        return _buildDetail(context, ref, item);
      },
    );
  }

  Widget _buildDetail(BuildContext context, WidgetRef ref, WatchItem item) {
    final theme = Theme.of(context);
    final runtime = runtimeForDisplay(item);

    return Scaffold(
      appBar: AppBar(
        title: QuickActionsTitle(child: Text(item.title)),
        actions: [
          IconButton(
            tooltip: item.watched ? 'Mark as unwatched' : 'Mark as watched',
            icon: Icon(
              item.watched ? Icons.check_circle : Icons.check_circle_outline,
              color: item.watched ? Colors.green : null,
            ),
            onPressed: () =>
                ref.read(watchlistProvider.notifier).toggleWatched(item),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/watchlist/${item.id}/edit'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (item.posterUrl != null) ...[
                Center(
                  child: GestureDetector(
                    onTap: () =>
                        showFullscreenNetworkImage(context, item.posterUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: item.posterUrl!,
                        height: 260,
                        memCacheWidth: 600,
                        fit: BoxFit.contain,
                        errorWidget: (_, _, _) =>
                            const Icon(Icons.broken_image, size: 48),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    avatar: Icon(
                      item.type == WatchItemType.series
                          ? Icons.tv
                          : Icons.movie,
                      size: 18,
                    ),
                    label: Text(
                      item.type == WatchItemType.series ? 'Series' : 'Movie',
                    ),
                  ),
                  if (item.year != null) Chip(label: Text('${item.year}')),
                  if (runtime.minutes != null)
                    Chip(
                      avatar: const Icon(Icons.timer_outlined, size: 18),
                      label: Text(
                        runtime.isRemaining
                            ? '${formatDuration(runtime.minutes!)} left'
                            : formatDuration(runtime.minutes!),
                      ),
                    ),
                  WatchStatusChip(status: item.status),
                ],
              ),
              const SizedBox(height: 16),

              if (item.platformIds.isNotEmpty) ...[
                PlatformIcons(
                  platformIds: item.platformIds,
                  size: 32,
                  openable: true,
                ),
                const SizedBox(height: 16),
              ],

              if (item.rating != null || item.externalRating != null) ...[
                Row(
                  children: [
                    if (item.rating != null)
                      StarRating(value: item.rating, size: 24),
                    if (item.rating != null && item.externalRating != null)
                      const SizedBox(width: 12),
                    ExternalRatingBadge(
                      rating: item.externalRating,
                      source: item.externalRatingSource,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              if (item.description != null) ...[
                Text(item.description!, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
              ],

              if (item.imdbUrl != null)
                _LinkTile(
                  icon: Icons.movie_filter_outlined,
                  label: 'View on IMDb',
                  subtitle: item.imdbId!,
                  url: item.imdbUrl!,
                ),
              if (item.sourceUrl != null)
                _LinkTile(
                  icon: Icons.link,
                  label: 'Source link',
                  subtitle: item.sourceUrl!,
                  url: item.sourceUrl!,
                ),

              if (item.seasons.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Seasons', style: theme.textTheme.titleMedium),
                for (final season in item.seasons)
                  SeasonProgressTile(
                    season: season,
                    onSeasonChanged: (watched) => ref
                        .read(watchlistProvider.notifier)
                        .setSeasonWatched(item, season.number, watched),
                    onEpisodeChanged: (episode, watched) => ref
                        .read(watchlistProvider.notifier)
                        .setEpisodeWatched(
                          item,
                          season.number,
                          episode,
                          watched,
                        ),
                  ),
              ],

              if (item.review != null) ...[
                const SizedBox(height: 16),
                Text('Review', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(item.review!, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final String url;

  const _LinkTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () async {
        final uri = Uri.tryParse(url);
        // Source links are deliberately unvalidated (they can point at a
        // magnet link or a local file), so a launch failure is expected
        // for some of them rather than exceptional.
        if (uri == null ||
            !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (context.mounted) {
            context.showErrorSnackbar('Could not open $url');
          }
        }
      },
    );
  }
}
