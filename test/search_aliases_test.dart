import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/catalog/models/catalog_item.dart';
import 'package:personal_app/features/inventory/models/inventory_item.dart';
import 'package:personal_app/features/knowledge/models/knowledge_page.dart';
import 'package:personal_app/features/recipes/models/recipe.dart';
import 'package:personal_app/utils/search_aliases.dart';

void main() {
  group('parseSearchAliases', () {
    test('splits on spaces', () {
      expect(parseSearchAliases('soja soy sauce'), ['soja', 'soy', 'sauce']);
    });

    test('splits on commas and periods (WISH-0082)', () {
      expect(parseSearchAliases('soja,soy.sauce'), ['soja', 'soy', 'sauce']);
    });

    test('mixed separators and runs collapse to single splits', () {
      expect(parseSearchAliases('a,, b..c ,. d'), ['a', 'b', 'c', 'd']);
    });

    test('lowercases every word', () {
      expect(parseSearchAliases('Soja SOY'), ['soja', 'soy']);
    });

    test('null / empty / whitespace-only input gives empty list', () {
      expect(parseSearchAliases(null), isEmpty);
      expect(parseSearchAliases(''), isEmpty);
      expect(parseSearchAliases('   '), isEmpty);
    });
  });

  group('matchesSearchAliases', () {
    test('matches a full alias word', () {
      expect(matchesSearchAliases('soja, ketjap', 'soja'), isTrue);
    });

    test('matches a partial prefix while typing', () {
      expect(matchesSearchAliases('soja, ketjap', 'soj'), isTrue);
      expect(matchesSearchAliases('soja, ketjap', 'ket'), isTrue);
    });

    test('is case-insensitive both ways', () {
      expect(matchesSearchAliases('Soja', 'SOJ'), isTrue);
    });

    test('no match when query is absent from all words', () {
      expect(matchesSearchAliases('soja, ketjap', 'mayo'), isFalse);
    });

    test('null aliases or empty query never match', () {
      expect(matchesSearchAliases(null, 'x'), isFalse);
      expect(matchesSearchAliases('soja', ''), isFalse);
      expect(matchesSearchAliases('soja', '  '), isFalse);
    });
  });

  group('searchAliases model roundtrips (WISH-0082)', () {
    test('InventoryItem', () {
      final item = InventoryItem(name: 'Soy sauce', searchAliases: 'soja');
      expect(InventoryItem.fromMap(item.toMap()).searchAliases, 'soja');
      final legacy = InventoryItem(name: 'old').toMap()
        ..remove('searchAliases');
      expect(InventoryItem.fromMap(legacy).searchAliases, isNull);
      expect(item.copyWith(clearSearchAliases: true).searchAliases, isNull);
    });

    test('CatalogItem', () {
      final item = CatalogItem(title: 'TV', searchAliases: 'telly, screen');
      expect(CatalogItem.fromMap(item.toMap()).searchAliases, 'telly, screen');
      final legacy = CatalogItem(title: 'old').toMap()..remove('searchAliases');
      expect(CatalogItem.fromMap(legacy).searchAliases, isNull);
      expect(item.copyWith(clearSearchAliases: true).searchAliases, isNull);
    });

    test('Recipe', () {
      final recipe = Recipe(title: 'Pasta', searchAliases: 'noodles');
      expect(Recipe.fromMap(recipe.toMap()).searchAliases, 'noodles');
      final legacy = Recipe(title: 'old').toMap()..remove('searchAliases');
      expect(Recipe.fromMap(legacy).searchAliases, isNull);
      expect(recipe.copyWith(clearSearchAliases: true).searchAliases, isNull);
    });

    test('KnowledgePage', () {
      final page = KnowledgePage(
        title: 'Router setup',
        content: 'x',
        searchAliases: 'wifi.network',
      );
      expect(KnowledgePage.fromMap(page.toMap()).searchAliases, 'wifi.network');
      final legacy = KnowledgePage(title: 'old', content: 'x').toMap()
        ..remove('searchAliases');
      expect(KnowledgePage.fromMap(legacy).searchAliases, isNull);
      expect(page.copyWith(searchAliases: () => null).searchAliases, isNull);
    });
  });
}
