import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/recipe.dart';
import 'recipe_service.dart';

class FirestoreRecipeService implements RecipeService {
  final FirebaseFirestore _firestore;
  final String _userId;

  FirestoreRecipeService(this._userId, {FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_userId).collection('recipes');

  @override
  Future<List<Recipe>> getRecipes() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map((doc) => Recipe.fromMap(doc.data())).toList();
  }

  @override
  Stream<List<Recipe>> watchRecipes() {
    return _collection.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => Recipe.fromMap(doc.data())).toList(),
    );
  }

  @override
  Future<Recipe> createRecipe(Recipe recipe) async {
    await _collection.doc(recipe.id).set(recipe.toMap());
    return recipe;
  }

  @override
  Future<Recipe> updateRecipe(Recipe recipe) async {
    await _collection.doc(recipe.id).set(recipe.toMap());
    return recipe;
  }

  @override
  Future<void> deleteRecipe(String id) async {
    await _collection.doc(id).delete();
  }

  @override
  Future<Recipe?> getRecipe(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Recipe.fromMap(doc.data()!);
  }

  DocumentReference<Map<String, dynamic>> get _tagsDoc => _firestore
      .collection('users')
      .doc(_userId)
      .collection('meta')
      .doc('recipeTags');

  @override
  Future<List<String>> getAvailableTags() async {
    final doc = await _tagsDoc.get();
    if (!doc.exists || doc.data() == null) return [];
    return (doc.data()!['tags'] as List?)?.cast<String>() ?? [];
  }

  @override
  Future<void> saveAvailableTags(List<String> tags) async {
    await _tagsDoc.set({'tags': tags});
  }
}
