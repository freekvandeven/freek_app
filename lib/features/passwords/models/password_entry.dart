import 'package:uuid/uuid.dart';

class PasswordEntry {
  final String id;
  final String title;
  final String? username;
  final String encryptedPassword;
  final String? url;
  final String? encryptedNotes;
  final String? category;
  final DateTime createdAt;
  final DateTime updatedAt;

  PasswordEntry({
    String? id,
    required this.title,
    this.username,
    required this.encryptedPassword,
    this.url,
    this.encryptedNotes,
    this.category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  PasswordEntry copyWith({
    String? title,
    String? username,
    String? encryptedPassword,
    String? url,
    String? encryptedNotes,
    String? category,
    bool clearUsername = false,
    bool clearUrl = false,
    bool clearNotes = false,
    bool clearCategory = false,
  }) {
    return PasswordEntry(
      id: id,
      title: title ?? this.title,
      username: clearUsername ? null : (username ?? this.username),
      encryptedPassword: encryptedPassword ?? this.encryptedPassword,
      url: clearUrl ? null : (url ?? this.url),
      encryptedNotes: clearNotes
          ? null
          : (encryptedNotes ?? this.encryptedNotes),
      category: clearCategory ? null : (category ?? this.category),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'username': username,
    'encryptedPassword': encryptedPassword,
    'url': url,
    'encryptedNotes': encryptedNotes,
    'category': category,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory PasswordEntry.fromMap(Map<String, dynamic> map) {
    return PasswordEntry(
      id: map['id'] as String,
      title: map['title'] as String,
      username: map['username'] as String?,
      encryptedPassword: map['encryptedPassword'] as String,
      url: map['url'] as String?,
      encryptedNotes: map['encryptedNotes'] as String?,
      category: map['category'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

/// Decrypted view of a password entry for UI display.
class DecryptedPasswordEntry {
  final PasswordEntry entry;
  final String password;
  final String? notes;

  DecryptedPasswordEntry({
    required this.entry,
    required this.password,
    this.notes,
  });

  String get id => entry.id;
  String get title => entry.title;
  String? get username => entry.username;
  String? get url => entry.url;
  String? get category => entry.category;
  DateTime get createdAt => entry.createdAt;
  DateTime get updatedAt => entry.updatedAt;
}
