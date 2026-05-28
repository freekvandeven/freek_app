import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Push a fullscreen image viewer that preserves the image's aspect
/// ratio, supports pinch-to-zoom + pan via [InteractiveViewer], and
/// dismisses on tap (anywhere outside the controls) or via the close
/// button (WISH-0075).
///
/// Use [showFullscreenNetworkImage] for a download URL or
/// [showFullscreenMemoryImage] for already-loaded bytes (e.g. a
/// pending upload preview).
Future<void> showFullscreenNetworkImage(
  BuildContext context,
  String url, {
  Object? heroTag,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, _, _) =>
          _FullscreenImageViewer(url: url, heroTag: heroTag),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// Variant for already-loaded bytes — useful for pending uploads that
/// haven't been pushed to Storage yet.
Future<void> showFullscreenMemoryImage(
  BuildContext context,
  Uint8List bytes, {
  Object? heroTag,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, _, _) =>
          _FullscreenImageViewer(bytes: bytes, heroTag: heroTag),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _FullscreenImageViewer extends StatelessWidget {
  final String? url;
  final Uint8List? bytes;
  final Object? heroTag;

  const _FullscreenImageViewer({this.url, this.bytes, this.heroTag});

  @override
  Widget build(BuildContext context) {
    final Widget image = url != null
        ? CachedNetworkImage(
            imageUrl: url!,
            fit: BoxFit.contain,
            placeholder: (_, _) => const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            ),
            errorWidget: (_, _, _) => const Center(
              child: Icon(Icons.broken_image, color: Colors.white70, size: 64),
            ),
          )
        : Image.memory(bytes!, fit: BoxFit.contain);

    final wrapped = heroTag != null ? Hero(tag: heroTag!, child: image) : image;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Tap anywhere outside the image to close.
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const SizedBox.expand(),
          ),
          Center(
            child: InteractiveViewer(minScale: 1, maxScale: 5, child: wrapped),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
