import 'package:uuid/uuid.dart';

/// A node in the user's Files tree (WISH-0069). Each entry is either
/// a directory or an uploaded file. Directories are pure Firestore
/// records; files additionally point at a Firebase Storage object
/// under `users/{userId}/files/` so the existing storage usage
/// triggers (`onFileUploaded` / `onFileDeleted`) keep the quota in
/// sync without any feature-specific bookkeeping.
class FileEntry {
  final String id;
  final String name;
  final String? parentId;
  final bool isDirectory;

  /// Storage download URL — null for directories.
  final String? url;

  /// MIME type — null for directories.
  final String? contentType;

  /// File size in bytes — 0 for directories.
  final int sizeBytes;

  final DateTime createdAt;
  final DateTime updatedAt;

  FileEntry({
    String? id,
    required this.name,
    this.parentId,
    required this.isDirectory,
    this.url,
    this.contentType,
    this.sizeBytes = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  FileEntry copyWith({
    String? name,
    String? Function()? parentId,
    DateTime? updatedAt,
  }) {
    return FileEntry(
      id: id,
      name: name ?? this.name,
      parentId: parentId != null ? parentId() : this.parentId,
      isDirectory: isDirectory,
      url: url,
      contentType: contentType,
      sizeBytes: sizeBytes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'parentId': parentId,
    'isDirectory': isDirectory,
    'url': url,
    'contentType': contentType,
    'sizeBytes': sizeBytes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory FileEntry.fromMap(Map<String, dynamic> map) => FileEntry(
    id: map['id'] as String,
    name: map['name'] as String,
    parentId: map['parentId'] as String?,
    isDirectory: map['isDirectory'] as bool? ?? false,
    url: map['url'] as String?,
    contentType: map['contentType'] as String?,
    sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );
}

enum FileSort { name, updatedAt }
