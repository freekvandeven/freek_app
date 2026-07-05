import 'package:uuid/uuid.dart';

/// A file attached to a knowledge page. Stored as plain data on the
/// page document so the UI can render the attachment list without an
/// extra Storage round-trip. The Cloud Function storage triggers
/// (`onFileUploaded` / `onFileDeleted`) keep the user's
/// `storageUsedBytes` in sync as files appear and disappear under
/// `users/{userId}/knowledge/`.
class KnowledgeAttachment {
  final String url;
  final String fileName;
  final String contentType;
  final int sizeBytes;

  const KnowledgeAttachment({
    required this.url,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
  });

  Map<String, dynamic> toMap() => {
    'url': url,
    'fileName': fileName,
    'contentType': contentType,
    'sizeBytes': sizeBytes,
  };

  factory KnowledgeAttachment.fromMap(Map<String, dynamic> map) =>
      KnowledgeAttachment(
        url: map['url'] as String,
        fileName: map['fileName'] as String,
        contentType:
            map['contentType'] as String? ?? 'application/octet-stream',
        sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      );
}

class KnowledgePage {
  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final String? parentId;
  final int sortOrder;
  final bool isWip;
  final List<KnowledgeAttachment> attachments;

  /// Raw nicknames string — extra search words separated by space,
  /// comma or period. Only shown on the edit page, never in lists
  /// (WISH-0082).
  final String? searchAliases;

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
    this.attachments = const [],
    this.searchAliases,
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
    List<KnowledgeAttachment>? attachments,
    String? Function()? searchAliases,
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
      attachments: attachments ?? this.attachments,
      searchAliases: searchAliases != null
          ? searchAliases()
          : this.searchAliases,
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
    'attachments': attachments.map((a) => a.toMap()).toList(),
    'searchAliases': searchAliases,
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
    attachments:
        (map['attachments'] as List<dynamic>?)
            ?.map((e) => KnowledgeAttachment.fromMap(e as Map<String, dynamic>))
            .toList() ??
        const [],
    searchAliases: map['searchAliases'] as String?,
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );
}
