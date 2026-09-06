import 'package:flutter/material.dart';

import '../models/watch_item.dart';

/// One season on the detail page: a whole-season checkbox, and — when the
/// season's length is known — an expandable grid of episode numbers to
/// tick off individually (WISH-0104).
///
/// Episodes are shown by number only. Titles would cost a TMDB request
/// per season and inflate every watchlist read for something a numbered
/// grid already conveys.
class SeasonProgressTile extends StatelessWidget {
  final Season season;

  /// Ticks or unticks the whole season.
  final ValueChanged<bool> onSeasonChanged;

  /// Ticks or unticks one episode.
  final void Function(int episode, bool watched) onEpisodeChanged;

  const SeasonProgressTile({
    super.key,
    required this.season,
    required this.onSeasonChanged,
    required this.onEpisodeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = season.episodeCount;
    final title = Text(season.title ?? 'Season ${season.number}');

    final subtitle = count == null
        ? null
        : Text(
            season.status == WatchStatus.partiallyWatched
                ? '${season.watchedEpisodeCount} of $count episodes'
                : '$count episodes',
          );

    final checkbox = Checkbox(
      value: season.isFullyWatched
          ? true
          : (season.status == WatchStatus.unwatched ? false : null),
      // Tristate so a part-watched season reads as such at a glance
      // instead of looking untouched.
      tristate: true,
      onChanged: (_) => onSeasonChanged(!season.isFullyWatched),
    );

    // Without a known episode count there is nothing to expand into, so
    // the season stays the plain checkbox row it has always been.
    if (count == null || count <= 0) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: checkbox,
        title: title,
        subtitle: subtitle,
        onTap: () => onSeasonChanged(!season.isFullyWatched),
      );
    }

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 8, bottom: 12),
      leading: checkbox,
      title: title,
      subtitle: subtitle,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var episode = 1; episode <= count; episode++)
                FilterChip(
                  label: Text('$episode'),
                  selected: season.isEpisodeWatched(episode),
                  onSelected: (selected) => onEpisodeChanged(episode, selected),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Episode $episode',
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Tap an episode to mark it watched',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
