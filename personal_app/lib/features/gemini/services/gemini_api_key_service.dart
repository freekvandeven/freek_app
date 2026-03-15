import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../config/app_config.dart';

class GeminiApiKeyService {
  static const _key = 'gemini_api_key';
  final FlutterSecureStorage _storage;

  GeminiApiKeyService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Returns the API key from secure storage, or falls back to dotenv config.
  Future<String> getApiKey() async {
    final stored = await _storage.read(key: _key);
    if (stored != null && stored.isNotEmpty) return stored;
    return AppConfig.geminiApiKey;
  }

  /// Saves a user-provided API key to secure storage.
  Future<void> setApiKey(String apiKey) async {
    await _storage.write(key: _key, value: apiKey);
  }

  /// Removes the user-provided API key from secure storage.
  Future<void> clearApiKey() async {
    await _storage.delete(key: _key);
  }

  /// Returns true if a user-provided key is stored in secure storage.
  Future<bool> hasStoredKey() async {
    final stored = await _storage.read(key: _key);
    return stored != null && stored.isNotEmpty;
  }
}
