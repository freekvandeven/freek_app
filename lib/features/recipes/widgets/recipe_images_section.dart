import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Horizontal strip of a recipe's images (saved + pending uploads) with add,
/// set-primary (tap) and remove controls. Index space is saved images first,
/// then pending images.
class RecipeImagesSection extends StatelessWidget {
  final List<String> savedImageUrls;
  final List<({Uint8List bytes, String fileName})> pendingImages;
  final int primaryImageIndex;
  final VoidCallback onAdd;
  final void Function(int index) onSetPrimary;
  final void Function(int index) onRemove;

  const RecipeImagesSection({
    super.key,
    required this.savedImageUrls,
    required this.pendingImages,
    required this.primaryImageIndex,
    required this.onAdd,
    required this.onSetPrimary,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final total = savedImageUrls.length + pendingImages.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Images', style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_photo_alternate, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        if (total > 0)
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: total,
              itemBuilder: (context, index) {
                final isExisting = index < savedImageUrls.length;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () => onSetPrimary(index),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: isExisting
                              ? CachedNetworkImage(
                                  imageUrl: savedImageUrls[index],
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.broken_image),
                                  ),
                                )
                              : Image.memory(
                                  pendingImages[index - savedImageUrls.length]
                                      .bytes,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      if (index == primaryImageIndex)
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
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => onRemove(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
