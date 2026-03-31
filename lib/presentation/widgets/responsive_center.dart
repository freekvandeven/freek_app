import 'package:flutter/material.dart';

/// Wraps [child] in a centered container with a maximum width so that
/// full-width pages look reasonable on large screens (web / desktop).
///
/// On narrow screens the child stretches to fill the available width.
class ResponsiveCenter extends StatelessWidget {
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  const ResponsiveCenter({
    super.key,
    this.maxWidth = 840,
    this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}
