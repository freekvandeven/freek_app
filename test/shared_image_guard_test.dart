import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/inventory/models/inventory_item.dart';
import 'package:personal_app/features/inventory/utils/shared_image_guard.dart';

void main() {
  InventoryItem item(String id, {List<String> images = const []}) =>
      InventoryItem(id: id, name: id, imageUrls: images);

  group('imageUrlsSafeToDelete (WISH-0088)', () {
    test('deletes URLs no other item references', () {
      final items = [
        item('a', images: ['url1', 'url2']),
        item('b'),
      ];
      expect(
        imageUrlsSafeToDelete(
          allItems: items,
          excludeItemId: 'a',
          candidateUrls: ['url1', 'url2'],
        ),
        ['url1', 'url2'],
      );
    });

    test('keeps URLs a sibling copy still references', () {
      final items = [
        item('a', images: ['shared', 'own']),
        item('b', images: ['shared']),
      ];
      expect(
        imageUrlsSafeToDelete(
          allItems: items,
          excludeItemId: 'a',
          candidateUrls: ['shared', 'own'],
        ),
        ['own'],
      );
    });

    test('the excluded item itself does not protect its own URLs', () {
      final items = [
        item('a', images: ['url1']),
      ];
      expect(
        imageUrlsSafeToDelete(
          allItems: items,
          excludeItemId: 'a',
          candidateUrls: ['url1'],
        ),
        ['url1'],
      );
    });

    test('null excludeItemId (new unsaved item) checks every item', () {
      final items = [
        item('a', images: ['shared']),
      ];
      expect(
        imageUrlsSafeToDelete(
          allItems: items,
          excludeItemId: null,
          candidateUrls: ['shared', 'unreferenced'],
        ),
        ['unreferenced'],
      );
    });

    test('empty candidates yield empty result', () {
      expect(
        imageUrlsSafeToDelete(
          allItems: [
            item('a', images: ['x']),
          ],
          excludeItemId: 'a',
          candidateUrls: const [],
        ),
        isEmpty,
      );
    });
  });
}
