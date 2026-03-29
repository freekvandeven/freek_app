import 'package:uuid/uuid.dart';

class CatalogItem {
  final String id;
  final String title;
  final String? description;
  final double? price;
  final String? link;
  final List<String> imageUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  CatalogItem({
    String? id,
    required this.title,
    this.description,
    this.price,
    this.link,
    this.imageUrls = const [],
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
    bool clearDescription = false,
    bool clearPrice = false,
    bool clearLink = false,
  }) {
    return CatalogItem(
      id: id,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      price: clearPrice ? null : (price ?? this.price),
      link: clearLink ? null : (link ?? this.link),
      imageUrls: imageUrls ?? this.imageUrls,
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
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
