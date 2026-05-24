import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:uuid/uuid.dart';

import '../features/auth/providers/auth_providers.dart';
import 'log_service.dart';

final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  final user = ref.watch(currentUserProvider);
  return ImageUploadService(
    userId: user?.id ?? 'anonymous',
    storageUsedBytes: user?.storageUsedBytes ?? 0,
    storageLimitBytes: user?.storageLimitBytes ?? 0,
  );
});

class StorageLimitExceededException implements Exception {
  final int fileSize;
  final int used;
  final int limit;
  const StorageLimitExceededException(this.fileSize, this.used, this.limit);

  @override
  String toString() =>
      'Storage limit exceeded. This file is '
      '${formatBytes(fileSize)} but you only have '
      '${formatBytes(limit - used)} remaining of ${formatBytes(limit)}.';
}

/// Format bytes to human-readable string.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

class ImageUploadService {
  final String userId;
  final int storageUsedBytes;
  final int storageLimitBytes;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  ImageUploadService({
    required this.userId,
    this.storageUsedBytes = 0,
    this.storageLimitBytes = 0,
  });

  /// Pick an image from gallery. Returns the XFile or null.
  Future<XFile?> pickImage() async {
    return _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
    );
  }

  /// Pick an image from camera. Returns the XFile or null.
  Future<XFile?> captureImage() async {
    if (kIsWeb) return null;
    return _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
    );
  }

  /// Compress image bytes to JPEG at the given quality (1-100).
  static Future<Uint8List> compressBytes(
    Uint8List bytes, {
    int quality = 85,
  }) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    return Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
  }

  /// True on platforms where [cropImage] launches the native image_cropper
  /// (Android/iOS). Desktop and web go through the Flutter-rendered
  /// crop_your_image page wrapped at the dialog layer (WISH-0072).
  static bool get isNativeCropperPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Launch the native image-cropper UI on the given bytes and return the
  /// cropped result. Returns the original bytes if the user cancels, or
  /// if cropping isn't supported on this platform (web/desktop — those
  /// route through the Flutter crop page instead). Falls back to the
  /// original bytes on any error so the upload flow can still proceed
  /// (WISH-0070, WISH-0072).
  static Future<Uint8List> cropImage(
    Uint8List bytes, {
    String fileExtension = 'jpg',
  }) async {
    if (!isNativeCropperPlatform) return bytes;
    try {
      // image_cropper needs a file path; write to a temp file under the
      // platform's tmp dir, run the cropper, read back the cropped bytes.
      final dir = Directory.systemTemp;
      final tmp = File('${dir.path}/crop_${const Uuid().v4()}.$fileExtension');
      await tmp.writeAsBytes(bytes, flush: true);
      final cropper = ImageCropper();
      final cropped = await cropper.cropImage(
        sourcePath: tmp.path,
        uiSettings: [
          AndroidUiSettings(toolbarTitle: 'Crop', lockAspectRatio: false),
          IOSUiSettings(title: 'Crop'),
        ],
      );
      if (cropped == null) {
        try {
          await tmp.delete();
        } catch (_) {}
        return bytes;
      }
      final out = await File(cropped.path).readAsBytes();
      try {
        await tmp.delete();
      } catch (_) {}
      try {
        await File(cropped.path).delete();
      } catch (_) {}
      return out;
    } catch (e) {
      LogService.instance.warning('Image crop failed, using original: $e');
      return bytes;
    }
  }

  /// Try to remove a gallery asset that matches [sourcePath] (the path
  /// returned by image_picker for a gallery pick). On Android 11+ and
  /// iOS, this prompts the user for confirmation via the OS dialog —
  /// the user can still refuse. Returns `true` when the system reports
  /// the asset(s) as deleted, `false` otherwise (no asset found,
  /// permission denied, or platform doesn't support it). Never throws —
  /// the source-removal feature is best-effort by design (WISH-0070).
  static Future<bool> tryRemoveSourceAsset(String sourcePath) async {
    if (kIsWeb) return false;
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth && !permission.hasAccess) {
        return false;
      }
      final fileName = sourcePath
          .split(Platform.pathSeparator)
          .last
          .split('/')
          .last;
      // The image_picker temp path doesn't match a gallery asset directly;
      // we look up the asset by title across the user's image albums.
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      if (albums.isEmpty) return false;
      final all = albums.first;
      final count = await all.assetCountAsync;
      // Scan pages of recent assets — the just-picked image is almost
      // always near the top; cap at 200 to keep this bounded.
      const pageSize = 50;
      final pagesToCheck = (count / pageSize).ceil().clamp(0, 4);
      for (var page = 0; page < pagesToCheck; page++) {
        final assets = await all.getAssetListPaged(page: page, size: pageSize);
        for (final asset in assets) {
          if (asset.title == fileName) {
            final removed = await PhotoManager.editor.deleteWithIds([asset.id]);
            return removed.isNotEmpty;
          }
        }
      }
      return false;
    } catch (e) {
      LogService.instance.warning('tryRemoveSourceAsset failed: $e');
      return false;
    }
  }

  /// Read an image off the system clipboard (PNG / JPEG). Returns null
  /// when the clipboard has no image (or no clipboard support on this
  /// platform). Best-effort — never throws (WISH-0072).
  static Future<({Uint8List bytes, String fileName})?>
  readImageFromClipboard() async {
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) return null;
      final reader = await clipboard.read();
      // Prefer PNG since most browser/copy operations produce PNG.
      for (final entry in [
        (format: Formats.png, ext: 'png'),
        (format: Formats.jpeg, ext: 'jpg'),
      ]) {
        if (reader.canProvide(entry.format)) {
          final completer = _ClipboardCompleter();
          reader.getFile(entry.format, (file) async {
            try {
              final stream = file.getStream();
              final chunks = <List<int>>[];
              await for (final chunk in stream) {
                chunks.add(chunk);
              }
              final total = chunks.fold<int>(0, (n, c) => n + c.length);
              final bytes = Uint8List(total);
              var offset = 0;
              for (final c in chunks) {
                bytes.setRange(offset, offset + c.length, c);
                offset += c.length;
              }
              completer.complete(bytes);
            } catch (e) {
              completer.completeError(e);
            }
          }, onError: completer.completeError);
          final bytes = await completer.future;
          if (bytes == null) return null;
          return (
            bytes: bytes,
            fileName:
                'clipboard_${DateTime.now().millisecondsSinceEpoch}.${entry.ext}',
          );
        }
      }
      return null;
    } catch (e) {
      LogService.instance.warning('readImageFromClipboard failed: $e');
      return null;
    }
  }

  /// Pick an image from gallery and upload it. Returns the download URL.
  Future<String?> pickAndUploadImage({String folder = 'images'}) async {
    final XFile? file = await pickImage();
    if (file == null) return null;
    return uploadXFile(file, folder: folder);
  }

  /// Pick an image from camera and upload it. Returns the download URL.
  Future<String?> captureAndUploadImage({String folder = 'images'}) async {
    final XFile? file = await captureImage();
    if (file == null) return null;
    return uploadXFile(file, folder: folder);
  }

  /// Upload an XFile to Firebase Storage and return the download URL.
  /// Throws [StorageLimitExceededException] if the upload would exceed the user's limit.
  Future<String> uploadXFile(XFile file, {String folder = 'images'}) async {
    final Uint8List bytes = await file.readAsBytes();
    return uploadImageBytes(bytes, fileName: file.name, folder: folder);
  }

  /// Upload raw image bytes to Firebase Storage and return the download URL.
  /// Throws [StorageLimitExceededException] if the upload would exceed the user's limit.
  Future<String> uploadImageBytes(
    Uint8List bytes, {
    String fileName = 'image.jpg',
    String folder = 'images',
  }) async {
    // Force-refresh the ID token so the inviteVerified claim is present.
    await FirebaseAuth.instance.currentUser?.getIdToken(true);

    final ext = fileName.split('.').last;
    final storageName = '${const Uuid().v4()}.$ext';
    final ref = _storage.ref('users/$userId/$folder/$storageName');

    // Check storage limit before uploading
    if (storageLimitBytes > 0 &&
        storageUsedBytes + bytes.length > storageLimitBytes) {
      throw StorageLimitExceededException(
        bytes.length,
        storageUsedBytes,
        storageLimitBytes,
      );
    }

    final metadata = SettableMetadata(
      contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}',
    );

    await ref.putData(bytes, metadata);
    final url = await ref.getDownloadURL();
    LogService.instance.info(
      'Image uploaded: $folder/$storageName (${formatBytes(bytes.length)})',
    );
    return url;
  }

  /// Delete an image from Firebase Storage by its download URL.
  Future<void> deleteImage(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      LogService.instance.info('Image deleted: ${ref.fullPath}');
    } catch (_) {
      // Image may have already been deleted or URL is external
    }
  }

  /// Pick any file from the system file picker. Returns the picked file
  /// (with bytes loaded) or null when the user cancels.
  ///
  /// Used for arbitrary attachments (PDFs, documents, archives, etc.) —
  /// distinct from [pickImage] which goes through the image gallery.
  Future<fp.PlatformFile?> pickAnyFile() async {
    final result = await fp.FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    if (picked.bytes == null) return null;
    return picked;
  }

  /// Upload arbitrary bytes (not necessarily an image) to Firebase
  /// Storage under `users/{userId}/{folder}/`, return a [FileUpload]
  /// with the download URL plus the metadata callers need to display the
  /// attachment in the UI without re-fetching anything.
  ///
  /// Throws [StorageLimitExceededException] if the upload would exceed
  /// the user's remaining quota.
  Future<FileUpload> uploadFileBytes(
    Uint8List bytes, {
    required String fileName,
    String? contentType,
    String folder = 'files',
  }) async {
    await FirebaseAuth.instance.currentUser?.getIdToken(true);

    final ext = fileName.contains('.') ? fileName.split('.').last : '';
    final storageName = ext.isEmpty
        ? const Uuid().v4()
        : '${const Uuid().v4()}.$ext';
    final ref = _storage.ref('users/$userId/$folder/$storageName');

    if (storageLimitBytes > 0 &&
        storageUsedBytes + bytes.length > storageLimitBytes) {
      throw StorageLimitExceededException(
        bytes.length,
        storageUsedBytes,
        storageLimitBytes,
      );
    }

    final effectiveType = contentType ?? _guessContentType(ext);
    final metadata = SettableMetadata(contentType: effectiveType);
    await ref.putData(bytes, metadata);
    final url = await ref.getDownloadURL();
    LogService.instance.info(
      'File uploaded: $folder/$storageName (${formatBytes(bytes.length)}, $effectiveType)',
    );
    return FileUpload(
      url: url,
      fileName: fileName,
      contentType: effectiveType,
      sizeBytes: bytes.length,
    );
  }

  /// Delete an arbitrary file from Firebase Storage by its download URL.
  /// Same idempotent behaviour as [deleteImage] — silently ignores
  /// already-gone files and external URLs.
  Future<void> deleteFile(String downloadUrl) => deleteImage(downloadUrl);

  String _guessContentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'txt':
      case 'md':
        return 'text/plain';
      case 'html':
        return 'text/html';
      case 'json':
        return 'application/json';
      case 'zip':
        return 'application/zip';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'csv':
        return 'text/csv';
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
        return 'image/${ext == 'jpg' ? 'jpeg' : ext}';
      default:
        return 'application/octet-stream';
    }
  }
}

/// Tiny single-shot completer used by [ImageUploadService.readImageFromClipboard]
/// to bridge super_clipboard's callback-style file read into an async result.
class _ClipboardCompleter {
  Uint8List? _value;
  Object? _error;
  bool _done = false;
  final List<void Function()> _listeners = [];

  void complete(Uint8List? bytes) {
    if (_done) return;
    _done = true;
    _value = bytes;
    for (final cb in _listeners) {
      cb();
    }
  }

  void completeError(Object error) {
    if (_done) return;
    _done = true;
    _error = error;
    for (final cb in _listeners) {
      cb();
    }
  }

  Future<Uint8List?> get future {
    if (_done) {
      if (_error != null) return Future.error(_error!);
      return Future.value(_value);
    }
    final completer = Completer<Uint8List?>();
    _listeners.add(() {
      if (_error != null) {
        completer.completeError(_error!);
      } else {
        completer.complete(_value);
      }
    });
    return completer.future;
  }
}

/// Result of a generic [ImageUploadService.uploadFileBytes] call —
/// contains everything the UI needs to display the attachment without a
/// second fetch.
class FileUpload {
  final String url;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  const FileUpload({
    required this.url,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
  });
}
