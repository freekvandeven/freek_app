import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/auth/models/user_profile.dart';

void main() {
  group('UserSettings', () {
    test('default constructor has correct defaults', () {
      const settings = UserSettings();
      expect(settings.themeMode, 'system');
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.defaultCurrency, 'EUR');
      expect(settings.biometricEnabled, isTrue);
      expect(settings.customSeedColor, isNull);
      expect(settings.geminiModel, isNull);
      expect(settings.showImagePreviews, isTrue);
      expect(settings.fullscreenMode, isFalse);
    });

    test('fullscreenMode roundtrips through toMap/fromMap', () {
      const settings = UserSettings(fullscreenMode: true);
      final restored = UserSettings.fromMap(settings.toMap());
      expect(restored.fullscreenMode, isTrue);
    });

    test('fullscreenMode copyWith flips the flag', () {
      const settings = UserSettings();
      final updated = settings.copyWith(fullscreenMode: true);
      expect(updated.fullscreenMode, isTrue);
      expect(updated.themeMode, settings.themeMode);
    });

    test('dateFormatLocale defaults to null (follow device)', () {
      const settings = UserSettings();
      expect(settings.dateFormatLocale, isNull);
    });

    test('dateFormatLocale roundtrips through toMap/fromMap', () {
      const settings = UserSettings(dateFormatLocale: 'en_GB');
      final restored = UserSettings.fromMap(settings.toMap());
      expect(restored.dateFormatLocale, 'en_GB');
    });

    test('dateFormatLocale copyWith updates the value', () {
      const settings = UserSettings();
      final updated = settings.copyWith(dateFormatLocale: 'nl_NL');
      expect(updated.dateFormatLocale, 'nl_NL');
    });

    test('dateFormatLocale copyWith clearDateFormatLocale resets to null', () {
      const settings = UserSettings(dateFormatLocale: 'en_GB');
      final updated = settings.copyWith(clearDateFormatLocale: true);
      expect(updated.dateFormatLocale, isNull);
    });

    test('defaultInventoryLocation defaults to null (WISH-0084)', () {
      const settings = UserSettings();
      expect(settings.defaultInventoryLocation, isNull);
    });

    test('defaultInventoryLocation roundtrips through toMap/fromMap', () {
      const settings = UserSettings(defaultInventoryLocation: 'Kitchen');
      final restored = UserSettings.fromMap(settings.toMap());
      expect(restored.defaultInventoryLocation, 'Kitchen');
    });

    test('defaultInventoryLocation copyWith updates and clears', () {
      const settings = UserSettings(defaultInventoryLocation: 'Kitchen');
      expect(
        settings
            .copyWith(defaultInventoryLocation: 'Storage')
            .defaultInventoryLocation,
        'Storage',
      );
      expect(
        settings
            .copyWith(clearDefaultInventoryLocation: true)
            .defaultInventoryLocation,
        isNull,
      );
    });

    test('toMap and fromMap round-trip', () {
      const settings = UserSettings(
        themeMode: 'dark',
        notificationsEnabled: false,
        defaultCurrency: 'USD',
        biometricEnabled: false,
        customSeedColor: '#FF0000',
        geminiModel: 'gemini-pro',
        showImagePreviews: false,
      );
      final map = settings.toMap();
      final restored = UserSettings.fromMap(map);

      expect(restored.themeMode, 'dark');
      expect(restored.notificationsEnabled, isFalse);
      expect(restored.defaultCurrency, 'USD');
      expect(restored.biometricEnabled, isFalse);
      expect(restored.customSeedColor, '#FF0000');
      expect(restored.geminiModel, 'gemini-pro');
      expect(restored.showImagePreviews, isFalse);
    });

    test('fromMap uses defaults for missing keys', () {
      final settings = UserSettings.fromMap({});
      expect(settings.themeMode, 'system');
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.defaultCurrency, 'EUR');
      expect(settings.biometricEnabled, isTrue);
      expect(settings.showImagePreviews, isTrue);
    });

    test('copyWith replaces values', () {
      const settings = UserSettings();
      final updated = settings.copyWith(
        themeMode: 'light',
        defaultCurrency: 'USD',
      );
      expect(updated.themeMode, 'light');
      expect(updated.defaultCurrency, 'USD');
      expect(updated.notificationsEnabled, isTrue); // unchanged
    });

    test('copyWith clearCustomSeedColor sets null', () {
      const settings = UserSettings(customSeedColor: '#FF0000');
      final updated = settings.copyWith(clearCustomSeedColor: true);
      expect(updated.customSeedColor, isNull);
    });

    test('copyWith clearGeminiModel sets null', () {
      const settings = UserSettings(geminiModel: 'gemini-pro');
      final updated = settings.copyWith(clearGeminiModel: true);
      expect(updated.geminiModel, isNull);
    });
  });

  group('UserProfile', () {
    final now = DateTime(2025, 1, 15, 10, 30);
    final later = DateTime(2025, 1, 16, 12, 0);

    UserProfile createProfile() => UserProfile(
      id: 'user-123',
      email: 'test@example.com',
      displayName: 'Test User',
      bio: 'Hello world',
      phone: '+31612345678',
      createdAt: now,
      updatedAt: later,
      settings: const UserSettings(themeMode: 'dark'),
    );

    test('toMap and fromMap round-trip', () {
      final profile = createProfile();
      final map = profile.toMap();
      final restored = UserProfile.fromMap(map);

      expect(restored.id, 'user-123');
      expect(restored.email, 'test@example.com');
      expect(restored.displayName, 'Test User');
      expect(restored.bio, 'Hello world');
      expect(restored.phone, '+31612345678');
      expect(restored.createdAt, now);
      expect(restored.updatedAt, later);
      expect(restored.settings.themeMode, 'dark');
    });

    test('fromMap handles null optional fields', () {
      final profile = UserProfile.fromMap({
        'id': 'u1',
        'email': 'a@b.com',
        'displayName': null,
        'bio': null,
        'phone': null,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
      expect(profile.displayName, isNull);
      expect(profile.bio, isNull);
      expect(profile.phone, isNull);
      expect(profile.settings.themeMode, 'system'); // default
    });

    test('copyWith replaces fields', () {
      final profile = createProfile();
      final updated = profile.copyWith(displayName: 'New Name');
      expect(updated.displayName, 'New Name');
      expect(updated.email, 'test@example.com'); // unchanged
      expect(updated.id, 'user-123'); // unchanged
    });

    test('copyWith clearBio sets null', () {
      final profile = createProfile();
      final updated = profile.copyWith(clearBio: true);
      expect(updated.bio, isNull);
    });

    test('copyWith clearPhone sets null', () {
      final profile = createProfile();
      final updated = profile.copyWith(clearPhone: true);
      expect(updated.phone, isNull);
    });

    test('toMap serializes dates as ISO8601', () {
      final profile = createProfile();
      final map = profile.toMap();
      expect(map['createdAt'], now.toIso8601String());
      expect(map['updatedAt'], later.toIso8601String());
    });

    test('toMap includes nested settings', () {
      final profile = createProfile();
      final map = profile.toMap();
      expect(map['settings'], isA<Map<String, dynamic>>());
      expect((map['settings'] as Map<String, dynamic>)['themeMode'], 'dark');
    });

    test('default storage fields', () {
      final profile = createProfile();
      expect(profile.storageUsedBytes, 0);
      expect(profile.storageLimitBytes, UserProfile.defaultStorageLimitBytes);
    });

    test('toMap includes storage fields', () {
      final profile = UserProfile(
        id: 'u1',
        email: 'a@b.com',
        createdAt: now,
        updatedAt: now,
        storageUsedBytes: 5000,
        storageLimitBytes: 100000,
      );
      final map = profile.toMap();
      expect(map['storageUsedBytes'], 5000);
      expect(map['storageLimitBytes'], 100000);
    });

    test('fromMap reads storage fields', () {
      final profile = UserProfile.fromMap({
        'id': 'u1',
        'email': 'a@b.com',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'storageUsedBytes': 12345,
        'storageLimitBytes': 50000,
      });
      expect(profile.storageUsedBytes, 12345);
      expect(profile.storageLimitBytes, 50000);
    });

    test('fromMap uses defaults for missing storage fields', () {
      final profile = UserProfile.fromMap({
        'id': 'u1',
        'email': 'a@b.com',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
      expect(profile.storageUsedBytes, 0);
      expect(profile.storageLimitBytes, UserProfile.defaultStorageLimitBytes);
    });

    test('copyWith updates storage fields', () {
      final profile = createProfile();
      final updated = profile.copyWith(storageUsedBytes: 9999);
      expect(updated.storageUsedBytes, 9999);
      expect(updated.storageLimitBytes, UserProfile.defaultStorageLimitBytes);
    });

    test('toClientMap excludes storage fields', () {
      final profile = UserProfile(
        id: 'u1',
        email: 'a@b.com',
        createdAt: now,
        updatedAt: now,
        storageUsedBytes: 5000,
        storageLimitBytes: 100000,
      );
      final map = profile.toClientMap();
      expect(map.containsKey('storageUsedBytes'), isFalse);
      expect(map.containsKey('storageLimitBytes'), isFalse);
      expect(map.containsKey('id'), isTrue);
    });
  });
}
