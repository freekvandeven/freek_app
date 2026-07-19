import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe.dart';

abstract class RecipeService {
  Future<List<Recipe>> getRecipes();

  /// Emits the full recipe list on listen and again after every change
  /// (IMPR-0018).
  Stream<List<Recipe>> watchRecipes();
  Future<Recipe> createRecipe(Recipe recipe);
  Future<Recipe> updateRecipe(Recipe recipe);
  Future<void> deleteRecipe(String id);
  Future<Recipe?> getRecipe(String id);
  Future<List<String>> getAvailableTags();
  Future<void> saveAvailableTags(List<String> tags);
}

class MockRecipeService implements RecipeService {
  final SharedPreferencesAsync _prefs;
  static const _key = 'mock_recipes';
  final _changes = StreamController<List<Recipe>>.broadcast();

  MockRecipeService(this._prefs);

  @override
  Future<List<Recipe>> getRecipes() async {
    final json = await _prefs.getString(_key);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => Recipe.fromMap(e as Map<String, dynamic>)).toList();
  }

  @override
  Stream<List<Recipe>> watchRecipes() async* {
    yield await getRecipes();
    yield* _changes.stream;
  }

  @override
  Future<Recipe> createRecipe(Recipe recipe) async {
    final recipes = await getRecipes();
    recipes.add(recipe);
    await _save(recipes);
    return recipe;
  }

  @override
  Future<Recipe> updateRecipe(Recipe recipe) async {
    final recipes = await getRecipes();
    final index = recipes.indexWhere((r) => r.id == recipe.id);
    if (index == -1) throw Exception('Recipe not found');
    recipes[index] = recipe;
    await _save(recipes);
    return recipe;
  }

  @override
  Future<void> deleteRecipe(String id) async {
    final recipes = await getRecipes();
    recipes.removeWhere((r) => r.id == id);
    await _save(recipes);
  }

  @override
  Future<Recipe?> getRecipe(String id) async {
    final recipes = await getRecipes();
    return recipes.where((r) => r.id == id).firstOrNull;
  }

  Future<void> _save(List<Recipe> recipes) async {
    await _prefs.setString(
      _key,
      jsonEncode(recipes.map((r) => r.toMap()).toList()),
    );
    _changes.add(List.of(recipes));
  }

  void dispose() {
    _changes.close();
  }

  static const _tagsKey = 'mock_recipe_tags';

  @override
  Future<List<String>> getAvailableTags() async {
    final json = await _prefs.getString(_tagsKey);
    if (json == null) return [];
    return (jsonDecode(json) as List).cast<String>();
  }

  @override
  Future<void> saveAvailableTags(List<String> tags) async {
    await _prefs.setString(_tagsKey, jsonEncode(tags));
  }
}
