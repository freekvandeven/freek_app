import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/recipes/models/recipe.dart';
import 'package:personal_app/features/recipes/pages/recipe_random_page.dart';
import 'package:personal_app/features/recipes/providers/recipe_providers.dart';

class _FakeRecipeListNotifier extends RecipeListNotifier {
  final List<Recipe> recipes;
  _FakeRecipeListNotifier(this.recipes);

  @override
  Stream<List<Recipe>> build() => Stream.value(recipes);
}

Future<void> _pump(WidgetTester tester, List<Recipe> recipes) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        recipeListProvider.overrideWith(() => _FakeRecipeListNotifier(recipes)),
      ],
      child: const MaterialApp(home: RecipeRandomPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('RecipeRandomPage (WISH-0097)', () {
    testWidgets('shows the title, description and image of a picked recipe', (
      tester,
    ) async {
      await _pump(tester, [
        Recipe(
          title: 'Pancakes',
          description: 'Fluffy pancakes',
          images: const ['https://example.com/pancakes.jpg'],
        ),
      ]);

      expect(find.text('Pancakes'), findsOneWidget);
      expect(find.text('Fluffy pancakes'), findsOneWidget);
      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.imageUrl, 'https://example.com/pancakes.jpg');
      expect(find.text('Try Another'), findsOneWidget);
      expect(find.text('Make This'), findsOneWidget);
    });

    testWidgets('excludes WIP recipes from the pool', (tester) async {
      await _pump(tester, [Recipe(title: 'Unfinished soup', isWip: true)]);

      expect(
        find.text('All your recipes are still marked as work-in-progress'),
        findsOneWidget,
      );
      expect(find.text('Unfinished soup'), findsNothing);
    });

    testWidgets('shows an empty state with no recipes at all', (tester) async {
      await _pump(tester, []);

      expect(find.text('No recipes yet'), findsOneWidget);
      expect(find.text('Add a Recipe'), findsOneWidget);
    });

    testWidgets('Try Another is disabled with only one eligible recipe', (
      tester,
    ) async {
      await _pump(tester, [Recipe(title: 'Only Option')]);

      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Try Another'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Try Another always switches to the other recipe when '
        'exactly two are eligible', (tester) async {
      await _pump(tester, [
        Recipe(title: 'Recipe A'),
        Recipe(title: 'Recipe B'),
      ]);

      final firstShown = find.text('Recipe A').evaluate().isNotEmpty
          ? 'Recipe A'
          : 'Recipe B';
      final other = firstShown == 'Recipe A' ? 'Recipe B' : 'Recipe A';

      await tester.tap(find.text('Try Another'));
      await tester.pumpAndSettle();

      expect(find.text(other), findsOneWidget);
      expect(find.text(firstShown), findsNothing);
    });
  });
}
