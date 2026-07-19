import 'package:flutter/material.dart';

import '../../services/image_attachment_controller.dart';
import '../../services/image_upload_service.dart';
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
/// clipboard) and feeds the chosen image through [addImageFromSource].
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
  await addImageFromSource(context, service, controller, source);
}
