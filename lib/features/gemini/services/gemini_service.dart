import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../services/log_service.dart';
import 'gemini_oauth_service.dart';

/// Authentication mode for the Gemini API.
///
/// - [apiKey]: the user enters a Google AI Studio key in Settings; quota
///   counts against the project that owns the key. The request URL gets
///   a `?key=...` query parameter.
/// - [oauth]: the user signs in with their Google account
///   (`generative-language.retriever` scope, the one accepted by
///   `generativelanguage.googleapis.com` — see BUG-0036). Quota counts
///   against their Google account; the request gets an
///   `Authorization: Bearer <token>` header.
enum GeminiAuthMode { apiKey, oauth }

/// Thrown when a Gemini OAuth call comes back with HTTP 403 +
/// `ACCESS_TOKEN_SCOPE_INSUFFICIENT`. The cached token doesn't include a
/// scope `generativelanguage.googleapis.com` will accept; the user has
/// to disconnect + reconnect Gemini OAuth in Settings (BUG-0036).
class GeminiScopeException implements Exception {
  final String message;
  const GeminiScopeException([
    this.message =
        'Gemini OAuth is missing the required scope. '
        'Open Settings → AI, disconnect, then sign in again.',
  ]);
  @override
  String toString() => message;
}

/// Thrown when a Gemini call fails due to API quota/rate limiting.
/// Callers should surface a clear message and link the user to
/// https://ai.dev/rate-limit so they can monitor their usage.
class GeminiRateLimitException implements Exception {
  final String message;
  final Duration? retryAfter;
  const GeminiRateLimitException(this.message, {this.retryAfter});
  @override
  String toString() => message;
}

/// True when [error] looks like a Gemini API rate-limit / quota error.
/// Matches any of: `quota`, `rate limit`, `rate-limit`, `429`, or
/// `exceeded your current quota` (case-insensitive). Accepts any type
/// (`String`, `Exception`, raw HTTP response body…) — calls `toString()`.
bool isGeminiRateLimitError(Object error) {
  final msg = error.toString().toLowerCase();
  return msg.contains('quota') ||
      msg.contains('rate limit') ||
      msg.contains('rate-limit') ||
      msg.contains('429') ||
      msg.contains('exceeded your current quota');
}

/// Parses a "Please retry in X.Ys" hint out of a Gemini error message
/// and returns it as a [Duration]. Returns null when no such hint is
/// present.
Duration? parseGeminiRetryAfter(String message) {
  final match = RegExp(r'retry in ([\d.]+)\s*s').firstMatch(message);
  final seconds = double.tryParse(match?.group(1) ?? '');
  if (seconds == null) return null;
  return Duration(milliseconds: (seconds * 1000).round());
}

/// Strips a leading ` ```json ` or ` ``` ` fence and a trailing ` ``` `
/// fence from [text]. Used to clean up generateContent responses where
/// the model wrapped its JSON in markdown despite being asked not to.
String stripCodeFences(String text) {
  return text
      .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
      .replaceFirst(RegExp(r'\s*```\s*$'), '')
      .trim();
}

class GeminiService {
  static const defaultModel = 'gemini-2.5-flash';
  static const _apiBase = 'https://generativelanguage.googleapis.com/v1beta';

  GeminiAuthMode _authMode = GeminiAuthMode.apiKey;
  String? _apiKey;
  GeminiOAuthService? _oauth;
  String _modelName = defaultModel;
  final List<Map<String, dynamic>> _chatHistory = [];

  bool get isConfigured {
    switch (_authMode) {
      case GeminiAuthMode.apiKey:
        return _apiKey != null && _apiKey!.isNotEmpty;
      case GeminiAuthMode.oauth:
        return _oauth != null && _oauth!.account != null;
    }
  }

  /// Configure with an API key. Switches the service to [GeminiAuthMode.apiKey].
  void configure(String apiKey, {String? model}) {
    final newModel = model ?? _modelName;
    if (_authMode != GeminiAuthMode.apiKey ||
        apiKey != _apiKey ||
        newModel != _modelName) {
      _authMode = GeminiAuthMode.apiKey;
      _apiKey = apiKey;
      _modelName = newModel;
      _chatHistory.clear();
    }
  }

  /// Configure with a Gemini OAuth account. Switches the service to
  /// [GeminiAuthMode.oauth]. The `oauth` service is expected to have a
  /// signed-in account; if not, [isConfigured] returns false and calls
  /// will be no-ops.
  void configureOauth(GeminiOAuthService oauth, {String? model}) {
    final newModel = model ?? _modelName;
    if (_authMode != GeminiAuthMode.oauth ||
        !identical(_oauth, oauth) ||
        newModel != _modelName) {
      _authMode = GeminiAuthMode.oauth;
      _oauth = oauth;
      _modelName = newModel;
      _chatHistory.clear();
    }
  }

