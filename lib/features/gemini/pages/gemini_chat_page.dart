import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';

import '../providers/gemini_providers.dart';

class GeminiChatPage extends ConsumerStatefulWidget {
  const GeminiChatPage({super.key});

  @override
  ConsumerState<GeminiChatPage> createState() => _GeminiChatPageState();
}

class _GeminiChatPageState extends ConsumerState<GeminiChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    _controller.clear();
    setState(() => _isSending = true);

    await ref.read(geminiChatProvider.notifier).sendMessage(text);

    setState(() => _isSending = false);
    _scrollToBottom();
  }

  Future<void> _retry() async {
    setState(() => _isSending = true);
    await ref.read(geminiChatProvider.notifier).retryLast();
    setState(() => _isSending = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(geminiChatProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Gemini AI')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Clear chat',
            onPressed: () => ref.read(geminiChatProvider.notifier).clearChat(),
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            if (ref.watch(geminiApiKeyAvailableProvider).valueOrNull == false)
              MaterialBanner(
                content: const Text(
                  'No Gemini API key configured. Add one in Settings or in your dotenv file.',
                ),
                leading: const Icon(Icons.warning_amber, color: Colors.orange),
                actions: [
                  TextButton(onPressed: () {}, child: const Text('Dismiss')),
                ],
              ),
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 64,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Ask Gemini anything',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _SuggestionChip(
                                label: 'Meal plan for the week',
                                onTap: () {
                                  _controller.text =
                                      'Suggest a meal plan for this week';
                                  _send();
                                },
                              ),
                              _SuggestionChip(
                                label: 'Organize my tasks',
                                onTap: () {
                                  _controller.text =
                                      'How should I organize my tasks for better productivity?';
                                  _send();
                                },
                              ),
                              _SuggestionChip(
                                label: 'Budget tips',
                                onTap: () {
                                  _controller.text =
                                      'Give me some practical budgeting tips';
                                  _send();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isLast = index == messages.length - 1;
                        return _ChatBubble(
                          message: msg,
                          onRetry: msg.isError && isLast && !_isSending
                              ? _retry
                              : null,
                        );
                      },
                    ),
            ),
            if (_isSending) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.all(8),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Ask Gemini...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _isSending ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;
  const _ChatBubble({required this.message, this.onRetry});

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

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}
