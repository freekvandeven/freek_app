import 'package:uuid/uuid.dart';

enum FeedbackType { wish, bug }

enum FeedbackStatus { open, acknowledged, resolved }

class FeedbackEntry {
  final String id;
  final FeedbackType type;
  final String title;
  final String description;
  final FeedbackStatus status;
  final bool isPrivate;
  final String? userId;
  final String? attachedLogs;
  final List<String> imageUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  FeedbackEntry({
    String? id,
    required this.type,
    required this.title,
    required this.description,
    this.status = FeedbackStatus.open,
    this.isPrivate = false,
    this.userId,
    this.attachedLogs,
    this.imageUrls = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  FeedbackEntry copyWith({
    FeedbackType? type,
    String? title,
    String? description,
    FeedbackStatus? status,
    bool? isPrivate,
    String? attachedLogs,
    bool clearAttachedLogs = false,
    List<String>? imageUrls,
    DateTime? updatedAt,
  }) {
    return FeedbackEntry(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      isPrivate: isPrivate ?? this.isPrivate,
      userId: userId,
      attachedLogs: clearAttachedLogs
          ? null
          : (attachedLogs ?? this.attachedLogs),
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'title': title,
    'description': description,
    'status': status.name,
    'isPrivate': isPrivate,
    'userId': userId,
    'attachedLogs': attachedLogs,
    'imageUrls': imageUrls,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory FeedbackEntry.fromMap(Map<String, dynamic> map) => FeedbackEntry(
    id: map['id'] as String,
    type: FeedbackType.values.byName(map['type'] as String),
    title: map['title'] as String,
    description: map['description'] as String,
    status: FeedbackStatus.values.byName(map['status'] as String),
    isPrivate: map['isPrivate'] as bool? ?? false,
    userId: map['userId'] as String?,
    attachedLogs: map['attachedLogs'] as String?,
    imageUrls: (map['imageUrls'] as List<dynamic>?)?.cast<String>() ?? const [],
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );

  String toClipboardText() {
    final typeLabel = type == FeedbackType.bug ? 'Bug' : 'Wish';
    final buf = StringBuffer(
      '**[$typeLabel] $title**\n\n'
      '$description\n\n'
      'Status: ${status.name[0].toUpperCase()}${status.name.substring(1)}\n'
      'Created: ${createdAt.toIso8601String().substring(0, 10)}',
    );
    if (attachedLogs != null && attachedLogs!.isNotEmpty) {
      buf.write('\n\n**Attached Logs:**\n```\n$attachedLogs\n```');
    }
    if (imageUrls.isNotEmpty) {
      buf.write('\n\n**Attached Images (${imageUrls.length}):**');
      for (final url in imageUrls) {
        buf.write('\n- $url');
      }
    }
    return buf.toString();
  }
}
