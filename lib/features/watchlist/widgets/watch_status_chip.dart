import 'package:flutter/material.dart';

import '../models/watch_item.dart';

/// Human-readable label for a watch status, used by the chip and by the
/// detail page's summary line (WISH-0098).
String watchStatusLabel(WatchStatus status) => switch (status) {
  WatchStatus.unwatched => 'Unwatched',
  WatchStatus.partiallyWatched => 'Partially watched',
  WatchStatus.watched => 'Watched',
};

/// Compact badge showing how far through an entry the user is. Only
/// rendered for entries that have actually been started, so an untouched
/// watchlist stays visually quiet.
class WatchStatusChip extends StatelessWidget {
  final WatchStatus status;
  const WatchStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == WatchStatus.unwatched) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final partial = status == WatchStatus.partiallyWatched;
    final background = partial
        ? scheme.tertiaryContainer
        : scheme.secondaryContainer;
    final foreground = partial
        ? scheme.onTertiaryContainer
        : scheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        watchStatusLabel(status),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}
