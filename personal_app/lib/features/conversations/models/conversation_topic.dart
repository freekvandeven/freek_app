import 'package:uuid/uuid.dart';

enum TopicPriority { low, medium, high }

enum TopicStatus { open, resolved }

class ConversationTopic {
  final String id;
  final String title;
  final String description;
  final String personOrGroup;
  final TopicPriority priority;
  final TopicStatus status;
  final List<String> imageUrls;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final DateTime updatedAt;

  ConversationTopic({
    String? id,
    required this.title,
    required this.description,
    required this.personOrGroup,
    this.priority = TopicPriority.medium,
    this.status = TopicStatus.open,
    this.imageUrls = const [],
    DateTime? createdAt,
    this.resolvedAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ConversationTopic copyWith({
    String? title,
    String? description,
    String? personOrGroup,
    TopicPriority? priority,
    TopicStatus? status,
    List<String>? imageUrls,
    DateTime? resolvedAt,
    bool clearResolvedAt = false,
    DateTime? updatedAt,
  }) {
    return ConversationTopic(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      personOrGroup: personOrGroup ?? this.personOrGroup,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt,
      resolvedAt: clearResolvedAt ? null : (resolvedAt ?? this.resolvedAt),
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'personOrGroup': personOrGroup,
        'priority': priority.name,
        'status': status.name,
        'imageUrls': imageUrls,
        'createdAt': createdAt.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ConversationTopic.fromMap(Map<String, dynamic> map) =>
      ConversationTopic(
        id: map['id'] as String,
        title: map['title'] as String,
        description: map['description'] as String,
        personOrGroup: map['personOrGroup'] as String,
        priority: TopicPriority.values.byName(map['priority'] as String),
        status: TopicStatus.values.byName(map['status'] as String),
        imageUrls:
            (map['imageUrls'] as List<dynamic>?)?.cast<String>() ?? const [],
        createdAt: DateTime.parse(map['createdAt'] as String),
        resolvedAt: map['resolvedAt'] != null
            ? DateTime.parse(map['resolvedAt'] as String)
            : null,
        updatedAt: DateTime.parse(map['updatedAt'] as String),
      );
}
