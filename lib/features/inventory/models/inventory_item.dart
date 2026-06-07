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
  final DateTime? expiryDate;
  final List<String> imageUrls;
  final String? barcode;
  final String? catalogItemId;
  final Map<String, String> customFields;

  /// Optional "how full is this" indicator (0–100) — useful for things
  /// the user wants to flag as half-empty / almost-gone without
  /// changing the integer [quantity] (WISH-0078). `null` means "not
  /// tracked" and the UI hides the indicator entirely.
  final int? fillPercent;

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
    this.expiryDate,
    this.imageUrls = const [],
    this.barcode,
    this.catalogItemId,
    this.customFields = const {},
    this.fillPercent,
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
    DateTime? expiryDate,
    List<String>? imageUrls,
    String? barcode,
    String? catalogItemId,
    Map<String, String>? customFields,
    int? fillPercent,
    bool clearDescription = false,
    bool clearCategory = false,
    bool clearLocation = false,
    bool clearPurchasePrice = false,
    bool clearPurchaseDate = false,
    bool clearExpiryDate = false,
    bool clearBarcode = false,
    bool clearCatalogItemId = false,
    bool clearFillPercent = false,
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
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      imageUrls: imageUrls ?? this.imageUrls,
      barcode: clearBarcode ? null : (barcode ?? this.barcode),
      catalogItemId: clearCatalogItemId
          ? null
          : (catalogItemId ?? this.catalogItemId),
      customFields: customFields ?? this.customFields,
      fillPercent: clearFillPercent ? null : (fillPercent ?? this.fillPercent),
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
    'expiryDate': expiryDate?.toIso8601String(),
    'imageUrls': imageUrls,
    'barcode': barcode,
    'catalogItemId': catalogItemId,
    'customFields': customFields,
    'fillPercent': fillPercent,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    // Backward compat: migrate single imageUrl to imageUrls list
    List<String> urls = [];
    if (map['imageUrls'] is List) {
      urls = (map['imageUrls'] as List<dynamic>)
          .map((e) => e as String)
          .toList();
    } else if (map['imageUrl'] is String) {
      urls = [map['imageUrl'] as String];
    }

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
      expiryDate: map['expiryDate'] != null
          ? DateTime.parse(map['expiryDate'] as String)
          : null,
      imageUrls: urls,
      barcode: map['barcode'] as String?,
      catalogItemId: map['catalogItemId'] as String?,
      customFields: map['customFields'] != null
          ? Map<String, String>.from(map['customFields'] as Map)
          : {},
      fillPercent: (map['fillPercent'] as num?)?.toInt(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
