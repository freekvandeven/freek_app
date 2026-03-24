import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../features/auth/providers/auth_providers.dart';

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
    return ref.getDownloadURL();
  }

  /// Delete an image from Firebase Storage by its download URL.
  Future<void> deleteImage(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (_) {
      // Image may have already been deleted or URL is external
    }
  }
}
