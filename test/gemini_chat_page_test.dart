import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/gemini/pages/gemini_chat_page.dart';
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

/// Replays canned [responses] in order, one per [sendMessage] call —
/// either a reply string or an exception to throw (BUG-0049).
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

Future<void> _pump(WidgetTester tester, GeminiService service) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        geminiApiKeyServiceProvider.overrideWithValue(
          _AlwaysConfiguredApiKeyService(),
        ),
        geminiServiceProvider.overrideWithValue(service),
        geminiModelProvider.overrideWithValue(GeminiService.defaultModel),
        geminiAuthModeProvider.overrideWithValue(GeminiAuthMode.apiKey),
      ],
      child: const MaterialApp(home: GeminiChatPage()),
    ),
  );
}

void main() {
  group('GeminiChatPage retry (BUG-0049)', () {
    testWidgets('a failed message shows a Retry button on its bubble', (
      tester,
    ) async {
      final service = _ScriptedGeminiService([Exception('network blip')]);
      await _pump(tester, service);

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('Hello'), findsOneWidget);
      expect(find.textContaining('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('tapping Retry resends without retyping and without '
        'duplicating the message', (tester) async {
      final service = _ScriptedGeminiService([
        Exception('network blip'),
        'General Kenobi!',
      ]);
      await _pump(tester, service);

      await tester.enterText(find.byType(TextField), 'Hello there');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Hello there'), findsOneWidget);
      expect(find.text('General Kenobi!'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(service.calls, 2);
    });
  });
}
