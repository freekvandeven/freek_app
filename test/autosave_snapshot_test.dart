import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/knowledge/utils/autosave_snapshot.dart';
import 'package:personal_app/features/recipes/models/recipe.dart';
import 'package:personal_app/features/recipes/utils/autosave_snapshot.dart';

void main() {
  group('knowledgeAutosaveSnapshot', () {
    String snap({
      String title = 'My page',
      String content = 'body',
      List<String> tags = const ['work'],
      String? parentId,
      bool isWip = false,
    }) {
      return knowledgeAutosaveSnapshot(
        title: title,
        content: content,
        tags: tags,
        parentId: parentId,
        isWip: isWip,
      );
    }

    test('identical inputs produce identical snapshots', () {
      expect(snap(), equals(snap()));
    });

    test('title change flips the snapshot', () {
      expect(snap(title: 'A'), isNot(equals(snap(title: 'B'))));
    });

    test('content change flips the snapshot', () {
      expect(snap(content: 'a'), isNot(equals(snap(content: 'b'))));
    });

    test('tag change flips the snapshot', () {
      expect(snap(tags: const ['a']), isNot(equals(snap(tags: const ['b']))));
    });

    test('parentId change flips the snapshot', () {
      expect(snap(parentId: null), isNot(equals(snap(parentId: 'pid'))));
    });

    test('isWip flip flips the snapshot', () {
      expect(snap(isWip: false), isNot(equals(snap(isWip: true))));
    });

    test('leading/trailing title whitespace is normalised away', () {
      // BUG-0033: redundant autosaves came partly from leading/trailing ws
      // wobble. The snapshot should compare equal across that.
      expect(snap(title: '  My page  '), equals(snap(title: 'My page')));
    });
  });

  group('recipeAutosaveSnapshot', () {
    String snap({
      String title = 'Soup',
      String description = '',
      String servings = '4',
      String prepTime = '',
      String cookTime = '',
      String source = '',
      String notes = '',
      List<Ingredient> ingredients = const [],
      List<RecipeInstruction> instructions = const [],
      List<String> tags = const [],
      List<String> savedImageUrls = const [],
      int primaryImageIndex = 0,
      List<String> videoLinks = const [],
      List<String> subRecipeIds = const [],
      bool isWip = false,
    }) {
      return recipeAutosaveSnapshot(
        title: title,
        description: description,
        servings: servings,
        prepTime: prepTime,
        cookTime: cookTime,
        source: source,
        notes: notes,
        ingredients: ingredients,
        instructions: instructions,
        tags: tags,
        savedImageUrls: savedImageUrls,
        primaryImageIndex: primaryImageIndex,
        videoLinks: videoLinks,
        subRecipeIds: subRecipeIds,
        isWip: isWip,
      );
    }

    test('identical inputs produce identical snapshots', () {
      expect(snap(), equals(snap()));
    });

    test('ingredient name change flips the snapshot', () {
      final a = snap(ingredients: [const Ingredient(name: 'onion')]);
      final b = snap(ingredients: [const Ingredient(name: 'garlic')]);
      expect(a, isNot(equals(b)));
    });

    test('ingredient quantity change flips the snapshot', () {
      final a = snap(
        ingredients: [const Ingredient(name: 'flour', quantity: 100)],
      );
      final b = snap(
        ingredients: [const Ingredient(name: 'flour', quantity: 200)],
      );
      expect(a, isNot(equals(b)));
    });

    test('null and 0 quantity produce different snapshots', () {
      final a = snap(ingredients: [const Ingredient(name: 'flour')]);
      final b = snap(
        ingredients: [const Ingredient(name: 'flour', quantity: 0)],
      );
      expect(a, isNot(equals(b)));
    });

    test('instruction text change flips the snapshot', () {
      final a = snap(instructions: [const RecipeInstruction(text: 'Stir')]);
      final b = snap(
        instructions: [const RecipeInstruction(text: 'Stir well')],
      );
      expect(a, isNot(equals(b)));
    });

    test('reordering ingredients flips the snapshot', () {
      final a = snap(
        ingredients: [
          const Ingredient(name: 'onion'),
          const Ingredient(name: 'garlic'),
        ],
      );
      final b = snap(
        ingredients: [
          const Ingredient(name: 'garlic'),
          const Ingredient(name: 'onion'),
        ],
      );
      expect(a, isNot(equals(b)));
    });

    test('primaryImageIndex change flips the snapshot', () {
      expect(
        snap(primaryImageIndex: 0),
        isNot(equals(snap(primaryImageIndex: 1))),
      );
    });

    test('isWip flip flips the snapshot', () {
      expect(snap(isWip: false), isNot(equals(snap(isWip: true))));
    });

    test('source / notes whitespace differences do not flip', () {
      expect(snap(source: '  url  '), equals(snap(source: 'url')));
      expect(snap(notes: '  n  '), equals(snap(notes: 'n')));
    });
  });
}
