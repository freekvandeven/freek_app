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

class Recipe {
  final String id;
  final String title;
  final String? description;
  final int? servings;
  final int? prepTimeMinutes;
  final int? cookTimeMinutes;
  final List<Ingredient> ingredients;
  final List<String> instructions;
  final List<String> tags;
  final String? imageUrl;
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
    this.imageUrl,
    this.isFavorite = false,
    this.source,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Recipe copyWith({
    String? title,
    String? description,
    int? servings,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    List<Ingredient>? ingredients,
    List<String>? instructions,
    List<String>? tags,
    String? imageUrl,
    bool? isFavorite,
    String? source,
    String? notes,
    bool clearDescription = false,
    bool clearSource = false,
    bool clearNotes = false,
    bool clearImageUrl = false,
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
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
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
    'instructions': instructions,
    'tags': tags,
    'imageUrl': imageUrl,
    'isFavorite': isFavorite,
    'source': source,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Recipe.fromMap(Map<String, dynamic> map) {
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
      instructions:
          (map['instructions'] as List?)?.map((s) => s as String).toList() ??
          [],
      tags: (map['tags'] as List?)?.map((s) => s as String).toList() ?? [],
      imageUrl: map['imageUrl'] as String?,
      isFavorite: map['isFavorite'] as bool? ?? false,
      source: map['source'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
