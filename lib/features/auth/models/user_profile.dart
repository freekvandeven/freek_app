class UserSettings {
  final String themeMode;
  final bool notificationsEnabled;
  final String defaultCurrency;
  final bool biometricEnabled;
  final String? customSeedColor;
  final String? geminiModel;
  final bool showImagePreviews;
  final List<int> expiryReminderDays;
  // 0 = disabled; otherwise interval in minutes
  final int autosaveIntervalMinutes;
  final bool syncToGoogleCalendar;

  const UserSettings({
    this.themeMode = 'system',
    this.notificationsEnabled = true,
    this.defaultCurrency = 'EUR',
    this.biometricEnabled = true,
    this.customSeedColor,
    this.geminiModel,
    this.showImagePreviews = true,
    this.expiryReminderDays = const [7, 1],
    this.autosaveIntervalMinutes = 0,
    this.syncToGoogleCalendar = true,
  });

  UserSettings copyWith({
    String? themeMode,
    bool? notificationsEnabled,
    String? defaultCurrency,
    bool? biometricEnabled,
    String? customSeedColor,
    bool clearCustomSeedColor = false,
    String? geminiModel,
    bool clearGeminiModel = false,
    bool? showImagePreviews,
    List<int>? expiryReminderDays,
    int? autosaveIntervalMinutes,
    bool? syncToGoogleCalendar,
  }) {
    return UserSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      customSeedColor: clearCustomSeedColor
          ? null
          : (customSeedColor ?? this.customSeedColor),
      geminiModel: clearGeminiModel ? null : (geminiModel ?? this.geminiModel),
      showImagePreviews: showImagePreviews ?? this.showImagePreviews,
      expiryReminderDays: expiryReminderDays ?? this.expiryReminderDays,
      autosaveIntervalMinutes:
          autosaveIntervalMinutes ?? this.autosaveIntervalMinutes,
      syncToGoogleCalendar: syncToGoogleCalendar ?? this.syncToGoogleCalendar,
    );
  }

  Map<String, dynamic> toMap() => {
    'themeMode': themeMode,
    'notificationsEnabled': notificationsEnabled,
    'defaultCurrency': defaultCurrency,
    'biometricEnabled': biometricEnabled,
    'customSeedColor': customSeedColor,
    'geminiModel': geminiModel,
    'showImagePreviews': showImagePreviews,
    'expiryReminderDays': expiryReminderDays,
    'autosaveIntervalMinutes': autosaveIntervalMinutes,
    'syncToGoogleCalendar': syncToGoogleCalendar,
  };

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      themeMode: map['themeMode'] as String? ?? 'system',
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      defaultCurrency: map['defaultCurrency'] as String? ?? 'EUR',
      biometricEnabled: map['biometricEnabled'] as bool? ?? true,
      customSeedColor: map['customSeedColor'] as String?,
      geminiModel: map['geminiModel'] as String?,
      showImagePreviews: map['showImagePreviews'] as bool? ?? true,
      expiryReminderDays:
          (map['expiryReminderDays'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [7, 1],
      autosaveIntervalMinutes: map['autosaveIntervalMinutes'] as int? ?? 0,
      syncToGoogleCalendar: map['syncToGoogleCalendar'] as bool? ?? true,
    );
  }
}

class UserProfile {
  final String id;
  final String email;
  final String? displayName;
  final String? bio;
  final String? phone;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserSettings settings;
  final int storageUsedBytes;
  final int storageLimitBytes;
  final List<String> fcmTokens;

  /// Default storage limit: 100 MB
  static const int defaultStorageLimitBytes = 100 * 1024 * 1024;

  const UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.bio,
    this.phone,
    this.photoUrl,
    required this.createdAt,
    required this.updatedAt,
    this.settings = const UserSettings(),
    this.storageUsedBytes = 0,
    this.storageLimitBytes = defaultStorageLimitBytes,
    this.fcmTokens = const [],
  });

  UserProfile copyWith({
    String? displayName,
    String? bio,
    String? phone,
    String? photoUrl,
    DateTime? updatedAt,
    UserSettings? settings,
    int? storageUsedBytes,
    int? storageLimitBytes,
    List<String>? fcmTokens,
    bool clearBio = false,
    bool clearPhone = false,
    bool clearPhotoUrl = false,
  }) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      bio: clearBio ? null : (bio ?? this.bio),
      phone: clearPhone ? null : (phone ?? this.phone),
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      settings: settings ?? this.settings,
      storageUsedBytes: storageUsedBytes ?? this.storageUsedBytes,
      storageLimitBytes: storageLimitBytes ?? this.storageLimitBytes,
      fcmTokens: fcmTokens ?? this.fcmTokens,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'bio': bio,
    'phone': phone,
    'photoUrl': photoUrl,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'settings': settings.toMap(),
    'storageUsedBytes': storageUsedBytes,
    'storageLimitBytes': storageLimitBytes,
    'fcmTokens': fcmTokens,
  };

  /// Returns client-writable fields only (excludes server-managed storage tracking).
  Map<String, dynamic> toClientMap() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'bio': bio,
    'phone': phone,
    'photoUrl': photoUrl,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'settings': settings.toMap(),
  };

  /// Returns only the fields visible to other users.
  Map<String, dynamic> toPublicMap() => {
    'id': id,
    'displayName': displayName,
    'bio': bio,
    'photoUrl': photoUrl,
    'createdAt': createdAt.toIso8601String(),
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String?,
      bio: map['bio'] as String?,
      phone: map['phone'] as String?,
      photoUrl: map['photoUrl'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      settings: map['settings'] != null
          ? UserSettings.fromMap(map['settings'] as Map<String, dynamic>)
          : const UserSettings(),
      storageUsedBytes: map['storageUsedBytes'] as int? ?? 0,
      storageLimitBytes:
          map['storageLimitBytes'] as int? ?? defaultStorageLimitBytes,
      fcmTokens:
          (map['fcmTokens'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }
}
