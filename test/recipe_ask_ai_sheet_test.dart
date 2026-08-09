import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/gemini/providers/gemini_providers.dart';
import 'package:personal_app/features/gemini/services/gemini_api_key_service.dart';
import 'package:personal_app/features/gemini/services/gemini_service.dart';
import 'package:personal_app/features/recipes/models/recipe.dart';
import 'package:personal_app/features/recipes/widgets/recipe_ask_ai_sheet.dart';
import 'package:personal_app/features/settings/providers/settings_providers.dart';

/// Never has a key, and never touches secure storage (unlike the real
/// service) — keeps this test free of platform-channel dependencies.
class _NeverConfiguredApiKeyService implements GeminiApiKeyService {
  @override
  Future<String> getApiKey() async => '';

  @override
  Future<void> setApiKey(String apiKey) async {}

  @override
  Future<void> clearApiKey() async {}

  @override
  Future<bool> hasStoredKey() async => false;
}

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

/// Replays canned [responses] in order, one per [askAboutRecipe] call —
/// either an answer string or an exception to throw (BUG-0049).
class _ScriptedGeminiService implements GeminiService {
  final List<Object> responses;
  int calls = 0;
  _ScriptedGeminiService(this.responses);

  @override
  void configure(String apiKey, {String? model}) {}

  @override
  bool get isConfigured => true;

  @override
  Future<String> askAboutRecipe(
    Map<String, dynamic> recipeContext,
    List<({bool isUser, String text})> history,
    String question,
  ) async {
    final result = responses[calls];
    calls++;
    if (result is Exception) throw result;
    return result as String;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final recipe = Recipe(title: 'Pancakes', description: 'Fluffy pancakes');

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          geminiApiKeyServiceProvider.overrideWithValue(
            _NeverConfiguredApiKeyService(),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => RecipeAskAiSheet(recipe: recipe),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> openConfiguredSheet(
    WidgetTester tester,
    GeminiService service,
  ) async {
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
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => RecipeAskAiSheet(recipe: recipe),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  group('RecipeAskAiSheet (WISH-0092)', () {
    testWidgets('shows the recipe title and suggestion chips', (tester) async {
      await openSheet(tester);

      expect(find.text('Ask AI about this recipe'), findsOneWidget);
      expect(find.text('Pancakes'), findsOneWidget);
      expect(find.text('Ingredient substitutions?'), findsOneWidget);
      expect(find.text('Make it healthier'), findsOneWidget);
      expect(find.text('Pairing suggestions'), findsOneWidget);
    });

    testWidgets('tapping a suggestion asks the question and shows the '
        'not-configured fallback', (tester) async {
      await openSheet(tester);

      await tester.tap(find.text('Make it healthier'));
      await tester.pumpAndSettle();

      expect(
        find.text('How could I make this recipe healthier?'),
        findsOneWidget,
      );
      expect(find.textContaining('Gemini is not configured'), findsOneWidget);
      // The suggestion chips are replaced by the conversation view.
      expect(find.text('Ingredient substitutions?'), findsNothing);
    });

    testWidgets('typing a question and pressing send shows the same '
        'fallback', (tester) async {
      await openSheet(tester);

      await tester.enterText(
        find.byType(TextField),
        'Can I use oat milk instead?',
      );
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('Can I use oat milk instead?'), findsOneWidget);
      expect(find.textContaining('Gemini is not configured'), findsOneWidget);
    });

    testWidgets('the close button dismisses the sheet', (tester) async {
      await openSheet(tester);
      expect(find.text('Ask AI about this recipe'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Ask AI about this recipe'), findsNothing);
    });
  });

  group('RecipeAskAiSheet retry (BUG-0049)', () {
    testWidgets('a failed question shows a Retry button', (tester) async {
      final service = _ScriptedGeminiService([Exception('network blip')]);
      await openConfiguredSheet(tester, service);

      await tester.tap(find.text('Make it healthier'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(service.calls, 1);
    });

    testWidgets('tapping Retry resends the same question without '
        'duplicating the user bubble', (tester) async {
      final service = _ScriptedGeminiService([
        Exception('network blip'),
        'Try low-fat yogurt instead of cream.',
      ]);
      await openConfiguredSheet(tester, service);

      await tester.tap(find.text('Make it healthier'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(
        find.text('How could I make this recipe healthier?'),
        findsOneWidget,
      );
      expect(find.text('Try low-fat yogurt instead of cream.'), findsOneWidget);
      expect(find.textContaining('Something went wrong'), findsNothing);
      expect(find.text('Retry'), findsNothing);
      expect(service.calls, 2);
    });
  });
}
