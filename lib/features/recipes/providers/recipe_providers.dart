import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/app_config.dart';
import '../../../services/image_upload_service.dart';
import '../../../services/log_service.dart';
import '../../../utils/search_aliases.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/recipe.dart';
import '../services/firestore_recipe_service.dart';
import '../services/recipe_service.dart';

final recipeServiceProvider = Provider<RecipeService>((ref) {
  if (AppConfig.useFirebase) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return FirestoreRecipeService(userId);
  }
  final service = MockRecipeService(SharedPreferencesAsync());
  ref.onDispose(service.dispose);
  return service;
});

final recipeListProvider =
    StreamNotifierProvider<RecipeListNotifier, List<Recipe>>(
      RecipeListNotifier.new,
    );

class RecipeListNotifier extends StreamNotifier<List<Recipe>> {
  RecipeService get _service => ref.read(recipeServiceProvider);

  @override
  Stream<List<Recipe>> build() {
    return ref.watch(recipeServiceProvider).watchRecipes();
  }

  Future<void> addRecipe(Recipe recipe) async {
    await _service.createRecipe(recipe);
    LogService.instance.info('Recipe created: ${recipe.title}');
  }

  Future<void> updateRecipe(Recipe recipe) async {
    await _service.updateRecipe(recipe);
    LogService.instance.info('Recipe updated: ${recipe.id}');
  }

  Future<void> deleteRecipe(String id) async {
    // Delete associated images from Storage
    final recipe = await _service.getRecipe(id);
    if (recipe != null) {
      final uploader = ref.read(imageUploadServiceProvider);
      for (final url in recipe.images) {
        await uploader.deleteImage(url);
      }
      for (final instruction in recipe.instructions) {
        if (instruction.imageUrl != null) {
          await uploader.deleteImage(instruction.imageUrl!);
        }
      }
    }
    await _service.deleteRecipe(id);
    LogService.instance.info('Recipe deleted: $id');
  }

  Future<void> toggleFavorite(Recipe recipe) async {
    await _service.updateRecipe(
      recipe.copyWith(isFavorite: !recipe.isFavorite),
    );
  }

  Future<void> toggleHasBeenMade(Recipe recipe) async {
    await _service.updateRecipe(
      recipe.copyWith(hasBeenMade: !recipe.hasBeenMade),
    );
  }
}

final recipeSearchProvider = StateProvider<String>((ref) => '');
final recipeTagFilterProvider = StateProvider<String?>((ref) => null);
final recipeFavoritesOnlyProvider = StateProvider<bool>((ref) => false);
final recipeWipOnlyProvider = StateProvider<bool>((ref) => false);
final recipeMadeOnlyProvider = StateProvider<bool>((ref) => false);

final filteredRecipesProvider = Provider<AsyncValue<List<Recipe>>>((ref) {
  final recipesAsync = ref.watch(recipeListProvider);
  final search = ref.watch(recipeSearchProvider).toLowerCase();
  final tag = ref.watch(recipeTagFilterProvider);
  final favOnly = ref.watch(recipeFavoritesOnlyProvider);
  final wipOnly = ref.watch(recipeWipOnlyProvider);
  final madeOnly = ref.watch(recipeMadeOnlyProvider);

  return recipesAsync.whenData((recipes) {
    var filtered = recipes.toList();
    if (search.isNotEmpty) {
      filtered = filtered
          .where(
            (r) =>
                r.title.toLowerCase().contains(search) ||
                matchesSearchAliases(r.searchAliases, search),
          )
          .toList();
    }
    if (tag != null) {
      filtered = filtered.where((r) => r.tags.contains(tag)).toList();
    }
    if (favOnly) {
      filtered = filtered.where((r) => r.isFavorite).toList();
    }
    if (wipOnly) {
      filtered = filtered.where((r) => r.isWip).toList();
    }
    if (madeOnly) {
      filtered = filtered.where((r) => r.hasBeenMade).toList();
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

final availableTagsProvider =
    AsyncNotifierProvider<AvailableTagsNotifier, List<String>>(
      AvailableTagsNotifier.new,
    );

class AvailableTagsNotifier extends AsyncNotifier<List<String>> {
  RecipeService get _service => ref.read(recipeServiceProvider);

  @override
  Future<List<String>> build() async {
    final saved = await _service.getAvailableTags();
    final fromRecipes = ref.watch(recipeTagsProvider);
    final merged = {...saved, ...fromRecipes}.toList()..sort();
    return merged;
  }

  Future<void> addTag(String tag) async {
    final current = state.valueOrNull ?? [];
    if (current.contains(tag)) return;
    final updated = [...current, tag]..sort();
    state = AsyncData(updated);
    await _service.saveAvailableTags(updated);
  }
}
