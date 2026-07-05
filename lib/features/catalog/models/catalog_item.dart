import 'package:uuid/uuid.dart';

class CatalogItem {
  final String id;
  final String title;
  final String? description;
  final double? price;
  final String? link;
  final List<String> imageUrls;

  /// Optional user rating, 0.0 – 5.0 in 0.5 increments (WISH-0080).
  /// `null` means "no rating yet". The wish also called out a 1–10
  /// alternative — that's just `rating * 2`, displayed alongside the
  /// stars in the UI rather than stored as a separate field.
  final double? rating;

  /// Raw nicknames string — extra search words separated by space,
  /// comma or period. Only shown on the edit page, never in lists
  /// (WISH-0082).
  final String? searchAliases;

  final DateTime createdAt;
  final DateTime updatedAt;

  CatalogItem({
    String? id,
    required this.title,
    this.description,
    this.price,
    this.link,
    this.imageUrls = const [],
    this.rating,
    this.searchAliases,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  CatalogItem copyWith({
    String? title,
    String? description,
    double? price,
    String? link,
    List<String>? imageUrls,
    double? rating,
    String? searchAliases,
    bool clearDescription = false,
    bool clearPrice = false,
    bool clearLink = false,
    bool clearRating = false,
    bool clearSearchAliases = false,
  }) {
    return CatalogItem(
      id: id,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      price: clearPrice ? null : (price ?? this.price),
      link: clearLink ? null : (link ?? this.link),
      imageUrls: imageUrls ?? this.imageUrls,
      rating: clearRating ? null : (rating ?? this.rating),
      searchAliases: clearSearchAliases
          ? null
          : (searchAliases ?? this.searchAliases),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'price': price,
    'link': link,
    'imageUrls': imageUrls,
    'rating': rating,
    'searchAliases': searchAliases,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CatalogItem.fromMap(Map<String, dynamic> map) {
    List<String> urls = [];
    if (map['imageUrls'] is List) {
      urls = (map['imageUrls'] as List<dynamic>)
          .map((e) => e as String)
          .toList();
    }

    return CatalogItem(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      price: (map['price'] as num?)?.toDouble(),
      link: map['link'] as String?,
      imageUrls: urls,
      rating: (map['rating'] as num?)?.toDouble(),
      searchAliases: map['searchAliases'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
