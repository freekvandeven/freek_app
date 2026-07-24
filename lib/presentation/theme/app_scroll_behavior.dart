import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Adds mouse to the set of devices that can drag-scroll (Flutter's default
/// excludes it — only touch/stylus/trackpad drag by default). Without this,
/// pull-to-refresh is unreachable with a mouse: the gesture is just an
/// overscroll at the top of a drag, and a `Scrollable` that won't drag for
/// mouse never produces one (WISH-0090).
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}
