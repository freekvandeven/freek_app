import 'package:uuid/uuid.dart';

class InventoryItem {
  final String id;
  final String name;
  final String? description;
  final String? category;
  final String? location;
  final int quantity;
  final double? purchasePrice;
  final DateTime? purchaseDate;
  final String? imageUrl;
  final String? barcode;
  final Map<String, String> customFields;
  final DateTime createdAt;
  final DateTime updatedAt;

  InventoryItem({
    String? id,
    required this.name,
    this.description,
    this.category,
    this.location,
    this.quantity = 1,
    this.purchasePrice,
    this.purchaseDate,
    this.imageUrl,
    this.barcode,
    this.customFields = const {},
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  InventoryItem copyWith({
    String? name,
    String? description,
    String? category,
    String? location,
    int? quantity,
    double? purchasePrice,
    DateTime? purchaseDate,
    String? imageUrl,
    String? barcode,
    Map<String, String>? customFields,
    bool clearDescription = false,
    bool clearCategory = false,
    bool clearLocation = false,
    bool clearPurchasePrice = false,
    bool clearPurchaseDate = false,
    bool clearBarcode = false,
  }) {
    return InventoryItem(
      id: id,
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      category: clearCategory ? null : (category ?? this.category),
      location: clearLocation ? null : (location ?? this.location),
      quantity: quantity ?? this.quantity,
      purchasePrice: clearPurchasePrice
          ? null
          : (purchasePrice ?? this.purchasePrice),
      purchaseDate: clearPurchaseDate
          ? null
          : (purchaseDate ?? this.purchaseDate),
      imageUrl: imageUrl ?? this.imageUrl,
      barcode: clearBarcode ? null : (barcode ?? this.barcode),
      customFields: customFields ?? this.customFields,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category,
    'location': location,
    'quantity': quantity,
    'purchasePrice': purchasePrice,
    'purchaseDate': purchaseDate?.toIso8601String(),
    'imageUrl': imageUrl,
    'barcode': barcode,
    'customFields': customFields,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      category: map['category'] as String?,
      location: map['location'] as String?,
      quantity: map['quantity'] as int? ?? 1,
      purchasePrice: (map['purchasePrice'] as num?)?.toDouble(),
      purchaseDate: map['purchaseDate'] != null
          ? DateTime.parse(map['purchaseDate'] as String)
          : null,
      imageUrl: map['imageUrl'] as String?,
      barcode: map['barcode'] as String?,
      customFields: map['customFields'] != null
          ? Map<String, String>.from(map['customFields'] as Map)
          : {},
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
