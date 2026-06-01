import 'package:uuid/uuid.dart';

/// A contact the user manages locally — distinct from the "people"
/// feature (which is about other app users' public profiles). Used to
/// give conversations a structured backing entity instead of a
/// free-text personOrGroup label (WISH-0076).
class Contact {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final DateTime? dateOfBirth;
  final String notes;

  /// True when this entity represents a group (family, team, …) rather
  /// than a single person. Affects the UI icon and lets the user split
  /// their conversation list mentally.
  final bool isGroup;

  final DateTime createdAt;
  final DateTime updatedAt;

  Contact({
    String? id,
    required this.name,
    this.email,
    this.phone,
    this.dateOfBirth,
    this.notes = '',
    this.isGroup = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Contact copyWith({
    String? name,
    String? Function()? email,
    String? Function()? phone,
    DateTime? Function()? dateOfBirth,
    String? notes,
    bool? isGroup,
    DateTime? updatedAt,
  }) {
    return Contact(
      id: id,
      name: name ?? this.name,
      email: email != null ? email() : this.email,
      phone: phone != null ? phone() : this.phone,
      dateOfBirth: dateOfBirth != null ? dateOfBirth() : this.dateOfBirth,
      notes: notes ?? this.notes,
      isGroup: isGroup ?? this.isGroup,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'dateOfBirth': dateOfBirth?.toIso8601String(),
    'notes': notes,
    'isGroup': isGroup,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Contact.fromMap(Map<String, dynamic> map) => Contact(
    id: map['id'] as String,
    name: map['name'] as String,
    email: map['email'] as String?,
    phone: map['phone'] as String?,
    dateOfBirth: map['dateOfBirth'] != null
        ? DateTime.parse(map['dateOfBirth'] as String)
        : null,
    notes: map['notes'] as String? ?? '',
    isGroup: map['isGroup'] as bool? ?? false,
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );
}
