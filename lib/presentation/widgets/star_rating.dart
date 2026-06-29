import 'package:flutter/material.dart';

/// Renders a 0–5 star rating with support for half-star steps. When
/// [onChanged] is provided the row is interactive — tapping a star's
/// left half sets the rating to `i + 0.5`, the right half sets `i + 1`,
/// and tapping the currently-active star clears the rating. When
/// [onChanged] is null the widget is purely a display.
///
/// Shows a small "x.x / 5" badge to the right of the stars; the
/// 1–10 alternative the wish mentions is just `rating * 2` so the
/// numeric badge covers both audiences without a separate setting
/// (WISH-0080).
class StarRating extends StatelessWidget {
  /// Current rating in `[0, 5]` in 0.5 increments. `null` = unrated.
  final double? value;

  /// When provided, the widget becomes interactive and emits new
  /// ratings via this callback. The callback receives `null` when the
  /// user taps to clear the rating.
  final ValueChanged<double?>? onChanged;

  /// Visual size of each star. Defaults to 24 (interactive) / 16
  /// (display) depending on whether [onChanged] is provided — pass
  /// explicitly to override.
  final double? size;

  /// Whether to show the "x.x / 5" numeric badge next to the stars.
  /// Defaults to true.
  final bool showNumeric;

  const StarRating({
    super.key,
    required this.value,
    this.onChanged,
    this.size,
    this.showNumeric = true,
  });

  bool get _interactive => onChanged != null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = Colors.amber.shade600;
    final dimColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.35);
    final iconSize = size ?? (_interactive ? 24 : 16);
    final rating = value ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 5; i++)
          _StarSlot(
            index: i,
            rating: rating,
            iconSize: iconSize,
            activeColor: activeColor,
            dimColor: dimColor,
            interactive: _interactive,
            currentValue: value,
            onChanged: onChanged,
          ),
        if (showNumeric) ...[
          const SizedBox(width: 6),
          Text(
            value == null
                ? (_interactive ? 'Tap to rate' : '—')
                : '${rating.toStringAsFixed(1)} / 5',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _StarSlot extends StatelessWidget {
  final int index;
  final double rating;
  final double iconSize;
  final Color activeColor;
  final Color dimColor;
  final bool interactive;
  final double? currentValue;
  final ValueChanged<double?>? onChanged;

  const _StarSlot({
    required this.index,
    required this.rating,
    required this.iconSize,
    required this.activeColor,
    required this.dimColor,
    required this.interactive,
    required this.currentValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filled = rating >= index + 1;
    final half = !filled && rating >= index + 0.5;

    final icon = Icon(
      filled
          ? Icons.star_rounded
          : (half ? Icons.star_half_rounded : Icons.star_outline_rounded),
      size: iconSize,
      color: filled || half ? activeColor : dimColor,
    );

    if (!interactive) return icon;

    // Split each star into two tap zones so users can pick half steps.
    // Tapping the same value twice clears the rating (matches the
    // common "tap-to-toggle" idiom and avoids needing a separate
    // clear control).
    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: Stack(
        children: [
          icon,
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final v = index + 0.5;
                      onChanged!(currentValue == v ? null : v);
                    },
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final v = (index + 1).toDouble();
                      onChanged!(currentValue == v ? null : v);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
