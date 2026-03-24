import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/providers/settings_providers.dart';
import '../services/gemini_api_key_service.dart';
import '../services/gemini_service.dart';

final geminiApiKeyServiceProvider = Provider<GeminiApiKeyService>((ref) {
  return GeminiApiKeyService();
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

/// Whether an API key is available (from secure storage or dotenv).
final geminiApiKeyAvailableProvider = FutureProvider<bool>((ref) async {
  final key = await ref.watch(geminiApiKeyServiceProvider).getApiKey();
  return key.isNotEmpty;
});

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

  Future<void> sendMessage(String message) async {
    state = [...state, ChatMessage(text: message, isUser: true)];

    final service = ref.read(geminiServiceProvider);
    final model = ref.read(geminiModelProvider);
    if (!service.isConfigured) {
      final apiKey = await ref.read(geminiApiKeyServiceProvider).getApiKey();
      service.configure(apiKey, model: model);
    } else {
      service.setModel(model);
    }
    final response = await service.sendMessage(message);

    state = [...state, ChatMessage(text: response, isUser: false)];
  }

  void clearChat() {
    ref.read(geminiServiceProvider).resetChat();
    state = [];
  }
}
