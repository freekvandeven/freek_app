import 'package:flutter/material.dart';

/// Centers [child] inside a scrollable so it can still be pulled to
/// refresh even as a loading/empty/error placeholder that wouldn't
/// otherwise fill or exceed the viewport — `RefreshIndicator` only ever
/// fires from an actual `Scrollable`, so a bare `Center` under it can't
/// be dragged at all (WISH-0090).
class PullableCenter extends StatelessWidget {
  final Widget child;
  const PullableCenter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}
