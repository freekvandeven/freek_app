import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../services/gemini_api_key_service.dart';
import '../services/gemini_oauth_service.dart';
import '../services/gemini_service.dart';

final geminiApiKeyServiceProvider = Provider<GeminiApiKeyService>((ref) {
  return GeminiApiKeyService();
});

final geminiOAuthServiceProvider = Provider<GeminiOAuthService>((ref) {
  return GeminiOAuthService();
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

/// Which Gemini auth mode the user has selected.
/// 'apiKey' (default) or 'oauth' — read from UserSettings.
final geminiAuthModeProvider = Provider<GeminiAuthMode>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.settings.geminiAuthMode == 'oauth'
      ? GeminiAuthMode.oauth
      : GeminiAuthMode.apiKey;
});

/// Whether the Gemini OAuth account is currently connected.
final geminiOAuthConnectedProvider = StateProvider<bool>((ref) => false);

/// Whether the Gemini service has whatever auth it needs for the current
/// mode. For API-key mode this means a key is set; for OAuth mode it
/// means the user is signed in.
final geminiAvailableProvider = FutureProvider<bool>((ref) async {
  final mode = ref.watch(geminiAuthModeProvider);
  if (mode == GeminiAuthMode.apiKey) {
    final key = await ref.watch(geminiApiKeyServiceProvider).getApiKey();
    return key.isNotEmpty;
  }
  return ref.watch(geminiOAuthConnectedProvider);
});

/// Legacy alias used by older call sites. Reflects the current auth
/// mode's availability so existing checks keep working.
final geminiApiKeyAvailableProvider = FutureProvider<bool>((ref) async {
  return ref.watch(geminiAvailableProvider.future);
});

/// Configure [geminiServiceProvider]'s service instance to match the
/// user's current settings (auth mode, model). Call this from any page
/// before triggering a Gemini request to make sure the service has
/// current credentials. Returns true when the service is ready to use,
/// false when the user hasn't set up the chosen auth mode yet.
Future<bool> configureGeminiForCurrentSettings(WidgetRef ref) async {
  final service = ref.read(geminiServiceProvider);
  final model = ref.read(geminiModelProvider);
  final mode = ref.read(geminiAuthModeProvider);
  if (mode == GeminiAuthMode.oauth) {
    final oauth = ref.read(geminiOAuthServiceProvider);
    if (oauth.account == null) {
      final ok = await oauth.trySilentSignIn();
      if (!ok) return false;
      ref.read(geminiOAuthConnectedProvider.notifier).state = true;
    }
    service.configureOauth(oauth, model: model);
    return service.isConfigured;
  }
  // API-key mode
  final apiKey = await ref.read(geminiApiKeyServiceProvider).getApiKey();
  if (apiKey.isEmpty) return false;
  service.configure(apiKey, model: model);
  return true;
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser})
    : timestamp = DateTime.now();
}

final geminiChatProvider =
    NotifierProvider<GeminiChatNotifier, List<ChatMessage>>(
      GeminiChatNotifier.new,
    );

class GeminiChatNotifier extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() => [];

  Future<bool> _ensureConfigured() async {
    final service = ref.read(geminiServiceProvider);
    final model = ref.read(geminiModelProvider);
    final mode = ref.read(geminiAuthModeProvider);
    if (mode == GeminiAuthMode.oauth) {
      final oauth = ref.read(geminiOAuthServiceProvider);
      if (oauth.account == null) {
        final ok = await oauth.trySilentSignIn();
        if (!ok) return false;
        ref.read(geminiOAuthConnectedProvider.notifier).state = true;
      }
      service.configureOauth(oauth, model: model);
      return service.isConfigured;
    }
    final apiKey = await ref.read(geminiApiKeyServiceProvider).getApiKey();
    if (apiKey.isEmpty) return false;
    service.configure(apiKey, model: model);
    return true;
  }

  Future<void> sendMessage(String message) async {
    state = [...state, ChatMessage(text: message, isUser: true)];

    final ok = await _ensureConfigured();
    if (!ok) {
      state = [
        ...state,
        ChatMessage(
          text: 'Gemini is not configured. Set it up in Settings → AI.',
          isUser: false,
        ),
      ];
      return;
    }
    final service = ref.read(geminiServiceProvider);
    try {
      final response = await service.sendMessage(message);
      state = [...state, ChatMessage(text: response, isUser: false)];
    } on GeminiScopeException catch (e) {
      // OAuth token doesn't have a scope generativelanguage.googleapis.com
      // accepts — the service auto-disconnected. Reflect that here and
      // tell the user how to fix it (BUG-0036).
      ref.read(geminiOAuthConnectedProvider.notifier).state = false;
      state = [...state, ChatMessage(text: e.message, isUser: false)];
    } on GeminiRateLimitException catch (e) {
      // 429 / quota / prepayment-depleted. Don't let it crash the chat;
      // surface the API message so the user knows what happened, plus a
      // hint to switch model in Settings → AI (some models still have
      // free-tier quota even when others are depleted).
      final msg = humanizeGeminiRateLimit(e);
      state = [...state, ChatMessage(text: msg, isUser: false)];
    }
  }

  void clearChat() {
    ref.read(geminiServiceProvider).resetChat();
    state = [];
  }
}
