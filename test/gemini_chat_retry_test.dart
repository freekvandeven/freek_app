import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/gemini/providers/gemini_providers.dart';
import 'package:personal_app/features/gemini/services/gemini_api_key_service.dart';
import 'package:personal_app/features/gemini/services/gemini_service.dart';
import 'package:personal_app/features/settings/providers/settings_providers.dart';

class _AlwaysConfiguredApiKeyService implements GeminiApiKeyService {
  @override
  Future<String> getApiKey() async => 'test-key';

  @override
  Future<void> setApiKey(String apiKey) async {}

  @override
  Future<void> clearApiKey() async {}

  @override
  Future<bool> hasStoredKey() async => true;
}

/// Replays canned [_responses] in order, one per [sendMessage] call —
/// either a reply string or an exception to throw.
class _ScriptedGeminiService implements GeminiService {
  final List<Object> responses;
  int calls = 0;
  _ScriptedGeminiService(this.responses);

  @override
  void configure(String apiKey, {String? model}) {}

  @override
  bool get isConfigured => true;

  @override
  Future<String> sendMessage(String message) async {
    final result = responses[calls];
    calls++;
    if (result is Exception) throw result;
    return result as String;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _containerFor(GeminiService service) {
  final container = ProviderContainer(
    overrides: [
      geminiServiceProvider.overrideWithValue(service),
      geminiModelProvider.overrideWithValue(GeminiService.defaultModel),
      geminiAuthModeProvider.overrideWithValue(GeminiAuthMode.apiKey),
      geminiApiKeyServiceProvider.overrideWithValue(
        _AlwaysConfiguredApiKeyService(),
      ),
    ],
  );
  return container;
}

void main() {
  group('GeminiChatNotifier retry (BUG-0049)', () {
    test('a failed request appends a retryable error message', () async {
      final service = _ScriptedGeminiService([Exception('network blip')]);
      final container = _containerFor(service);
      addTearDown(container.dispose);

      await container.read(geminiChatProvider.notifier).sendMessage('Hello');

      final messages = container.read(geminiChatProvider);
      expect(messages, hasLength(2));
      expect(messages[0].isUser, isTrue);
      expect(messages[0].text, 'Hello');
      expect(messages[1].isUser, isFalse);
      expect(messages[1].isError, isTrue);
      expect(service.calls, 1);
    });

    test('retryLast resends the same message without duplicating it', () async {
      final service = _ScriptedGeminiService([
        Exception('network blip'),
        'Hi there!',
      ]);
      final container = _containerFor(service);
      addTearDown(container.dispose);

      final notifier = container.read(geminiChatProvider.notifier);
      await notifier.sendMessage('Hello');
      await notifier.retryLast();

      final messages = container.read(geminiChatProvider);
      expect(messages, hasLength(2));
      expect(messages[0].text, 'Hello');
      expect(messages[1].isError, isFalse);
      expect(messages[1].text, 'Hi there!');
      expect(service.calls, 2);
    });

    test('retryLast can be called again after a second failure', () async {
      final service = _ScriptedGeminiService([
        Exception('first failure'),
        Exception('second failure'),
        'Finally!',
      ]);
      final container = _containerFor(service);
      addTearDown(container.dispose);

      final notifier = container.read(geminiChatProvider.notifier);
      await notifier.sendMessage('Hello');
      await notifier.retryLast();
      await notifier.retryLast();

      final messages = container.read(geminiChatProvider);
      expect(messages, hasLength(2));
      expect(messages[1].text, 'Finally!');
      expect(service.calls, 3);
    });

    test('retryLast is a no-op when there is nothing to retry', () async {
      final service = _ScriptedGeminiService(['Hi there!']);
      final container = _containerFor(service);
      addTearDown(container.dispose);

      final notifier = container.read(geminiChatProvider.notifier);
      // Empty state.
      await notifier.retryLast();
      expect(container.read(geminiChatProvider), isEmpty);

      // Successful reply — last message isn't an error.
      await notifier.sendMessage('Hello');
      final beforeRetry = container.read(geminiChatProvider);
      await notifier.retryLast();
      expect(container.read(geminiChatProvider), beforeRetry);
      expect(service.calls, 1);
    });
  });
}
