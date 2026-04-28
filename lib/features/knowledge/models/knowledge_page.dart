import 'package:uuid/uuid.dart';

class KnowledgePage {
  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final String? parentId;
  final int sortOrder;
  final bool isWip;
  final DateTime createdAt;
  final DateTime updatedAt;

  KnowledgePage({
    String? id,
    required this.title,
    required this.content,
    this.tags = const [],
    this.parentId,
    this.sortOrder = 0,
    this.isWip = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  KnowledgePage copyWith({
    String? title,
    String? content,
    List<String>? tags,
    String? Function()? parentId,
    int? sortOrder,
    bool? isWip,
    DateTime? updatedAt,
  }) {
    return KnowledgePage(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      parentId: parentId != null ? parentId() : this.parentId,
      sortOrder: sortOrder ?? this.sortOrder,
      isWip: isWip ?? this.isWip,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'tags': tags,
    'parentId': parentId,
    'sortOrder': sortOrder,
    'isWip': isWip,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory KnowledgePage.fromMap(Map<String, dynamic> map) => KnowledgePage(
    id: map['id'] as String,
    title: map['title'] as String,
    content: map['content'] as String,
    tags: (map['tags'] as List).cast<String>(),
    parentId: map['parentId'] as String?,
    sortOrder: map['sortOrder'] as int? ?? 0,
    isWip: map['isWip'] as bool? ?? false,
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );
}
