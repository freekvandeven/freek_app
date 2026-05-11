import 'package:uuid/uuid.dart';

enum FeedbackType { wish, bug, improvement }

extension FeedbackTypeLabel on FeedbackType {
  /// Human-readable label used in clipboard exports and UI badges.
  String get label => switch (this) {
    FeedbackType.wish => 'Wish',
    FeedbackType.bug => 'Bug',
    FeedbackType.improvement => 'Improvement',
  };

  /// Prefix used for the auto-generated `BUG-NNNN` / `WISH-NNNN` /
  /// `IMPR-NNNN` reference IDs.
  String get referencePrefix => switch (this) {
    FeedbackType.wish => 'WISH',
    FeedbackType.bug => 'BUG',
    FeedbackType.improvement => 'IMPR',
  };
}

enum FeedbackStatus { open, acknowledged, resolved }

class FeedbackEntry {
  final String id;
  final String? referenceId;
  final FeedbackType type;
  final String title;
  final String description;
  final FeedbackStatus status;
  final bool isPrivate;
  final String? userId;
  final String? attachedLogs;
  final List<String> imageUrls;
  final bool isManual;
  final bool isWip;
  final String? aiSummary;
  final DateTime createdAt;
  final DateTime updatedAt;

  FeedbackEntry({
    String? id,
    this.referenceId,
    required this.type,
    required this.title,
    required this.description,
    this.status = FeedbackStatus.open,
    this.isPrivate = false,
    this.isManual = false,
    this.isWip = false,
    this.userId,
    this.attachedLogs,
    this.imageUrls = const [],
    this.aiSummary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  FeedbackEntry copyWith({
    String? referenceId,
    FeedbackType? type,
    String? title,
    String? description,
    FeedbackStatus? status,
    bool? isPrivate,
    bool? isManual,
    bool? isWip,
    String? attachedLogs,
    bool clearAttachedLogs = false,
    List<String>? imageUrls,
    String? aiSummary,
    DateTime? updatedAt,
  }) {
    return FeedbackEntry(
      id: id,
      referenceId: referenceId ?? this.referenceId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      isPrivate: isPrivate ?? this.isPrivate,
      isManual: isManual ?? this.isManual,
      isWip: isWip ?? this.isWip,
      userId: userId,
      attachedLogs: clearAttachedLogs
          ? null
          : (attachedLogs ?? this.attachedLogs),
      imageUrls: imageUrls ?? this.imageUrls,
      aiSummary: aiSummary ?? this.aiSummary,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'referenceId': referenceId,
    'type': type.name,
    'title': title,
    'description': description,
    'status': status.name,
    'isPrivate': isPrivate,
    'isManual': isManual,
    'isWip': isWip,
    'userId': userId,
    'attachedLogs': attachedLogs,
    'imageUrls': imageUrls,
    'aiSummary': aiSummary,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory FeedbackEntry.fromMap(Map<String, dynamic> map) => FeedbackEntry(
    id: map['id'] as String,
    referenceId: map['referenceId'] as String?,
    type: FeedbackType.values.byName(map['type'] as String),
    title: map['title'] as String,
    description: map['description'] as String,
    status: FeedbackStatus.values.byName(map['status'] as String),
    isPrivate: map['isPrivate'] as bool? ?? false,
    isManual: map['isManual'] as bool? ?? false,
    isWip: map['isWip'] as bool? ?? false,
    userId: map['userId'] as String?,
    attachedLogs: map['attachedLogs'] as String?,
    imageUrls: (map['imageUrls'] as List<dynamic>?)?.cast<String>() ?? const [],
    aiSummary: map['aiSummary'] as String?,
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );

  String toClipboardText() {
    final typeLabel = type.label;
    final refPrefix = referenceId != null ? ' ($referenceId)' : '';
    final buf = StringBuffer(
      '**[$typeLabel] $title**$refPrefix\n\n'
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
