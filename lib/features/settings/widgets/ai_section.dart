import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/widgets/api_key_vault_dialog.dart';
import '../../../presentation/widgets/app_snackbar.dart';
import '../../auth/providers/auth_providers.dart';
import '../../gemini/providers/gemini_providers.dart';
import '../../gemini/services/gemini_service.dart';
import '../providers/settings_providers.dart';
import 'section_header.dart';

class AiSection extends ConsumerWidget {
  const AiSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader('AI'),
        const _GeminiAuthModeTile(),
        if (user.settings.geminiAuthMode == 'oauth') ...[
          const _OAuthBillingWarning(),
          const _GeminiOAuthTile(),
        ] else
          const _GeminiApiKeyTile(),
        const _GeminiModelTile(),
      ],
    );
  }
}

class _GeminiAuthModeTile extends ConsumerWidget {
  const _GeminiAuthModeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final mode = user.settings.geminiAuthMode;
    return ListTile(
      leading: const Icon(Icons.vpn_key_outlined),
      title: const Text('Authentication mode'),
      subtitle: Text(
        mode == 'oauth'
            ? 'Sign in with Google — runs against the app developer’s '
                  'Gemini project'
            : 'API key — uses the AI Studio key you configure below '
                  '(your own project)',
      ),
      onTap: () => _show(context, ref, mode),
    );
  }

  void _show(BuildContext context, WidgetRef ref, String current) {
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Gemini authentication'),
        children: [
          RadioGroup<String>(
            groupValue: current,
            onChanged: (v) => _select(ctx, ref, v),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  value: 'apiKey',
                  title: Text('API key'),
                  subtitle: Text(
                    'Paste a key from Google AI Studio. Quota counts '
                    'against the project that owns the key.',
                  ),
                ),
                RadioListTile<String>(
                  value: 'oauth',
                  title: Text('Sign in with Google'),
                  subtitle: Text(
                    'No key to manage. Note: requests run against the '
                    'app developer’s Gemini Cloud project, not yours — '
                    'choose API key if you want your own quota / models. '
                    'Grants the generative-language.retriever scope.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _select(BuildContext ctx, WidgetRef ref, String? value) async {
    if (value == null) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final updated = user.copyWith(
      settings: user.settings.copyWith(geminiAuthMode: value),
    );
    await ref.read(authServiceProvider).updateProfile(updated);
    if (ctx.mounted) Navigator.pop(ctx);
  }
}

/// Inline notice shown above the OAuth sign-in tile so users can't
/// miss that the OAuth path runs against the app developer's Gemini
/// project, not their own (BUG-0036 follow-up).
class _OAuthBillingWarning extends StatelessWidget {
  const _OAuthBillingWarning();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Gemini requests on this path run against the app developer’s '
              'Cloud project — not your own. Quota, billing, and the '
              'available model list all come from there. Switch to API key '
              'mode (above) if you want to use your own Google project.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _GeminiOAuthTile extends ConsumerWidget {
  const _GeminiOAuthTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(geminiOAuthConnectedProvider);
    final oauth = ref.watch(geminiOAuthServiceProvider);
    final email = oauth.account?.email;
    return ListTile(
      leading: Icon(
        Icons.account_circle_outlined,
        color: connected ? Colors.green : null,
      ),
      title: Text(connected ? 'Connected' : 'Sign in with Google'),
      subtitle: Text(
        connected
            ? (email ?? 'OAuth active')
            : 'Grant Gemini access to your Google account',
      ),
      trailing: connected
          ? IconButton(
              icon: Icon(
                Icons.logout,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: 'Disconnect',
              onPressed: () async {
                await oauth.disconnect();
                ref.read(geminiOAuthConnectedProvider.notifier).state = false;
              },
            )
          : const Icon(Icons.login),
      onTap: connected
          ? null
          : () async {
              final success = await oauth.signIn();
              ref.read(geminiOAuthConnectedProvider.notifier).state = success;
              if (!success && context.mounted) {
                context.showErrorSnackbar(
                  'Gemini OAuth sign-in failed or was cancelled',
                );
              }
            },
    );
  }
}

class _GeminiApiKeyTile extends ConsumerWidget {
  const _GeminiApiKeyTile();

  static const _vaultEntryTitle = 'Gemini API Key';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasKey = ref.watch(geminiApiKeyAvailableProvider);

    return ListTile(
      leading: const Icon(Icons.key),
      title: const Text('Gemini API Key'),
      subtitle: Text(
        hasKey.when(
          data: (available) => available ? 'Key configured' : 'Not set',
          loading: () => 'Checking...',
          error: (_, _) => 'Error',
        ),
      ),
      trailing: hasKey.valueOrNull == true
          ? IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: 'Remove key',
              onPressed: () async {
                await ref.read(geminiApiKeyServiceProvider).clearApiKey();
                ref.invalidate(geminiApiKeyAvailableProvider);
                ref.read(geminiServiceProvider).configure('');
              },
            )
          : null,
      onTap: () => _showApiKeyDialog(context, ref),
    );
  }

  Future<void> _showApiKeyDialog(BuildContext context, WidgetRef ref) {
    return showApiKeyVaultDialog(
      context: context,
      ref: ref,
      spec: const ApiKeyVaultSpec(
        serviceName: 'Gemini',
        dialogTitle: 'Gemini API Key',
        fieldLabel: 'API Key',
        vaultEntryTitle: _vaultEntryTitle,
        vaultMatch: 'gemini',
        vaultEntryUrl: 'https://aistudio.google.com/apikey',
      ),
      onSaved: (key) async {
        await ref.read(geminiApiKeyServiceProvider).setApiKey(key);
        ref.invalidate(geminiApiKeyAvailableProvider);
        ref.read(geminiServiceProvider).configure(key);
      },
    );
  }
}

