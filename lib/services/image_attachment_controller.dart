import 'package:flutter/foundation.dart';

import 'image_upload_service.dart';

typedef PendingImage = ({Uint8List bytes, String fileName});

/// Shared image-attachment choreography for edit pages (IMPR-0019).
///
/// Tracks three buckets that every image-carrying edit page needs:
/// - [savedUrls]: URLs already persisted on the entity (or added by URL),
/// - [pendingImages]: picked/pasted/captured bytes not yet uploaded,
/// - [removedUrls]: previously saved URLs the user removed this session,
///   deleted from Storage only on save so an abandoned edit loses nothing.
///
/// Index space across the UI strip is saved images first, then pending.
/// On save, call [uploadPending] before building the entity (so [savedUrls]
/// is complete) and [deleteRemoved] after the entity write succeeds.
class ImageAttachmentController extends ChangeNotifier {
  ImageAttachmentController({required this.folder});

  /// Storage folder uploads go into (e.g. 'recipes', 'inventory').
  final String folder;

  final List<String> _savedUrls = [];
  final List<PendingImage> _pending = [];
  final List<String> _removedUrls = [];
  int _primaryIndex = 0;

  List<String> get savedUrls => List.unmodifiable(_savedUrls);
  List<PendingImage> get pendingImages => List.unmodifiable(_pending);
  List<String> get removedUrls => List.unmodifiable(_removedUrls);

  /// Index of the primary image in the combined saved+pending space.
  /// Only meaningful for entities that track one (recipes).
  int get primaryIndex => _primaryIndex;

  int get totalCount => _savedUrls.length + _pending.length;
  bool get isEmpty => totalCount == 0;
  bool get isNotEmpty => totalCount > 0;

  /// Stable signature of the image state for unsaved-changes snapshots
  /// (WISH-0079): changes whenever a save would persist something different.
  String get dirtySignature =>
      '${_savedUrls.join(',')}|${_pending.length}|$_primaryIndex';

  /// Loads the persisted state of an existing entity, resetting any
  /// in-session edits.
  void seed(List<String> urls, {int primaryIndex = 0}) {
    _savedUrls
      ..clear()
      ..addAll(urls);
    _pending.clear();
    _removedUrls.clear();
    _primaryIndex = primaryIndex;
    notifyListeners();
  }

  void addPending(Uint8List bytes, String fileName) {
    _pending.add((bytes: bytes, fileName: fileName));
    notifyListeners();
  }

  /// Adds an externally hosted URL directly to the saved list (recipes'
  /// "Enter URL" option). Never uploaded or deleted from Storage by this
  /// controller.
  void addSavedUrl(String url) {
    _savedUrls.add(url);
    notifyListeners();
  }

  void setPrimary(int index) {
    if (index < 0 || index >= totalCount) return;
    _primaryIndex = index;
    notifyListeners();
  }

  /// Removes the image at [index] in the combined saved+pending space.
  /// Saved URLs are queued for Storage deletion on save; pending images
  /// are simply dropped. The primary index keeps pointing at the same
  /// image when one before it is removed, and clamps when it falls off
  /// the end.
  void removeAt(int index) {
    if (index < 0 || index >= totalCount) return;
    if (index < _savedUrls.length) {
      _removedUrls.add(_savedUrls.removeAt(index));
    } else {
      _pending.removeAt(index - _savedUrls.length);
    }
    if (_primaryIndex > index) {
      _primaryIndex--;
    } else if (_primaryIndex >= totalCount) {
      _primaryIndex = totalCount <= 0 ? 0 : totalCount - 1;
    }
    notifyListeners();
  }

  /// Uploads every pending image to Storage under [folder] and moves the
  /// resulting URLs to [savedUrls], preserving order.
  Future<void> uploadPending(ImageUploadService uploader) async {
    if (_pending.isEmpty) return;
    for (final pending in _pending) {
      final url = await uploader.uploadImageBytes(
        pending.bytes,
        fileName: pending.fileName,
        folder: folder,
      );
      _savedUrls.add(url);
    }
    _pending.clear();
    notifyListeners();
  }

  /// Deletes removed URLs from Storage. Pass [deletable] to restrict which
  /// of [removedUrls] are actually deleted (e.g. inventory's shared-image
  /// guard, WISH-0088); the rest are dropped without deletion either way.
  Future<void> deleteRemoved(
    ImageUploadService uploader, {
    List<String>? deletable,
  }) async {
    if (_removedUrls.isEmpty) return;
    for (final url in deletable ?? _removedUrls) {
      await uploader.deleteImage(url);
    }
    _removedUrls.clear();
    notifyListeners();
  }
}
