import 'package:uuid/uuid.dart';

class ShoppingItem {
  final String id;
  final String title;
  final String? description;
  final int quantity;
  final String? unit;
  final String? catalogItemId;
  final bool isCompleted;
  final bool isWip;
  final DateTime createdAt;
  final DateTime updatedAt;

  ShoppingItem({
    String? id,
    required this.title,
    this.description,
    this.quantity = 1,
    this.unit,
    this.catalogItemId,
    this.isCompleted = false,
    this.isWip = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  ShoppingItem copyWith({
    String? title,
    String? description,
    int? quantity,
    String? unit,
    String? catalogItemId,
    bool? isCompleted,
    bool? isWip,
    bool clearDescription = false,
    bool clearUnit = false,
    bool clearCatalogItemId = false,
  }) {
    return ShoppingItem(
      id: id,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      quantity: quantity ?? this.quantity,
      unit: clearUnit ? null : (unit ?? this.unit),
      catalogItemId: clearCatalogItemId
          ? null
          : (catalogItemId ?? this.catalogItemId),
      isCompleted: isCompleted ?? this.isCompleted,
      isWip: isWip ?? this.isWip,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'quantity': quantity,
    'unit': unit,
    'catalogItemId': catalogItemId,
    'isCompleted': isCompleted,
    'isWip': isWip,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ShoppingItem.fromMap(Map<String, dynamic> map) {
    return ShoppingItem(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      quantity: map['quantity'] as int? ?? 1,
      unit: map['unit'] as String?,
      catalogItemId: map['catalogItemId'] as String?,
      isCompleted: map['isCompleted'] as bool? ?? false,
      isWip: map['isWip'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
