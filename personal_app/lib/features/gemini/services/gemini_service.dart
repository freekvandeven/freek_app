import 'package:google_generative_ai/google_generative_ai.dart';

import '../../../config/app_config.dart';

class GeminiService {
  GenerativeModel? _model;
  ChatSession? _chat;

  bool get isConfigured => AppConfig.geminiApiKey.isNotEmpty;

  GenerativeModel _getModel() {
    _model ??= GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: AppConfig.geminiApiKey,
    );
    return _model!;
  }

  ChatSession _getChat() {
    _chat ??= _getModel().startChat(history: [
      Content.text(
        'You are a helpful personal assistant embedded in a life-management app called "Personal App". '
        'You help with tasks, recipes, finances, calendar planning, knowledge organization, and general questions. '
        'Keep answers concise and practical.',
      ),
      Content.model([TextPart('Understood! I\'m ready to help you with anything in your Personal App.')]),
    ]);
    return _chat!;
  }

  Future<String> sendMessage(String message) async {
    if (!isConfigured) {
      return 'Gemini API key not configured. Add GEMINI_API_KEY to your dotenv file.';
    }
    try {
      final response = await _getChat().sendMessage(Content.text(message));
      return response.text ?? 'No response received.';
    } catch (e) {
      return 'Error: $e';
    }
  }

  void resetChat() {
    _chat = null;
  }
}
