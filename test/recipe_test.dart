import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/recipes/models/recipe.dart';

void main() {
  group('Ingredient', () {
    test('toMap and fromMap round-trip', () {
      const ingredient = Ingredient(name: 'Flour', quantity: 250, unit: 'g');
      final map = ingredient.toMap();
      final restored = Ingredient.fromMap(map);

      expect(restored.name, 'Flour');
      expect(restored.quantity, 250);
      expect(restored.unit, 'g');
    });

    test('handles null quantity and unit', () {
      const ingredient = Ingredient(name: 'Salt');
      final map = ingredient.toMap();
      final restored = Ingredient.fromMap(map);

      expect(restored.name, 'Salt');
      expect(restored.quantity, isNull);
      expect(restored.unit, isNull);
    });
  });

  group('RecipeInstruction', () {
    test('toMap and fromMap round-trip', () {
      const instruction = RecipeInstruction(
        text: 'Mix ingredients',
        imageUrl: 'https://example.com/step1.jpg',
      );
      final map = instruction.toMap();
      final restored = RecipeInstruction.fromMap(map);

      expect(restored.text, 'Mix ingredients');
      expect(restored.imageUrl, 'https://example.com/step1.jpg');
    });

    test('fromString creates instruction from legacy string', () {
      final instruction = RecipeInstruction.fromString('Preheat oven to 180°C');
      expect(instruction.text, 'Preheat oven to 180°C');
      expect(instruction.imageUrl, isNull);
    });
  });

  group('Recipe', () {
    final now = DateTime(2025, 6, 1, 12, 0);

    Recipe createRecipe() => Recipe(
      id: 'recipe-001',
      title: 'Pancakes',
      description: 'Fluffy pancakes',
      servings: 4,
      prepTimeMinutes: 10,
      cookTimeMinutes: 15,
      ingredients: const [
        Ingredient(name: 'Flour', quantity: 200, unit: 'g'),
        Ingredient(name: 'Eggs', quantity: 2),
      ],
      instructions: const [
        RecipeInstruction(text: 'Mix dry ingredients'),
        RecipeInstruction(text: 'Add wet ingredients'),
      ],
      tags: ['breakfast', 'easy'],
      images: ['https://example.com/pancakes.jpg'],
      videoLinks: ['https://youtu.be/dQw4w9WgXcQ'],
      isFavorite: true,
      source: 'Grandma',
      notes: 'Best served warm',
      createdAt: now,
      updatedAt: now,
    );

    test('toMap and fromMap round-trip', () {
      final recipe = createRecipe();
      final map = recipe.toMap();
      final restored = Recipe.fromMap(map);

      expect(restored.id, 'recipe-001');
      expect(restored.title, 'Pancakes');
      expect(restored.description, 'Fluffy pancakes');
      expect(restored.servings, 4);
      expect(restored.prepTimeMinutes, 10);
      expect(restored.cookTimeMinutes, 15);
      expect(restored.ingredients.length, 2);
      expect(restored.ingredients[0].name, 'Flour');
      expect(restored.instructions.length, 2);
      expect(restored.instructions[0].text, 'Mix dry ingredients');
      expect(restored.images, ['https://example.com/pancakes.jpg']);
      expect(restored.videoLinks, ['https://youtu.be/dQw4w9WgXcQ']);
      expect(restored.isFavorite, isTrue);
      expect(restored.createdAt, now);
    });

    test('fromMap handles legacy string instructions', () {
      final map = {
        'id': 'r1',
        'title': 'Old Recipe',
        'instructions': ['Step 1', 'Step 2'],
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      final recipe = Recipe.fromMap(map);
      expect(recipe.instructions.length, 2);
      expect(recipe.instructions[0].text, 'Step 1');
      expect(recipe.instructions[0].imageUrl, isNull);
    });

    test('fromMap handles legacy imageUrl field', () {
      final map = {
        'id': 'r2',
        'title': 'Legacy Recipe',
        'imageUrl': 'https://example.com/old.jpg',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      final recipe = Recipe.fromMap(map);
      expect(recipe.images, ['https://example.com/old.jpg']);
    });

    test('fromMap defaults for missing optional fields', () {
      final recipe = Recipe.fromMap({
        'id': 'r3',
        'title': 'Minimal',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
      expect(recipe.ingredients, isEmpty);
      expect(recipe.instructions, isEmpty);
      expect(recipe.images, isEmpty);
      expect(recipe.videoLinks, isEmpty);
      expect(recipe.isFavorite, isFalse);
    });

    test('primaryImageUrl returns first image when available', () {
      final recipe = createRecipe();
      expect(recipe.primaryImageUrl, 'https://example.com/pancakes.jpg');
    });

    test('primaryImageUrl returns null when no images', () {
      final recipe = Recipe(title: 'No images', createdAt: now, updatedAt: now);
      expect(recipe.primaryImageUrl, isNull);
    });

    test('totalTimeMinutes sums prep and cook time', () {
      final recipe = createRecipe();
      expect(recipe.totalTimeMinutes, 25);
    });

    test('totalTimeMinutes returns null when both are null', () {
      final recipe = Recipe(title: 'Quick', createdAt: now, updatedAt: now);
      expect(recipe.totalTimeMinutes, isNull);
    });

    test('totalTimeMinutes handles partial times', () {
      final recipe = Recipe(
        title: 'Prep only',
        prepTimeMinutes: 10,
        createdAt: now,
        updatedAt: now,
      );
      expect(recipe.totalTimeMinutes, 10);
    });

    test('auto-generates id when not provided', () {
      final recipe = Recipe(title: 'Auto ID');
      expect(recipe.id, isNotEmpty);
    });

    test('copyWith replaces fields', () {
      final recipe = createRecipe();
      final updated = recipe.copyWith(title: 'Waffles', isFavorite: false);
      expect(updated.title, 'Waffles');
      expect(updated.isFavorite, isFalse);
      expect(updated.id, 'recipe-001'); // unchanged
      expect(updated.servings, 4); // unchanged
    });

    test('copyWith clearDescription sets null', () {
      final recipe = createRecipe();
      final updated = recipe.copyWith(clearDescription: true);
      expect(updated.description, isNull);
    });

    test('rating defaults to null (WISH-0080)', () {
      final recipe = Recipe(title: 'Unrated');
      expect(recipe.rating, isNull);
    });

    test('rating roundtrips through toMap/fromMap including half-stars', () {
      final recipe = Recipe(title: 'r', rating: 4.5);
      final copy = Recipe.fromMap(recipe.toMap());
      expect(copy.rating, 4.5);
    });

    test('fromMap tolerates legacy records without rating', () {
      final legacy = Recipe(title: 'legacy').toMap()..remove('rating');
      expect(Recipe.fromMap(legacy).rating, isNull);
    });

    test('copyWith updates rating; clearRating resets to null', () {
      final recipe = Recipe(title: 'r', rating: 3);
      expect(recipe.copyWith(rating: 5).rating, 5);
      expect(recipe.copyWith(clearRating: true).rating, isNull);
    });

    test('hasBeenMade defaults to false (WISH-0091)', () {
      final recipe = Recipe(title: 'Untried');
      expect(recipe.hasBeenMade, isFalse);
    });

    test('hasBeenMade roundtrips through toMap/fromMap', () {
      final recipe = Recipe(title: 'r', hasBeenMade: true);
      final copy = Recipe.fromMap(recipe.toMap());
      expect(copy.hasBeenMade, isTrue);
    });

    test('fromMap tolerates legacy records without hasBeenMade', () {
      final legacy = Recipe(title: 'legacy').toMap()..remove('hasBeenMade');
      expect(Recipe.fromMap(legacy).hasBeenMade, isFalse);
    });

    test('copyWith updates hasBeenMade independently of other fields', () {
      final recipe = Recipe(title: 'r', isFavorite: true, rating: 4);
      final updated = recipe.copyWith(hasBeenMade: true);
      expect(updated.hasBeenMade, isTrue);
      expect(updated.isFavorite, isTrue);
      expect(updated.rating, 4);
    });
  });
}
