import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/recipes/models/recipe.dart';
import 'package:personal_app/features/recipes/widgets/recipe_ingredients_section.dart';
import 'package:personal_app/features/recipes/widgets/recipe_instructions_section.dart';

void main() {
  group('RecipeIngredientsSection (BUG-0048)', () {
    const ingredients = [
      Ingredient(name: 'Flour', quantity: 200, unit: 'g'),
      Ingredient(name: 'Salt'),
    ];

    testWidgets('tapping a row calls onEdit with its index, not onRemove', (
      tester,
    ) async {
      int? editedIndex;
      int? removedIndex;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecipeIngredientsSection(
              ingredients: ingredients,
              onAdd: () {},
              onEdit: (i) => editedIndex = i,
              onRemove: (i) => removedIndex = i,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Salt'));
      await tester.pump();

      expect(editedIndex, 1);
      expect(removedIndex, isNull);
    });

    testWidgets('the trailing remove button calls onRemove, not onEdit', (
      tester,
    ) async {
      int? editedIndex;
      int? removedIndex;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecipeIngredientsSection(
              ingredients: ingredients,
              onAdd: () {},
              onEdit: (i) => editedIndex = i,
              onRemove: (i) => removedIndex = i,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
      await tester.pump();

      expect(removedIndex, 0);
      expect(editedIndex, isNull);
    });
  });

  group('RecipeInstructionsSection (BUG-0048)', () {
    const instructions = [
      RecipeInstruction(text: 'Mix dry ingredients'),
      RecipeInstruction(text: 'Add wet ingredients'),
    ];

    testWidgets('tapping a step calls onEdit with its index, not onRemove', (
      tester,
    ) async {
      int? editedIndex;
      int? removedIndex;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecipeInstructionsSection(
              instructions: instructions,
              onAdd: () {},
              onEdit: (i) => editedIndex = i,
              onRemove: (i) => removedIndex = i,
              onReorder: (_, _) {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add wet ingredients'));
      await tester.pump();

      expect(editedIndex, 1);
      expect(removedIndex, isNull);
    });

    testWidgets('the trailing remove button calls onRemove, not onEdit', (
      tester,
    ) async {
      int? editedIndex;
      int? removedIndex;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecipeInstructionsSection(
              instructions: instructions,
              onAdd: () {},
              onEdit: (i) => editedIndex = i,
              onRemove: (i) => removedIndex = i,
              onReorder: (_, _) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
      await tester.pump();

      expect(removedIndex, 0);
      expect(editedIndex, isNull);
    });
  });
}
