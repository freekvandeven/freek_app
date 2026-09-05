import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the user's TMDB API key, mirroring how the Gemini key is kept
/// (WISH-0100). Secure storage only — there is no dotenv fallback, since
/// this is the user's own TMDB account rather than an app-level key.
class TmdbApiKeyService {
  static const _key = 'tmdb_api_key';
  final FlutterSecureStorage _storage;

  TmdbApiKeyService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<String> getApiKey() async {
    return await _storage.read(key: _key) ?? '';
  }

  Future<void> setApiKey(String apiKey) async {
    await _storage.write(key: _key, value: apiKey);
  }

  Future<void> clearApiKey() async {
    await _storage.delete(key: _key);
  }

  Future<bool> hasStoredKey() async => (await getApiKey()).isNotEmpty;
}
