import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/services/image_attachment_controller.dart';
import 'package:personal_app/services/image_upload_service.dart';

class _FakeUploader implements ImageUploadService {
  final uploads = <({String fileName, String folder})>[];
  final deleted = <String>[];
  int _n = 0;

  @override
  Future<String> uploadImageBytes(
    Uint8List bytes, {
    String fileName = 'image.jpg',
    String folder = 'images',
  }) async {
    uploads.add((fileName: fileName, folder: folder));
    return 'https://storage/$folder/${_n++}_$fileName';
  }

  @override
  Future<void> deleteImage(String downloadUrl) async {
    deleted.add(downloadUrl);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Uint8List _bytes() => Uint8List.fromList([1, 2, 3]);

void main() {
  group('ImageAttachmentController (IMPR-0019)', () {
    test('seed loads saved URLs and resets in-session state', () {
      final c = ImageAttachmentController(folder: 'test')
        ..addPending(_bytes(), 'a.jpg')
        ..seed(['u1', 'u2'], primaryIndex: 1);

      expect(c.savedUrls, ['u1', 'u2']);
      expect(c.pendingImages, isEmpty);
      expect(c.removedUrls, isEmpty);
      expect(c.primaryIndex, 1);
      expect(c.totalCount, 2);
      expect(c.isNotEmpty, isTrue);
    });

    test('removeAt on a saved URL queues it for deletion', () {
      final c = ImageAttachmentController(folder: 'test')
        ..seed(['u1', 'u2'])
        ..removeAt(0);

      expect(c.savedUrls, ['u2']);
      expect(c.removedUrls, ['u1']);
    });

    test('removeAt on a pending image drops it without queuing', () {
      final c = ImageAttachmentController(folder: 'test')
        ..seed(['u1'])
        ..addPending(_bytes(), 'a.jpg')
        ..removeAt(1);

      expect(c.savedUrls, ['u1']);
      expect(c.pendingImages, isEmpty);
      expect(c.removedUrls, isEmpty);
    });

    test('removeAt ignores out-of-range indexes', () {
      final c = ImageAttachmentController(folder: 'test')
        ..seed(['u1'])
        ..removeAt(-1)
        ..removeAt(5);

      expect(c.savedUrls, ['u1']);
      expect(c.removedUrls, isEmpty);
    });

    test('primary index follows its image when an earlier one is removed', () {
      final c = ImageAttachmentController(folder: 'test')
        ..seed(['u1', 'u2', 'u3'], primaryIndex: 2)
        ..removeAt(0);

      expect(c.primaryIndex, 1);
      expect(c.savedUrls[c.primaryIndex], 'u3');
    });

    test('primary index clamps when the last image is removed', () {
      final c = ImageAttachmentController(folder: 'test')
        ..seed(['u1', 'u2'], primaryIndex: 1)
        ..removeAt(1);

      expect(c.primaryIndex, 0);

      c.removeAt(0);
      expect(c.primaryIndex, 0);
      expect(c.isEmpty, isTrue);
    });

    test('setPrimary ignores out-of-range indexes', () {
      final c = ImageAttachmentController(folder: 'test')
        ..seed(['u1', 'u2'])
        ..setPrimary(5);
      expect(c.primaryIndex, 0);

      c.setPrimary(1);
      expect(c.primaryIndex, 1);
    });

    test('dirtySignature changes on add, remove, and set-primary', () {
      final c = ImageAttachmentController(folder: 'test')..seed(['u1', 'u2']);
      final initial = c.dirtySignature;

      c.addPending(_bytes(), 'a.jpg');
      final afterAdd = c.dirtySignature;
      expect(afterAdd, isNot(initial));

      c.setPrimary(1);
      final afterPrimary = c.dirtySignature;
      expect(afterPrimary, isNot(afterAdd));

      c.removeAt(0);
      expect(c.dirtySignature, isNot(afterPrimary));
    });

    test('uploadPending uploads to the folder in order and moves URLs to '
        'saved', () async {
      final uploader = _FakeUploader();
      final c = ImageAttachmentController(folder: 'recipes')
        ..seed(['existing'])
        ..addPending(_bytes(), 'first.jpg')
        ..addPending(_bytes(), 'second.png');

      await c.uploadPending(uploader);

      expect(uploader.uploads.map((u) => u.folder), ['recipes', 'recipes']);
      expect(uploader.uploads.map((u) => u.fileName), [
        'first.jpg',
        'second.png',
      ]);
      expect(c.pendingImages, isEmpty);
      expect(c.savedUrls, [
        'existing',
        'https://storage/recipes/0_first.jpg',
        'https://storage/recipes/1_second.png',
      ]);
    });

    test(
      'deleteRemoved deletes every queued URL and clears the queue',
      () async {
        final uploader = _FakeUploader();
        final c = ImageAttachmentController(folder: 'test')
          ..seed(['u1', 'u2'])
          ..removeAt(0)
          ..removeAt(0);

        await c.deleteRemoved(uploader);

        expect(uploader.deleted, ['u1', 'u2']);
        expect(c.removedUrls, isEmpty);
      },
    );

    test('deleteRemoved with a deletable filter only deletes those but still '
        'clears the queue (shared-image guard, WISH-0088)', () async {
      final uploader = _FakeUploader();
      final c = ImageAttachmentController(folder: 'test')
        ..seed(['shared', 'unshared'])
        ..removeAt(0)
        ..removeAt(0);

      await c.deleteRemoved(uploader, deletable: ['unshared']);

      expect(uploader.deleted, ['unshared']);
      expect(c.removedUrls, isEmpty);
    });

    test('notifies listeners on every mutation', () {
      var notifications = 0;
      final c = ImageAttachmentController(folder: 'test');
      c.addListener(() => notifications++);

      c.seed(['u1']);
      c.addPending(_bytes(), 'a.jpg');
      c.addSavedUrl('u2');
      c.setPrimary(1);
      c.removeAt(0);

      expect(notifications, 5);
    });
  });
}
