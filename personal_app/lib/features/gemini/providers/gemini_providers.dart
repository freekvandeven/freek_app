import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/gemini_service.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
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
    final response = await service.sendMessage(message);

    state = [...state, ChatMessage(text: response, isUser: false)];
  }

  void clearChat() {
    ref.read(geminiServiceProvider).resetChat();
    state = [];
  }
}
