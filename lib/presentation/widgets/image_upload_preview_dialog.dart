import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/image_upload_service.dart';

/// Result from the image upload preview dialog.
class ImageUploadResult {
  final Uint8List bytes;
  final String fileName;

  const ImageUploadResult({required this.bytes, required this.fileName});
}

/// Shows a preview of the selected image with file size and compression options.
/// Returns [ImageUploadResult] if the user proceeds, or null if cancelled.
Future<ImageUploadResult?> showImageUploadPreviewDialog({
  required BuildContext context,
  required Uint8List originalBytes,
  required String fileName,
}) {
  return showDialog<ImageUploadResult>(
    context: context,
    builder: (ctx) => _ImageUploadPreviewDialog(
      originalBytes: originalBytes,
      fileName: fileName,
    ),
  );
}

class _ImageUploadPreviewDialog extends StatefulWidget {
  final Uint8List originalBytes;
  final String fileName;

  const _ImageUploadPreviewDialog({
    required this.originalBytes,
    required this.fileName,
  });

  @override
  State<_ImageUploadPreviewDialog> createState() =>
      _ImageUploadPreviewDialogState();
}

class _ImageUploadPreviewDialogState extends State<_ImageUploadPreviewDialog> {
  late Uint8List _currentBytes;
  int _selectedQuality = 0; // 0=original, 1=good(85), 2=compressed(60)
  bool _compressing = false;

  static const _qualities = [
    (label: 'Original', quality: 100),
    (label: 'Good', quality: 85),
    (label: 'Compressed', quality: 60),
  ];

  @override
  void initState() {
    super.initState();
    _currentBytes = widget.originalBytes;
  }

  Future<void> _applyQuality(int index) async {
    if (index == _selectedQuality) return;
    setState(() {
      _selectedQuality = index;
      _compressing = true;
    });

    final quality = _qualities[index].quality;
    Uint8List result;
    if (quality >= 100) {
      result = widget.originalBytes;
    } else {
      result = await ImageUploadService.compressBytes(
        widget.originalBytes,
        quality: quality,
      );
    }

    if (mounted) {
      setState(() {
        _currentBytes = result;
        _compressing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final originalSize = widget.originalBytes.length;
    final currentSize = _currentBytes.length;
    final saved = originalSize - currentSize;

    return AlertDialog(
      title: const Text('Upload Image'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: Image.memory(_currentBytes, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 12),

            // File size info
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_size_select_large,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  formatBytes(currentSize),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (saved > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(saved ${formatBytes(saved)})',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.green),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Quality selector
            Text('Quality', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                for (var i = 0; i < _qualities.length; i++)
                  ButtonSegment(value: i, label: Text(_qualities[i].label)),
              ],
              selected: {_selectedQuality},
              onSelectionChanged: (selected) {
                _applyQuality(selected.first);
              },
            ),

            if (_compressing) ...[
              const SizedBox(height: 12),
              const SizedBox(height: 2, child: LinearProgressIndicator()),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _compressing
              ? null
              : () => Navigator.pop(
                  context,
                  ImageUploadResult(
                    bytes: _currentBytes,
                    fileName: _selectedQuality == 0
                        ? widget.fileName
                        : '${widget.fileName.split('.').first}.jpg',
                  ),
                ),
          child: const Text('Upload'),
        ),
      ],
    );
  }
}
