import 'package:flutter/material.dart';

import '../../services/image_attachment_controller.dart';
import '../../services/image_upload_service.dart';
import 'app_snackbar.dart';
import 'image_upload_preview_dialog.dart';

/// Runs the standard resolve → preview/crop → confirm flow for [source]
/// ('gallery', 'camera', or 'clipboard') and appends the result to
/// [controller] as a pending image (IMPR-0019). No-ops when the user
/// cancels at any step.
Future<void> addImageFromSource(
  BuildContext context,
  ImageUploadService service,
  ImageAttachmentController controller,
  String source,
) async {
  final picked = await resolveImageSource(context, source, service);
  if (picked == null || !context.mounted) return;

  final result = await showImageUploadPreviewDialog(
    context: context,
    originalBytes: picked.bytes,
    fileName: picked.fileName,
    sourcePath: picked.sourcePath,
  );
  if (result == null || !context.mounted) return;
  await result.maybeRemoveSourceFromDevice();

  controller.addPending(result.bytes, result.fileName);
}

/// Shows the standard image-source bottom sheet (gallery / camera /
/// clipboard) and feeds the chosen image through [addImageFromSource] —
/// except gallery, which goes through [addImagesFromGallery] so the user
/// can select several photos at once (WISH-0096).
Future<void> pickImageInto(
  BuildContext context,
  ImageUploadService service,
  ImageAttachmentController controller, {
  bool includeCamera = true,
}) async {
  final source = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Gallery'),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          if (includeCamera)
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
          const PasteFromClipboardTile(),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return;
  if (source == 'gallery') {
    await addImagesFromGallery(context, service, controller);
    return;
  }
  await addImageFromSource(context, service, controller, source);
}

/// Picks any number of images from the gallery and runs each one through
/// the standard resolve → preview/crop/compress → confirm flow in turn,
/// so the user only has to open their device gallery once even when
/// adding several photos (WISH-0096) — the motivating case being old
/// photos that take a while to scroll back to. Confirmed images are
/// appended to [controller] as they're approved; cancelling an
/// individual image's dialog just skips that one and moves on to the
/// next. No-ops when the user cancels the gallery picker itself.
Future<void> addImagesFromGallery(
  BuildContext context,
  ImageUploadService service,
  ImageAttachmentController controller,
) => pickAndConfirmMultipleFromGallery(
  context,
  service,
  (result) async => controller.addPending(result.bytes, result.fileName),
);

/// Lower-level version of [addImagesFromGallery] for pages that don't use
/// [ImageAttachmentController] — e.g. ones that upload each image
/// immediately rather than deferring to save time. [onImageReady] is
/// awaited once per confirmed image, in order; the caller decides what
/// to do with the result (add to a pending list, upload immediately,
/// etc.). Returns the number of images actually confirmed (WISH-0096).
Future<int> pickAndConfirmMultipleFromGallery(
  BuildContext context,
  ImageUploadService service,
  Future<void> Function(ImageUploadResult result) onImageReady,
) async {
  final files = await service.pickMultiImage();
  if (files.isEmpty || !context.mounted) return 0;

  var added = 0;
  for (var i = 0; i < files.length; i++) {
    if (!context.mounted) break;
    final bytes = await files[i].readAsBytes();
    if (!context.mounted) break;
    final result = await showImageUploadPreviewDialog(
      context: context,
      originalBytes: bytes,
      fileName: files[i].name,
      sourcePath: files[i].path,
      stepLabel: files.length > 1 ? '${i + 1} of ${files.length}' : null,
    );
    if (result == null) continue;
    await result.maybeRemoveSourceFromDevice();
    await onImageReady(result);
    added++;
  }

  if (files.length > 1 && context.mounted) {
    context.showSnackbar(
      added == files.length
          ? 'Added $added image${added == 1 ? '' : 's'}'
          : 'Added $added of ${files.length} images',
    );
  }
  return added;
}
