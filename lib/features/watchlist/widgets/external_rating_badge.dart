import 'package:flutter/material.dart';

import '../../../utils/decimal_input.dart';

/// Public rating out of 10, shown next to the personal star rating so the
/// quality of a title is readable at a glance (WISH-0101).
///
/// The [source] is surfaced in the tooltip rather than assumed to be IMDb:
/// TMDB's API does not expose IMDb's rating, and a hand-typed number has
/// no source at all.
class ExternalRatingBadge extends StatelessWidget {
  final double? rating;
  final String? source;
  final double size;

  const ExternalRatingBadge({
    super.key,
    required this.rating,
    this.source,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    final value = rating;
    if (value == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: source == null
          ? 'Public rating: ${formatDecimal(value)}/10'
          : '$source rating: ${formatDecimal(value)}/10',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rate_rounded, size: size + 2, color: Colors.amber),
          const SizedBox(width: 2),
          Text(
            formatDecimal(value),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: size,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          Text(
            '/10',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: size - 2,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
