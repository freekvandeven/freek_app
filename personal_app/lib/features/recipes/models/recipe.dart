import 'package:uuid/uuid.dart';

class Ingredient {
  final String name;
  final double? quantity;
  final String? unit;

  const Ingredient({required this.name, this.quantity, this.unit});

  Map<String, dynamic> toMap() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
  };

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      name: map['name'] as String,
      quantity: (map['quantity'] as num?)?.toDouble(),
      unit: map['unit'] as String?,
    );
  }
}

class RecipeInstruction {
  final String text;
  final String? imageUrl;

  const RecipeInstruction({required this.text, this.imageUrl});

  Map<String, dynamic> toMap() => {
    'text': text,
    'imageUrl': imageUrl,
  };

  factory RecipeInstruction.fromMap(Map<String, dynamic> map) {
    return RecipeInstruction(
      text: map['text'] as String,
      imageUrl: map['imageUrl'] as String?,
    );
  }

  /// Parse from legacy string format for backward compatibility.
  factory RecipeInstruction.fromString(String text) {
    return RecipeInstruction(text: text);
  }
}

class Recipe {
  final String id;
  final String title;
  final String? description;
  final int? servings;
  final int? prepTimeMinutes;
  final int? cookTimeMinutes;
  final List<Ingredient> ingredients;
  final List<RecipeInstruction> instructions;
  final List<String> tags;
  final List<String> images;
  final int primaryImageIndex;
  final bool isFavorite;
  final String? source;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Recipe({
    String? id,
    required this.title,
    this.description,
    this.servings,
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    this.ingredients = const [],
    this.instructions = const [],
    this.tags = const [],
    this.images = const [],
    this.primaryImageIndex = 0,
    this.isFavorite = false,
    this.source,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Primary image URL (the thumbnail).
  String? get primaryImageUrl =>
      images.isNotEmpty ? images[primaryImageIndex.clamp(0, images.length - 1)] : null;

  Recipe copyWith({
    String? title,
    String? description,
    int? servings,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    List<Ingredient>? ingredients,
    List<RecipeInstruction>? instructions,
    List<String>? tags,
    List<String>? images,
    int? primaryImageIndex,
    bool? isFavorite,
    String? source,
    String? notes,
    bool clearDescription = false,
    bool clearSource = false,
    bool clearNotes = false,
  }) {
    return Recipe(
      id: id,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      servings: servings ?? this.servings,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      tags: tags ?? this.tags,
      images: images ?? this.images,
      primaryImageIndex: primaryImageIndex ?? this.primaryImageIndex,
      isFavorite: isFavorite ?? this.isFavorite,
      source: clearSource ? null : (source ?? this.source),
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  int? get totalTimeMinutes {
    if (prepTimeMinutes == null && cookTimeMinutes == null) return null;
    return (prepTimeMinutes ?? 0) + (cookTimeMinutes ?? 0);
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'servings': servings,
    'prepTimeMinutes': prepTimeMinutes,
    'cookTimeMinutes': cookTimeMinutes,
    'ingredients': ingredients.map((i) => i.toMap()).toList(),
    'instructions': instructions.map((i) => i.toMap()).toList(),
    'tags': tags,
    'images': images,
    'primaryImageIndex': primaryImageIndex,
    'isFavorite': isFavorite,
    'source': source,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Recipe.fromMap(Map<String, dynamic> map) {
    // Parse instructions: support both legacy List<String> and new List<Map>
    final rawInstructions = map['instructions'] as List? ?? [];
    final instructions = rawInstructions.map((item) {
      if (item is String) return RecipeInstruction.fromString(item);
      return RecipeInstruction.fromMap(item as Map<String, dynamic>);
    }).toList();

    // Parse images: support legacy single imageUrl field
    final imagesList = (map['images'] as List?)?.cast<String>() ?? [];
    final legacyImageUrl = map['imageUrl'] as String?;
    final images = imagesList.isNotEmpty
        ? imagesList
        : (legacyImageUrl != null ? [legacyImageUrl] : <String>[]);

    return Recipe(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      servings: map['servings'] as int?,
      prepTimeMinutes: map['prepTimeMinutes'] as int?,
      cookTimeMinutes: map['cookTimeMinutes'] as int?,
      ingredients:
          (map['ingredients'] as List?)
              ?.map((i) => Ingredient.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      instructions: instructions,
      tags: (map['tags'] as List?)?.map((s) => s as String).toList() ?? [],
      images: images,
      primaryImageIndex: map['primaryImageIndex'] as int? ?? 0,
      isFavorite: map['isFavorite'] as bool? ?? false,
      source: map['source'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
