import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static const defaultModel = 'gemini-2.0-flash';

  GenerativeModel? _model;
  ChatSession? _chat;
  String? _apiKey;
  String _modelName = defaultModel;

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  void configure(String apiKey, {String? model}) {
    final newModel = model ?? _modelName;
    if (apiKey != _apiKey || newModel != _modelName) {
      _apiKey = apiKey;
      _modelName = newModel;
      _model = null;
      _chat = null;
    }
  }

  void setModel(String model) {
    if (model != _modelName) {
      _modelName = model;
      _model = null;
      _chat = null;
    }
  }

  /// Fetch available generative models from the Gemini API.
  /// Returns a list of (modelId, displayName) pairs.
  Future<List<({String id, String displayName})>> listModels() async {
    if (_apiKey == null || _apiKey!.isEmpty) return [];
    try {
      final response = await http.get(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?key=$_apiKey',
        ),
      );
      if (response.statusCode != 200) return [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final models = body['models'] as List<dynamic>;
      return models
          .cast<Map<String, dynamic>>()
          .where((m) {
            final methods =
                (m['supportedGenerationMethods'] as List<dynamic>?) ?? [];
            return methods.contains('generateContent');
          })
          .map((m) {
            final name = m['name'] as String; // "models/gemini-2.0-flash"
            final id = name.replaceFirst('models/', '');
            final displayName = m['displayName'] as String? ?? id;
            return (id: id, displayName: displayName);
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  GenerativeModel _getModel() {
    _model ??= GenerativeModel(model: _modelName, apiKey: _apiKey!);
    return _model!;
  }

  ChatSession _getChat() {
    _chat ??= _getModel().startChat(
      history: [
        Content.text(
          'You are a helpful personal assistant embedded in a life-management app called "Personal App". '
          'You help with tasks, recipes, finances, calendar planning, knowledge organization, and general questions. '
          'Keep answers concise and practical.',
        ),
        Content.model([
          TextPart(
            'Understood! I\'m ready to help you with anything in your Personal App.',
          ),
        ]),
      ],
    );
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

  /// Analyze an image and return structured inventory data as JSON.
  Future<Map<String, dynamic>?> analyzeInventoryImage(
    Uint8List imageBytes,
    String mimeType, {
    List<String> categories = const [],
    List<String> locations = const [],
  }) async {
    if (!isConfigured) return null;
    try {
      final categoryHint = categories.isNotEmpty
          ? 'The user has these existing categories: ${categories.join(', ')}. '
                'Use one of these if the item fits, otherwise suggest a new category.\n'
          : '';
      final locationHint = locations.isNotEmpty
          ? 'The user has these existing locations: ${locations.join(', ')}. '
                'Use one of these if appropriate.\n'
          : '';
      final response = await _getModel().generateContent([
        Content.multi([
          TextPart(
            'Analyze this image for an inventory management app. '
            'Look carefully at the product, packaging, labels, and any visible text.\n'
            '$categoryHint$locationHint'
            'Return ONLY a JSON object with these fields (omit fields you cannot determine):\n'
            '- "name": product/item name (string)\n'
            '- "description": brief description (string)\n'
            '- "category": item category (string)\n'
            '- "location": where this item is typically stored (string)\n'
            '- "quantity": count the number of items visible in the image (int)\n'
            '- "purchasePrice": price if visible on a label or tag, in EUR (number)\n'
            '- "expiryDate": expiry/best-before date if visible, in ISO 8601 format YYYY-MM-DD (string)\n'
            '- "barcode": barcode or EAN number if visible (string)\n'
            'Respond with ONLY the JSON object, no markdown fences.',
          ),
          DataPart(mimeType, imageBytes),
        ]),
      ]);
      final text = response.text?.trim();
      if (text == null || text.isEmpty) return null;
      // Strip markdown fences if present
      final cleaned = text
          .replaceAll(RegExp(r'^```json?\s*|\s*```$'), '')
          .trim();
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Generate a structured recipe from a plain-language prompt.
  /// Returns a JSON map matching the Recipe field schema, or null on failure.
  Future<Map<String, dynamic>?> generateRecipe(String prompt) async {
    if (!isConfigured) return null;
    try {
      final response = await _getModel().generateContent([
        Content.text(
          'You are a recipe creation assistant. Create a detailed recipe based on the following request:\n\n'
          '$prompt\n\n'
          'Return ONLY a JSON object with these fields (omit optional fields you cannot determine):\n'
          '- "title": recipe title (string, required)\n'
          '- "description": brief one-sentence description (string)\n'
          '- "servings": number of servings (int)\n'
          '- "prepTimeMinutes": preparation time in minutes (int)\n'
          '- "cookTimeMinutes": cooking time in minutes (int)\n'
          '- "ingredients": list of objects with "name" (string, required), "quantity" (number, optional), "unit" (string, optional)\n'
          '- "instructions": list of objects with "text" (string, required)\n'
          '- "tags": list of lowercase category tags such as cuisine or dietary info (list of strings)\n'
          '- "notes": helpful tips or variations (string)\n'
          'Respond with ONLY the JSON object, no markdown fences.',
        ),
      ]);
      final text = response.text?.trim();
      if (text == null || text.isEmpty) return null;
      final cleaned = text
          .replaceAll(RegExp(r'^```json?\s*|\s*```$'), '')
          .trim();
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Apply an AI instruction to a markdown document and return the result.
  Future<String> editMarkdown(String content, String instruction) async {
    if (!isConfigured) return content;
    try {
      final response = await _getModel().generateContent([
        Content.text(
          'You are a markdown editor assistant. Apply the following instruction to the markdown content below.\n\n'
          'INSTRUCTION: $instruction\n\n'
          'MARKDOWN:\n$content\n\n'
          'Return ONLY the modified markdown, no explanations, no code fences.',
        ),
      ]);
      final result = response.text?.trim();
      return (result == null || result.isEmpty) ? content : result;
    } catch (e) {
      rethrow;
    }
  }

  void resetChat() {
    _chat = null;
  }
}
