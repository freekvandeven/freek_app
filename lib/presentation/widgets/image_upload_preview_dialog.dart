import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../services/image_upload_service.dart';

/// Result from the image upload preview dialog.
class ImageUploadResult {
  final Uint8List bytes;
  final String fileName;

  /// When true and a [sourcePath] was supplied, the caller should attempt
  /// to delete the original image from the device's photo library after
  /// the upload finishes via [ImageUploadService.tryRemoveSourceAsset]
  /// (WISH-0070).
  final bool removeSourceAfterUpload;

  /// Original device path (XFile.path) carried through so the caller can
  /// pass it to [ImageUploadService.tryRemoveSourceAsset] without having
  /// to plumb it separately.
  final String? sourcePath;

  const ImageUploadResult({
    required this.bytes,
    required this.fileName,
    this.removeSourceAfterUpload = false,
    this.sourcePath,
  });

  /// Convenience for the upload sites: if the user opted in to removing
  /// the source from the device, ask the OS to delete it. Safe to call
  /// unconditionally — no-op when the user didn't opt in or no path was
  /// supplied (WISH-0070).
  Future<void> maybeRemoveSourceFromDevice() async {
    if (!removeSourceAfterUpload || sourcePath == null) return;
    await ImageUploadService.tryRemoveSourceAsset(sourcePath!);
  }
}

/// Shows a preview of the selected image with file size, crop, compression
/// options, and (when [sourcePath] is provided on a mobile platform) an
/// opt-in to delete the original from the device's photo library after a
/// successful upload. Returns [ImageUploadResult] if the user proceeds, or
/// null if cancelled.
Future<ImageUploadResult?> showImageUploadPreviewDialog({
  required BuildContext context,
  required Uint8List originalBytes,
  required String fileName,
  String? sourcePath,
}) {
  return showDialog<ImageUploadResult>(
    context: context,
    builder: (ctx) => _ImageUploadPreviewDialog(
      originalBytes: originalBytes,
      fileName: fileName,
      sourcePath: sourcePath,
    ),
  );
}

class _ImageUploadPreviewDialog extends StatefulWidget {
  final Uint8List originalBytes;
  final String fileName;
  final String? sourcePath;

  const _ImageUploadPreviewDialog({
    required this.originalBytes,
    required this.fileName,
    required this.sourcePath,
  });

  @override
  State<_ImageUploadPreviewDialog> createState() =>
      _ImageUploadPreviewDialogState();
}

class _ImageUploadPreviewDialogState extends State<_ImageUploadPreviewDialog> {
  late Uint8List _baseBytes;
  late Uint8List _currentBytes;
  int _selectedQuality = 0;
  bool _busy = false;
  bool _removeSource = false;
  bool _wasCropped = false;

  static const _qualities = [
    (label: 'Original', quality: 100),
    (label: 'Good', quality: 85),
    (label: 'Compressed', quality: 60),
  ];

  bool get _canOfferSourceRemoval =>
      !kIsWeb && widget.sourcePath != null && widget.sourcePath!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _baseBytes = widget.originalBytes;
    _currentBytes = widget.originalBytes;
  }

  Future<void> _applyQuality(int index) async {
    if (index == _selectedQuality) return;
    setState(() {
      _selectedQuality = index;
      _busy = true;
    });

    final quality = _qualities[index].quality;
    final result = quality >= 100
        ? _baseBytes
        : await ImageUploadService.compressBytes(_baseBytes, quality: quality);

    if (mounted) {
      setState(() {
        _currentBytes = result;
        _busy = false;
      });
    }
  }

  Future<void> _cropImage() async {
    setState(() => _busy = true);
    final ext = widget.fileName.contains('.')
        ? widget.fileName.split('.').last
        : 'jpg';
    final cropped = await ImageUploadService.cropImage(
      _baseBytes,
      fileExtension: ext,
    );
    if (!mounted) return;
    final didCrop = cropped.length != _baseBytes.length;
    setState(() {
      _baseBytes = cropped;
      _wasCropped = _wasCropped || didCrop;
      _busy = false;
    });
    // Re-apply the active quality on top of the new base.
    if (_selectedQuality != 0) {
      final reapply = _selectedQuality;
      _selectedQuality = 0;
      await _applyQuality(reapply);
    } else {
      if (mounted) setState(() => _currentBytes = cropped);
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: Image.memory(_currentBytes, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 12),

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
            const SizedBox(height: 12),

            if (!kIsWeb)
              OutlinedButton.icon(
                onPressed: _busy ? null : _cropImage,
                icon: const Icon(Icons.crop),
                label: Text(_wasCropped ? 'Crop again' : 'Crop'),
              ),
            const SizedBox(height: 12),

            Text('Quality', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                for (var i = 0; i < _qualities.length; i++)
                  ButtonSegment(value: i, label: Text(_qualities[i].label)),
              ],
              selected: {_selectedQuality},
              onSelectionChanged: _busy
                  ? null
                  : (selected) => _applyQuality(selected.first),
            ),

            if (_canOfferSourceRemoval) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _removeSource,
                onChanged: (v) => setState(() => _removeSource = v ?? false),
                title: const Text('Remove from device after upload'),
                subtitle: const Text(
                  'You will be asked to confirm by your OS.',
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ],

            if (_busy) ...[
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
          onPressed: _busy
              ? null
              : () => Navigator.pop(
                  context,
                  ImageUploadResult(
                    bytes: _currentBytes,
                    fileName: _selectedQuality == 0 && !_wasCropped
                        ? widget.fileName
                        : '${widget.fileName.split('.').first}.jpg',
                    removeSourceAfterUpload:
                        _canOfferSourceRemoval && _removeSource,
                    sourcePath: widget.sourcePath,
                  ),
                ),
          child: const Text('Upload'),
        ),
      ],
    );
  }
}