  void setModel(String model) {
    if (model != _modelName) {
      _modelName = model;
      _chatHistory.clear();
    }
  }

  void resetChat() {
    _chatHistory.clear();
  }

  /// Build the URI for an API endpoint, appending `?key=...` for API-key mode.
  Uri _uri(String path) {
    if (_authMode == GeminiAuthMode.apiKey) {
      return Uri.parse('$_apiBase$path?key=$_apiKey');
    }
    return Uri.parse('$_apiBase$path');
  }

  /// Build the headers for a Gemini API request, attaching a Bearer token
  /// for OAuth mode. Returns null if OAuth mode is selected but we can't
  /// obtain auth headers (user not signed in).
  Future<Map<String, String>?> _headers({bool json = true}) async {
    final headers = <String, String>{
      if (json) 'Content-Type': 'application/json',
    };
    if (_authMode == GeminiAuthMode.oauth) {
      final oauthHeaders = await _oauth?.authHeaders();
      if (oauthHeaders == null) return null;
      headers.addAll(oauthHeaders);
    }
    return headers;
  }

  /// POST to a `:method` endpoint on a model (e.g. `generateContent`).
  /// Throws [GeminiRateLimitException] on 429/quota responses. Returns
  /// the parsed JSON body on success or null on any other failure.
  Future<Map<String, dynamic>?> _postModel(
    String method,
    Map<String, dynamic> body, {
    String? op,
  }) async {
    if (!isConfigured) {
      LogService.instance.warning(
        'Gemini ${op ?? method} called but service is not configured '
        '(mode=${_authMode.name})',
      );
      return null;
    }
    final headers = await _headers();
    if (headers == null) {
      LogService.instance.warning(
        'Gemini ${op ?? method}: no auth headers available (mode=${_authMode.name})',
      );
      return null;
    }
    final uri = _uri('/models/$_modelName:$method');
    final http.Response response;
    try {
      response = await http.post(uri, headers: headers, body: jsonEncode(body));
    } catch (e, st) {
      LogService.instance.error('Gemini ${op ?? method} HTTP error: $e\n$st');
      return null;
    }
    if (response.statusCode == 429 ||
        (response.statusCode >= 400 && isGeminiRateLimitError(response.body))) {
      LogService.instance.error(
        'Gemini ${op ?? method} rate-limited (${response.statusCode}): ${response.body}',
      );
      throw GeminiRateLimitException(
        response.body,
        retryAfter: parseGeminiRetryAfter(response.body),
      );
    }
    if (response.statusCode == 403 &&
        response.body.contains('ACCESS_TOKEN_SCOPE_INSUFFICIENT')) {
      LogService.instance.error(
        'Gemini ${op ?? method}: OAuth scope insufficient — '
        'auto-disconnecting so the user can re-authorize (BUG-0036)',
      );
      await _oauth?.markStale();
      throw const GeminiScopeException();
    }
    if (response.statusCode != 200) {
      LogService.instance.error(
        'Gemini ${op ?? method} failed (${response.statusCode}): ${response.body}',
      );
      return null;
    }
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      LogService.instance.error(
        'Gemini ${op ?? method}: response was not JSON: $e\n${response.body}',
      );
      return null;
    }
  }

  /// Extract the first text candidate from a generateContent response.
  String? _firstText(Map<String, dynamic> response) {
    final candidates = response['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return null;
    final content =
        (candidates.first as Map<String, dynamic>)['content']
            as Map<String, dynamic>?;
    if (content == null) return null;
    final parts = content['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) return null;
    final text = (parts.first as Map<String, dynamic>)['text'] as String?;
    return text;
  }

  /// Fetch available generative models from the Gemini API.
  /// Returns a list of (modelId, displayName) pairs.
  Future<List<({String id, String displayName})>> listModels() async {
    if (!isConfigured) return [];
    final headers = await _headers(json: false);
    if (headers == null) return [];
    final uri = _uri('/models');
    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode != 200) {
        LogService.instance.warning(
          'Gemini listModels failed (${response.statusCode}): ${response.body}',
        );
        return [];
      }
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
    } catch (e) {
      LogService.instance.error('Gemini listModels error: $e');
      return [];
    }
  }

  /// Chat-style message with history continuity.
  Future<String> sendMessage(String message) async {
    if (!isConfigured) {
      return 'Gemini is not configured. Set it up in Settings.';
    }
    if (_chatHistory.isEmpty) {
      _chatHistory.addAll([
        {
          'role': 'user',
          'parts': [
            {
              'text':
                  'You are a helpful personal assistant embedded in a life-management '
                  'app called "Personal App". You help with tasks, recipes, finances, '
                  'calendar planning, knowledge organization, and general questions. '
                  'Keep answers concise and practical.',
            },
          ],
        },
        {
          'role': 'model',
          'parts': [
            {
              'text':
                  "Understood! I'm ready to help you with anything in your Personal App.",
            },
          ],
        },
      ]);
    }
    _chatHistory.add({
      'role': 'user',
      'parts': [
        {'text': message},
      ],
    });
    try {
      final response = await _postModel('generateContent', {
        'contents': _chatHistory,
      }, op: 'sendMessage');
      if (response == null) {
        _chatHistory.removeLast();
        return 'No response received.';
      }
      final text = _firstText(response) ?? '';
      _chatHistory.add({
        'role': 'model',
        'parts': [
          {'text': text},
        ],
      });
      return text.isEmpty ? 'No response received.' : text;
    } catch (e) {
      _chatHistory.removeLast();
      if (e is GeminiRateLimitException) rethrow;
      if (e is GeminiScopeException) rethrow;
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
    final categoryHint = categories.isNotEmpty
        ? 'The user has these existing categories: ${categories.join(', ')}. '
              'Use one of these if the item fits, otherwise suggest a new category.\n'
        : '';
    final locationHint = locations.isNotEmpty
        ? 'The user has these existing locations: ${locations.join(', ')}. '
              'Use one of these if appropriate.\n'
        : '';
    final body = {
      'contents': [
        {
          'parts': [
            {
              'text':
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
            },
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Encode(imageBytes),
              },
            },
          ],
        },
      ],
    };
    try {
      final response = await _postModel(
        'generateContent',
        body,
        op: 'analyzeInventoryImage',
      );
      if (response == null) return null;
      final text = _firstText(response)?.trim();
      if (text == null || text.isEmpty) return null;
      final cleaned = stripCodeFences(text);
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      LogService.instance.error('Gemini analyzeInventoryImage error: $e');
      return null;
    }
  }

  static const _recipeSchema =
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
      'Respond with ONLY the JSON object, no markdown fences.';

  /// Generate a structured recipe from a plain-language prompt.
  /// Returns a JSON map matching the Recipe field schema, or null on failure.
  /// Failures are logged via [LogService] so the developer page surfaces them.
  Future<Map<String, dynamic>?> generateRecipe(String prompt) async {
    return _runRecipeAi(
      op: 'generateRecipe',
      promptBody:
          'You are a recipe creation assistant. Create a detailed recipe based on the following request:\n\n'
          '$prompt\n\n'
          '$_recipeSchema',
    );
  }

  /// Apply a user instruction to an existing recipe and return the updated
  /// recipe in the same JSON schema. Fields the user did not ask to change
  /// should be preserved by the model.
  Future<Map<String, dynamic>?> editRecipe(
    Map<String, dynamic> existing,
    String instruction,
  ) async {
    return _runRecipeAi(
      op: 'editRecipe',
      promptBody:
          'You are a recipe editing assistant. Apply the user\'s instruction '
          'to an existing recipe and return the updated recipe.\n\n'
          'EXISTING RECIPE (JSON):\n${jsonEncode(existing)}\n\n'
          'USER INSTRUCTION:\n$instruction\n\n'
          '$_recipeSchema\n'
          'Preserve fields the user did not ask to change.',
    );
  }

  Future<Map<String, dynamic>?> _runRecipeAi({
    required String op,
    required String promptBody,
  }) async {
    LogService.instance.info(
      'Gemini $op: requesting (model=$_modelName, '
      'authMode=${_authMode.name}, promptLen=${promptBody.length})',
    );
    final response = await _postModel('generateContent', {
      'contents': [
        {
          'parts': [
            {'text': promptBody},
          ],
        },
      ],
    }, op: op);
    if (response == null) return null;
    final text = _firstText(response)?.trim();
    if (text == null || text.isEmpty) {
      LogService.instance.error('Gemini $op: empty response from model');
      return null;
    }
    final cleaned = stripCodeFences(text);
    try {
      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
      LogService.instance.info('Gemini $op: success');
      return decoded;
    } on FormatException catch (e) {
      final preview = cleaned.length > 500
          ? '${cleaned.substring(0, 500)}…'
          : cleaned;
      LogService.instance.error(
        'Gemini $op: JSON parse failed: $e\nResponse: $preview',
      );
      return null;
    }
  }

  /// Apply an AI instruction to a markdown document and return the result.
  Future<String> editMarkdown(String content, String instruction) async {
    if (!isConfigured) return content;
    final response = await _postModel('generateContent', {
      'contents': [
        {
          'parts': [
            {
              'text':
                  'You are a markdown editor assistant. Apply the following instruction to the markdown content below.\n\n'
                  'INSTRUCTION: $instruction\n\n'
                  'MARKDOWN:\n$content\n\n'
                  'Return ONLY the modified markdown, no explanations, no code fences.',
            },
          ],
        },
      ],
    }, op: 'editMarkdown');
    if (response == null) return content;
    final result = _firstText(response)?.trim();
    return (result == null || result.isEmpty) ? content : result;
  }
}
