import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../gemini/providers/gemini_providers.dart';
import '../../gemini/services/gemini_service.dart';
import '../models/recipe.dart';

/// Modal Q&A sheet for asking Gemini about an existing recipe (WISH-0092).
/// Deliberately separate from "Create with AI" / "Edit with AI": every
/// answer is read-only — nothing here is ever applied back to [recipe].
/// The conversation lives only in this sheet's local state and is
/// discarded when it's closed.
class RecipeAskAiSheet extends HookConsumerWidget {
  final Recipe recipe;
  const RecipeAskAiSheet({super.key, required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = useState<List<ChatMessage>>(const []);
    final isSending = useState(false);
    final inputController = useTextEditingController();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, sheetScrollController) {
        // Reusing the sheet's own controller (rather than a separate one)
        // is what lets dragging from within the message list also resize
        // the sheet, matching RecipePickerSheet's convention.
        void scrollToBottom() {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (sheetScrollController.hasClients) {
              sheetScrollController.animateTo(
                sheetScrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }

        // Runs the actual request + appends the reply (or a retryable error
        // bubble) without touching the user's question bubble — shared by
        // [send] (fresh question) and [retry] (BUG-0049: resend the same
        // question after a failure without retyping it).
        Future<void> ask(
          String text,
          List<({bool isUser, String text})> priorHistory,
        ) async {
          isSending.value = true;
          scrollToBottom();

          final ready = await configureGeminiForCurrentSettings(ref);
          if (!ready) {
            messages.value = [
              ...messages.value,
              ChatMessage(
                text: 'Gemini is not configured. Set it up in Settings → AI.',
                isUser: false,
              ),
            ];
            isSending.value = false;
            scrollToBottom();
            return;
          }

          final service = ref.read(geminiServiceProvider);
          try {
            final answer = await service.askAboutRecipe(
              _recipeContext(recipe),
              priorHistory,
              text,
            );
            messages.value = [
              ...messages.value,
              ChatMessage(text: answer, isUser: false),
            ];
          } on GeminiScopeException catch (e) {
            ref.read(geminiOAuthConnectedProvider.notifier).state = false;
            messages.value = [
              ...messages.value,
              ChatMessage(text: e.message, isUser: false, isError: true),
            ];
          } on GeminiRateLimitException catch (e) {
            messages.value = [
              ...messages.value,
              ChatMessage(
                text: humanizeGeminiRateLimit(e),
                isUser: false,
                isError: true,
              ),
            ];
          } catch (e) {
            messages.value = [
              ...messages.value,
              ChatMessage(
                text: 'Something went wrong: $e',
                isUser: false,
                isError: true,
              ),
            ];
          } finally {
            isSending.value = false;
            scrollToBottom();
          }
        }

        Future<void> send([String? suggested]) async {
          final text = (suggested ?? inputController.text).trim();
          if (text.isEmpty || isSending.value) return;
          inputController.clear();

          // Snapshot prior turns before appending the new question —
          // that's the "history" the service replays; the question is
          // passed separately.
          final priorHistory = messages.value
              .map((m) => (isUser: m.isUser, text: m.text))
              .toList();

          messages.value = [
            ...messages.value,
            ChatMessage(text: text, isUser: true),
          ];
          await ask(text, priorHistory);
        }

        Future<void> retry() async {
          final current = messages.value;
          if (current.isEmpty || !current.last.isError) return;
          final withoutError = current.sublist(0, current.length - 1);
          if (withoutError.isEmpty || !withoutError.last.isUser) return;

          final priorHistory = withoutError
              .sublist(0, withoutError.length - 1)
              .map((m) => (isUser: m.isUser, text: m.text))
              .toList();
          final retryText = withoutError.last.text;
          messages.value = withoutError;
          await ask(retryText, priorHistory);
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ask AI about this recipe',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          recipe.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: messages.value.isEmpty
                  ? _Suggestions(onTap: send)
                  : ListView.builder(
                      controller: sheetScrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.value.length,
                      itemBuilder: (context, index) {
                        final msg = messages.value[index];
                        final isLast = index == messages.value.length - 1;
                        return _QaBubble(
                          message: msg,
                          onRetry: msg.isError && isLast && !isSending.value
                              ? retry
                              : null,
                        );
                      },
                    ),
            ),
            if (isSending.value) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.all(8),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: inputController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Can I substitute the butter?',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: isSending.value ? null : () => send(),
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Curated, read-only context sent to the model — recipe content only
/// (no ids, images, timestamps, or personal flags like isFavorite).
Map<String, dynamic> _recipeContext(Recipe recipe) => {
  'title': recipe.title,
  if (recipe.description != null) 'description': recipe.description,
  if (recipe.servings != null) 'servings': recipe.servings,
  if (recipe.prepTimeMinutes != null) 'prepTimeMinutes': recipe.prepTimeMinutes,
  if (recipe.cookTimeMinutes != null) 'cookTimeMinutes': recipe.cookTimeMinutes,
  'ingredients': recipe.ingredients
      .map(
        (i) => {
          'name': i.name,
          if (i.quantity != null) 'quantity': i.quantity,
          if (i.unit != null) 'unit': i.unit,
        },
      )
      .toList(),
  'instructions': recipe.instructions.map((s) => s.text).toList(),
  if (recipe.tags.isNotEmpty) 'tags': recipe.tags,
  if (recipe.notes != null) 'notes': recipe.notes,
  if (recipe.source != null) 'source': recipe.source,
};

class _Suggestions extends StatelessWidget {
  final void Function(String) onTap;
  const _Suggestions({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 56,
              color: colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Ask anything about this recipe',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Answers never change the saved recipe',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ActionChip(
                  label: const Text('Ingredient substitutions?'),
                  onPressed: () => onTap(
                    'What can I substitute in this recipe, and for what?',
                  ),
                ),
                ActionChip(
                  label: const Text('Make it healthier'),
                  onPressed: () =>
                      onTap('How could I make this recipe healthier?'),
                ),
                ActionChip(
                  label: const Text('Pairing suggestions'),
                  onPressed: () =>
                      onTap('What would pair well with this dish?'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QaBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;
  const _QaBubble({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    final isError = message.isError;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primaryContainer
              : isError
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUser)
              Text(message.text)
            else if (isError)
              Text(
                message.text,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              )
            else
              MarkdownBody(data: message.text),
            if (onRetry != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.onErrorContainer,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
