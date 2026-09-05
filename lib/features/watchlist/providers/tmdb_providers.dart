import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tmdb_api_key_service.dart';
import '../services/tmdb_service.dart';

final tmdbApiKeyServiceProvider = Provider<TmdbApiKeyService>((ref) {
  return TmdbApiKeyService();
});

/// The stored TMDB key, or an empty string when none is configured.
final tmdbApiKeyProvider = FutureProvider<String>((ref) {
  return ref.watch(tmdbApiKeyServiceProvider).getApiKey();
});

/// Whether metadata lookups are available at all — the fetch and search
/// affordances stay hidden until a key is configured (WISH-0100).
final tmdbAvailableProvider = Provider<bool>((ref) {
  final key = ref.watch(tmdbApiKeyProvider).valueOrNull;
  return key != null && key.isNotEmpty;
});

/// Rebuilt whenever the key changes, so a newly saved key takes effect
/// without restarting the app.
final tmdbServiceProvider = Provider<TmdbService>((ref) {
  final key = ref.watch(tmdbApiKeyProvider).valueOrNull ?? '';
  return TmdbService(key);
});
