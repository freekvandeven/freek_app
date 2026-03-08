class UserSettings {
  final String themeMode;
  final bool notificationsEnabled;
  final String defaultCurrency;
  final bool biometricEnabled;

  const UserSettings({
    this.themeMode = 'system',
    this.notificationsEnabled = true,
    this.defaultCurrency = 'EUR',
    this.biometricEnabled = true,
  });

  UserSettings copyWith({
    String? themeMode,
    bool? notificationsEnabled,
    String? defaultCurrency,
    bool? biometricEnabled,
  }) {
    return UserSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }

  Map<String, dynamic> toMap() => {
    'themeMode': themeMode,
    'notificationsEnabled': notificationsEnabled,
    'defaultCurrency': defaultCurrency,
    'biometricEnabled': biometricEnabled,
  };

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      themeMode: map['themeMode'] as String? ?? 'system',
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      defaultCurrency: map['defaultCurrency'] as String? ?? 'EUR',
      biometricEnabled: map['biometricEnabled'] as bool? ?? true,
    );
  }
}

class UserProfile {
  final String id;
  final String email;
  final String? displayName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserSettings settings;

  const UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    required this.createdAt,
    required this.updatedAt,
    this.settings = const UserSettings(),
  });

  UserProfile copyWith({
    String? displayName,
    DateTime? updatedAt,
    UserSettings? settings,
  }) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      settings: settings ?? this.settings,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'settings': settings.toMap(),
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      settings: map['settings'] != null
          ? UserSettings.fromMap(map['settings'] as Map<String, dynamic>)
          : const UserSettings(),
    );
  }
}
