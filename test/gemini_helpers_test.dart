import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/gemini/services/gemini_service.dart';

void main() {
  group('isGeminiRateLimitError', () {
    test('matches the real quota message from BUG-0030', () {
      const msg =
          'You exceeded your current quota, please check your plan and billing details. '
          'For more information on this error, head to: '
          'https://ai.google.dev/gemini-api/docs/rate-limits.';
      expect(isGeminiRateLimitError(msg), isTrue);
    });

    test('matches "rate limit" wording', () {
      expect(isGeminiRateLimitError('rate limit reached'), isTrue);
      expect(isGeminiRateLimitError('rate-limit reached'), isTrue);
    });

    test('matches HTTP 429 in the body', () {
      expect(isGeminiRateLimitError('HTTP 429 Too Many Requests'), isTrue);
    });

    test('is case-insensitive', () {
      expect(isGeminiRateLimitError('QUOTA exceeded'), isTrue);
      expect(isGeminiRateLimitError('Rate Limit Reached'), isTrue);
    });

    test('accepts non-String error objects via toString()', () {
      final ex = Exception('429 quota exceeded');
      expect(isGeminiRateLimitError(ex), isTrue);
    });

    test('rejects unrelated errors', () {
      expect(isGeminiRateLimitError('Network unreachable'), isFalse);
      expect(isGeminiRateLimitError('Bad request'), isFalse);
      expect(isGeminiRateLimitError(''), isFalse);
    });
  });

  group('parseGeminiRetryAfter', () {
    test('parses fractional retry hint from the real BUG-0030 message', () {
      const msg = 'Please retry in 45.911023847s.';
      final d = parseGeminiRetryAfter(msg);
      expect(d, isNotNull);
      expect(d!.inMilliseconds, 45911);
    });

    test('parses an integer retry hint', () {
      final d = parseGeminiRetryAfter('retry in 30s');
      expect(d, const Duration(seconds: 30));
    });

    test('tolerates whitespace between number and the s suffix', () {
      final d = parseGeminiRetryAfter('retry in 5 s now');
      expect(d, const Duration(seconds: 5));
    });

    test('returns null when no retry hint is present', () {
      expect(parseGeminiRetryAfter('quota exceeded'), isNull);
      expect(parseGeminiRetryAfter(''), isNull);
    });
  });

  group('stripCodeFences', () {
    test('strips a ```json ... ``` fence', () {
      const raw = '```json\n{"title": "x"}\n```';
      expect(stripCodeFences(raw), '{"title": "x"}');
    });

    test('strips a bare ``` ... ``` fence', () {
      const raw = '```\n{"title": "x"}\n```';
      expect(stripCodeFences(raw), '{"title": "x"}');
    });

    test('leaves un-fenced JSON untouched', () {
      const raw = '{"title": "x"}';
      expect(stripCodeFences(raw), '{"title": "x"}');
    });

    test(
      'handles the BUG-0029 case (trailing fence without inline newline)',
      () {
        const raw = '```json{"title":"x"}```';
        expect(stripCodeFences(raw), '{"title":"x"}');
      },
    );

    test('trims surrounding whitespace', () {
      const raw = '  \n  {"title": "x"}  \n  ';
      expect(stripCodeFences(raw), '{"title": "x"}');
    });

    test('does not strip a literal "json" prefix when no fence is present', () {
      const raw = 'json{"title":"x"}';
      // No leading ```, so the prefix stays intact.
      expect(stripCodeFences(raw), 'json{"title":"x"}');
    });
  });
}
