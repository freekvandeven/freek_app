import 'package:uuid/uuid.dart';

/// A streaming service the user can watch things on (WISH-0099).
///
/// Account credentials deliberately live in the encrypted password vault
/// rather than here — this model only keeps [vaultEntryId], the id of the
/// vault entry to use, so the watchlist collection never holds a secret.
class StreamingPlatform {
  final String id;
  final String name;
  final String? url;

  /// Id of the `PasswordEntry` holding the login for this platform.
  final String? vaultEntryId;

  /// Best quality the subscription offers, free text so it can hold
  /// whatever the platform advertises ("4K HDR", "1080p", "Basic with ads").
  final String? quality;

  final String? iconUrl;
  final DateTime? subscriptionStartedAt;
  final DateTime? subscriptionEndedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  StreamingPlatform({
    String? id,
    required this.name,
    this.url,
    this.vaultEntryId,
    this.quality,
    this.iconUrl,
    this.subscriptionStartedAt,
    this.subscriptionEndedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// True while a subscription is running: one has been started and not
  /// yet ended. A platform with no start date is treated as not
  /// subscribed — it can still be linked to entries, it just is not being
  /// paid for.
  bool get isSubscribed =>
      subscriptionStartedAt != null && subscriptionEndedAt == null;

  StreamingPlatform copyWith({
    String? name,
    String? url,
    String? vaultEntryId,
    String? quality,
    String? iconUrl,
    DateTime? subscriptionStartedAt,
    DateTime? subscriptionEndedAt,
    bool clearUrl = false,
    bool clearVaultEntryId = false,
    bool clearQuality = false,
    bool clearIconUrl = false,
    bool clearSubscriptionStartedAt = false,
    bool clearSubscriptionEndedAt = false,
  }) {
    return StreamingPlatform(
      id: id,
      name: name ?? this.name,
      url: clearUrl ? null : (url ?? this.url),
      vaultEntryId: clearVaultEntryId
          ? null
          : (vaultEntryId ?? this.vaultEntryId),
      quality: clearQuality ? null : (quality ?? this.quality),
      iconUrl: clearIconUrl ? null : (iconUrl ?? this.iconUrl),
      subscriptionStartedAt: clearSubscriptionStartedAt
          ? null
          : (subscriptionStartedAt ?? this.subscriptionStartedAt),
      subscriptionEndedAt: clearSubscriptionEndedAt
          ? null
          : (subscriptionEndedAt ?? this.subscriptionEndedAt),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'url': url,
    'vaultEntryId': vaultEntryId,
    'quality': quality,
    'iconUrl': iconUrl,
    'subscriptionStartedAt': subscriptionStartedAt?.toIso8601String(),
    'subscriptionEndedAt': subscriptionEndedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory StreamingPlatform.fromMap(Map<String, dynamic> map) {
    return StreamingPlatform(
      id: map['id'] as String,
      name: map['name'] as String,
      url: map['url'] as String?,
      vaultEntryId: map['vaultEntryId'] as String?,
      quality: map['quality'] as String?,
      iconUrl: map['iconUrl'] as String?,
      subscriptionStartedAt: map['subscriptionStartedAt'] == null
          ? null
          : DateTime.parse(map['subscriptionStartedAt'] as String),
      subscriptionEndedAt: map['subscriptionEndedAt'] == null
          ? null
          : DateTime.parse(map['subscriptionEndedAt'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
