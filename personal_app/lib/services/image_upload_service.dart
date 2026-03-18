import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../features/auth/providers/auth_providers.dart';

final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  final user = ref.watch(currentUserProvider);
  return ImageUploadService(userId: user?.id ?? 'anonymous');
});

class ImageUploadService {
  final String userId;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  ImageUploadService({required this.userId});

  /// Pick an image from gallery and upload it. Returns the download URL.
  Future<String?> pickAndUploadImage({String folder = 'images'}) async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (file == null) return null;
    return uploadXFile(file, folder: folder);
  }

  /// Pick an image from camera and upload it. Returns the download URL.
  Future<String?> captureAndUploadImage({String folder = 'images'}) async {
    if (kIsWeb) return null; // Camera not supported on web
    final XFile? file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (file == null) return null;
    return uploadXFile(file, folder: folder);
  }

  /// Upload an XFile to Firebase Storage and return the download URL.
  Future<String> uploadXFile(XFile file, {String folder = 'images'}) async {
    // Force-refresh the ID token so the inviteVerified claim is present.
    await FirebaseAuth.instance.currentUser?.getIdToken(true);

    final ext = file.name.split('.').last;
    final fileName = '${const Uuid().v4()}.$ext';
    final ref = _storage.ref('users/$userId/$folder/$fileName');

    final Uint8List bytes = await file.readAsBytes();
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
