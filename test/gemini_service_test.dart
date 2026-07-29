import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/gemini/services/gemini_service.dart';

void main() {
  group('GeminiService.askAboutRecipe (WISH-0092)', () {
    test('returns a not-configured message without making a request', () async {
      final service = GeminiService();
      final answer = await service.askAboutRecipe(
        {'title': 'Pancakes'},
        const [],
        'Can I use oat milk instead?',
      );
      expect(answer, contains('not configured'));
    });
  });

  group('humanizeGeminiRateLimit', () {
    test('extracts the message from a JSON error body', () {
      final body = jsonEncode({
        'error': {'message': 'Please retry in 12s.'},
      });
      final result = humanizeGeminiRateLimit(GeminiRateLimitException(body));
      expect(result, contains('Please retry in 12s.'));
      expect(result, contains('Settings → AI → Gemini Model'));
    });

    test('falls back to the raw body when it is not JSON', () {
      final result = humanizeGeminiRateLimit(
        const GeminiRateLimitException('quota exceeded, try later'),
      );
      expect(result, contains('quota exceeded, try later'));
      expect(result, contains('Settings → AI → Gemini Model'));
    });

    test('falls back to the raw body when JSON has no error.message', () {
      final body = jsonEncode({'other': 'field'});
      final result = humanizeGeminiRateLimit(GeminiRateLimitException(body));
      expect(result, contains(body));
    });
  });
}
