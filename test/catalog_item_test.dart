import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/catalog/models/catalog_item.dart';

void main() {
  group('CatalogItem.rating (WISH-0080)', () {
    test('defaults to null', () {
      final item = CatalogItem(title: 'Phone');
      expect(item.rating, isNull);
    });

    test('roundtrips through toMap/fromMap including half-stars', () {
      final item = CatalogItem(title: 'Phone', rating: 4.5);
      final copy = CatalogItem.fromMap(item.toMap());
      expect(copy.rating, 4.5);
    });

    test('fromMap tolerates legacy records without rating', () {
      final legacy = CatalogItem(title: 'old').toMap()..remove('rating');
      expect(CatalogItem.fromMap(legacy).rating, isNull);
    });

    test('copyWith updates rating', () {
      final item = CatalogItem(title: 'x', rating: 3);
      expect(item.copyWith(rating: 5).rating, 5);
    });

    test('copyWith clearRating resets to null', () {
      final item = CatalogItem(title: 'x', rating: 3);
      expect(item.copyWith(clearRating: true).rating, isNull);
    });
  });
}