class _GeminiModelTile extends ConsumerWidget {
  const _GeminiModelTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentModel = ref.watch(geminiModelProvider);

    return ListTile(
      leading: const Icon(Icons.smart_toy),
      title: const Text('Gemini Model'),
      subtitle: Text(currentModel),
      onTap: () => _showModelPicker(context, ref, currentModel),
    );
  }

  void _showModelPicker(BuildContext context, WidgetRef ref, String current) {
    showDialog(
      context: context,
      builder: (ctx) => _GeminiModelPickerDialog(
        current: current,
        onSelected: (id) {
          final user = ref.read(currentUserProvider)!;
          final updated = user.copyWith(
            settings: user.settings.copyWith(geminiModel: id),
          );
          ref.read(authServiceProvider).updateProfile(updated);
          ref.read(geminiServiceProvider).setModel(id);
        },
        geminiService: ref.read(geminiServiceProvider),
      ),
    );
  }
}

class _GeminiModelPickerDialog extends StatefulWidget {
  final String current;
  final ValueChanged<String> onSelected;
  final GeminiService geminiService;

  const _GeminiModelPickerDialog({
    required this.current,
    required this.onSelected,
    required this.geminiService,
  });

  @override
  State<_GeminiModelPickerDialog> createState() =>
      _GeminiModelPickerDialogState();
}

class _GeminiModelPickerDialogState extends State<_GeminiModelPickerDialog> {
  List<({String id, String displayName})>? _models;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchModels();
  }

  Future<void> _fetchModels() async {
    final models = await widget.geminiService.listModels();
    if (mounted) {
      setState(() {
        _models = models.isEmpty ? null : models;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Gemini Model'),
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_models == null)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Could not fetch models. Check your API key.',
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final model in _models!)
            ListTile(
              title: Text(model.displayName),
              subtitle: Text(model.id),
              trailing: widget.current == model.id
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                widget.onSelected(model.id);
                Navigator.pop(context);
              },
            ),
      ],
    );
  }
}
