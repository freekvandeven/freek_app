import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/recipe.dart';
import '../services/firestore_recipe_service.dart';
import '../services/recipe_service.dart';

final recipeServiceProvider = Provider<RecipeService>((ref) {
  if (AppConfig.useFirebase) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return FirestoreRecipeService(userId);
  }
  return MockRecipeService(SharedPreferencesAsync());
});

final recipeListProvider =
    AsyncNotifierProvider<RecipeListNotifier, List<Recipe>>(
      RecipeListNotifier.new,
    );

class RecipeListNotifier extends AsyncNotifier<List<Recipe>> {
  RecipeService get _service => ref.read(recipeServiceProvider);

  @override
  Future<List<Recipe>> build() {
    return ref.watch(recipeServiceProvider).getRecipes();
  }

  Future<void> addRecipe(Recipe recipe) async {
    await _service.createRecipe(recipe);
    ref.invalidateSelf();
  }

  Future<void> updateRecipe(Recipe recipe) async {
    await _service.updateRecipe(recipe);
    ref.invalidateSelf();
  }

  Future<void> deleteRecipe(String id) async {
    await _service.deleteRecipe(id);
    ref.invalidateSelf();
  }

  Future<void> toggleFavorite(Recipe recipe) async {
    await _service.updateRecipe(
      recipe.copyWith(isFavorite: !recipe.isFavorite),
    );
    ref.invalidateSelf();
  }
}

final recipeSearchProvider = StateProvider<String>((ref) => '');
final recipeTagFilterProvider = StateProvider<String?>((ref) => null);
final recipeFavoritesOnlyProvider = StateProvider<bool>((ref) => false);

final filteredRecipesProvider = Provider<AsyncValue<List<Recipe>>>((ref) {
  final recipesAsync = ref.watch(recipeListProvider);
  final search = ref.watch(recipeSearchProvider).toLowerCase();
  final tag = ref.watch(recipeTagFilterProvider);
  final favOnly = ref.watch(recipeFavoritesOnlyProvider);

  return recipesAsync.whenData((recipes) {
    var filtered = recipes.toList();
    if (search.isNotEmpty) {
      filtered = filtered
          .where((r) => r.title.toLowerCase().contains(search))
          .toList();
    }
    if (tag != null) {
      filtered = filtered.where((r) => r.tags.contains(tag)).toList();
    }
    if (favOnly) {
      filtered = filtered.where((r) => r.isFavorite).toList();
    }
    filtered.sort((a, b) => a.title.compareTo(b.title));
    return filtered;
  });
});

final recipeTagsProvider = Provider<List<String>>((ref) {
  final recipes = ref.watch(recipeListProvider).valueOrNull ?? [];
  final tags = recipes.expand((r) => r.tags).toSet().toList();
  tags.sort();
  return tags;
});
