import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/image_attachment_controller.dart';
import 'fullscreen_image_viewer.dart';

/// Horizontal strip of an [ImageAttachmentController]'s images (saved +
/// pending) with remove overlays, shared by the image-carrying edit pages
/// (IMPR-0019). Renders nothing while the controller is empty.
///
/// Tapping a thumbnail opens the fullscreen viewer unless [onTapImage]
/// overrides it (recipes tap to set the primary image instead, with
/// [showPrimaryBadge] marking the current one).
class ImageAttachmentStrip extends StatelessWidget {
  final ImageAttachmentController controller;
  final double thumbnailSize;
  final bool showPrimaryBadge;
  final void Function(int index)? onTapImage;

  const ImageAttachmentStrip({
    super.key,
    required this.controller,
    this.thumbnailSize = 100,
    this.showPrimaryBadge = false,
    this.onTapImage,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isEmpty) return const SizedBox.shrink();
        final saved = controller.savedUrls;
        final pending = controller.pendingImages;
        return SizedBox(
          height: thumbnailSize,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: controller.totalCount,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final isExisting = index < saved.length;
              return Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (onTapImage != null) {
                        onTapImage!(index);
                      } else if (isExisting) {
                        showFullscreenNetworkImage(context, saved[index]);
                      } else {
                        showFullscreenMemoryImage(
                          context,
                          pending[index - saved.length].bytes,
                        );
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: isExisting
                          ? CachedNetworkImage(
                              imageUrl: saved[index],
                              width: thumbnailSize,
                              height: thumbnailSize,
                              // 3x logical size for device-pixel-ratio
                              // headroom (IMPR-0017).
                              memCacheWidth: (thumbnailSize * 3).round(),
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: thumbnailSize,
                                height: thumbnailSize,
                                color: Colors.grey[300],
                                child: const Icon(Icons.broken_image),
                              ),
                            )
                          : Image.memory(
                              pending[index - saved.length].bytes,
                              width: thumbnailSize,
                              height: thumbnailSize,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  if (showPrimaryBadge && index == controller.primaryIndex)
                    Positioned(
                      top: 2,
                      left: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Primary',
                          style: TextStyle(color: Colors.white, fontSize: 9),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => controller.removeAt(index),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
