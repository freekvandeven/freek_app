import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe.dart';

abstract class RecipeService {
  Future<List<Recipe>> getRecipes();
  Future<Recipe> createRecipe(Recipe recipe);
  Future<Recipe> updateRecipe(Recipe recipe);
  Future<void> deleteRecipe(String id);
  Future<Recipe?> getRecipe(String id);
}

class MockRecipeService implements RecipeService {
  final SharedPreferencesAsync _prefs;
  static const _key = 'mock_recipes';

  MockRecipeService(this._prefs);

  @override
  Future<List<Recipe>> getRecipes() async {
    final json = await _prefs.getString(_key);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => Recipe.fromMap(e as Map<String, dynamic>)).toList();
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
  }
}
