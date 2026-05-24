import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../services/image_upload_service.dart';
import 'flutter_cropper_page.dart';

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

/// What the source picker returns — abstracts away whether the user
/// chose Gallery, Camera, or Paste from clipboard so callers can hand
/// it straight to [showImageUploadPreviewDialog] (WISH-0072).
class PickedImage {
  final Uint8List bytes;
  final String fileName;

  /// Filesystem path of the picked file, when applicable (gallery /
  /// camera). Null for clipboard images.
  final String? sourcePath;

  const PickedImage({
    required this.bytes,
    required this.fileName,
    this.sourcePath,
  });
}

/// Resolve one of the standard source identifiers ('gallery', 'camera',
/// 'clipboard') into bytes + filename. Shows a snackbar and returns
/// null if the clipboard has no image. The caller chooses the source
/// (typically via a bottom sheet) and passes the string here so the
/// branching lives in one place (WISH-0072).
Future<PickedImage?> resolveImageSource(
  BuildContext context,
  String source,
  ImageUploadService service,
) async {
  switch (source) {
    case 'clipboard':
      final pasted = await ImageUploadService.readImageFromClipboard();
      if (pasted == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No image on clipboard')),
          );
        }
        return null;
      }
      return PickedImage(bytes: pasted.bytes, fileName: pasted.fileName);
    case 'gallery':
    case 'camera':
      final file = source == 'gallery'
          ? await service.pickImage()
          : await service.captureImage();
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      return PickedImage(
        bytes: bytes,
        fileName: file.name,
        sourcePath: file.path,
      );
  }
  return null;
}

/// Standard "Paste from clipboard" ListTile for image-source bottom
/// sheets. Pops the parent route with the sentinel `'clipboard'` so
/// callers can dispatch via [resolveImageSource] (WISH-0072).
class PasteFromClipboardTile extends StatelessWidget {
  const PasteFromClipboardTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.content_paste),
      title: const Text('Paste from clipboard'),
      onTap: () => Navigator.pop(context, 'clipboard'),
    );
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
    Uint8List cropped;
    if (ImageUploadService.isNativeCropperPlatform) {
      cropped = await ImageUploadService.cropImage(
        _baseBytes,
        fileExtension: ext,
      );
    } else {
      // Desktop / web — use the Flutter-rendered cropper page (WISH-0072).
      // It cannot be shown inline on top of the dialog, so close the
      // dialog's modal barrier by pushing a fullscreen route.
      final result = await showFlutterCropperPage(context, _baseBytes);
      cropped = result ?? _baseBytes;
    }
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
