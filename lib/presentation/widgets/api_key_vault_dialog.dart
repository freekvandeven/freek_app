import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/passwords/models/password_entry.dart';
import '../../features/passwords/providers/vault_providers.dart';
import 'app_snackbar.dart';

/// Describes one third-party API key that can be kept in the password
/// vault, so the "type it in, or load it from the vault" flow is written
/// once instead of per integration (WISH-0102).
class ApiKeyVaultSpec {
  /// Used in messages, e.g. "TMDB API key loaded from vault".
  final String serviceName;

  final String dialogTitle;
  final String fieldLabel;

  /// Title given to the vault entry when saving a key.
  final String vaultEntryTitle;

  /// Lower-case substring used to find the entry again on another device.
  /// Matched against entry titles, so it should be distinctive.
  final String vaultMatch;

  /// Where the user can obtain a key, stored on the vault entry.
  final String? vaultEntryUrl;

  /// Optional explanation shown above the field.
  final String? description;

  const ApiKeyVaultSpec({
    required this.serviceName,
    required this.dialogTitle,
    required this.fieldLabel,
    required this.vaultEntryTitle,
    required this.vaultMatch,
    this.vaultEntryUrl,
    this.description,
  });
}

/// Vault entries that look like they hold this key. Matching on the title
/// keeps it predictable: whatever the app saves as [ApiKeyVaultSpec
/// .vaultEntryTitle] is found again by [ApiKeyVaultSpec.vaultMatch].
List<DecryptedPasswordEntry> matchingVaultEntries(
  List<DecryptedPasswordEntry> entries,
  String match,
) {
  final needle = match.toLowerCase();
  return entries.where((e) => e.title.toLowerCase().contains(needle)).toList();
}

/// Shows the standard API-key dialog: enter a key by hand, or pull one
/// out of the password vault, and offer to put a hand-entered key back
/// into the vault so the next device can pick it up.
///
/// [onSaved] persists the key however the caller needs (secure storage,
/// reconfiguring a service) and is called for both routes, so loading
/// from the vault behaves exactly like typing the key in.
Future<void> showApiKeyVaultDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ApiKeyVaultSpec spec,
  String initialValue = '',
  required Future<void> Function(String key) onSaved,
}) {
  final vaultLocked = ref.read(vaultLockedProvider);

  return showDialog<void>(
    context: context,
    builder: (ctx) => _ApiKeyDialog(
      spec: spec,
      initialValue: initialValue,
      vaultLocked: vaultLocked,
      onLoadFromVault: () {
        Navigator.pop(ctx);
        _loadFromVault(context, ref, spec, onSaved);
      },
      onSubmit: (key) async {
        await onSaved(key);
        if (ctx.mounted) Navigator.pop(ctx);
        if (!vaultLocked && context.mounted) {
          _offerSaveToVault(context, ref, spec, key);
        }
      },
    ),
  );
}

/// Owns the field's controller so it is disposed with the dialog itself.
/// Disposing it when `showDialog`'s future completes is too early — the
/// exit animation still rebuilds the TextField.
class _ApiKeyDialog extends StatefulWidget {
  final ApiKeyVaultSpec spec;
  final String initialValue;
  final bool vaultLocked;
  final VoidCallback onLoadFromVault;
  final Future<void> Function(String key) onSubmit;

  const _ApiKeyDialog({
    required this.spec,
    required this.initialValue,
    required this.vaultLocked,
    required this.onLoadFromVault,
    required this.onSubmit,
  });

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;

    return AlertDialog(
      title: Text(spec.dialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spec.description != null) ...[
            Text(spec.description!),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _controller,
            decoration: InputDecoration(labelText: spec.fieldLabel),
            obscureText: true,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          if (widget.vaultLocked)
            Text(
              'Unlock your Password Vault to load or save the key there.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            OutlinedButton.icon(
              icon: const Icon(Icons.lock_open, size: 18),
              label: const Text('Load from Password Vault'),
              onPressed: widget.onLoadFromVault,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final key = _controller.text.trim();
            if (key.isEmpty) return;
            widget.onSubmit(key);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Future<void> _loadFromVault(
  BuildContext context,
  WidgetRef ref,
  ApiKeyVaultSpec spec,
  Future<void> Function(String key) onSaved,
) async {
  // Awaited rather than read from the current snapshot: the entries
  // stream may not have emitted yet (nothing else is necessarily
  // watching it), and a synchronous read would then look like an empty
  // vault and wrongly report that no key is stored.
  final all = await ref.read(vaultEntriesProvider.future);
  if (!context.mounted) return;
  final entries = matchingVaultEntries(all, spec.vaultMatch);

  if (entries.isEmpty) {
    context.showSnackbar(
      'No ${spec.serviceName} API key found in vault. '
      'Save one first by entering a key manually.',
    );
    return;
  }

  if (entries.length == 1) {
    await _apply(context, ref, spec, entries.first.password, onSaved);
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Select Vault Entry'),
      children: [
        for (final entry in entries)
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _apply(context, ref, spec, entry.password, onSaved);
            },
            child: ListTile(
              leading: const Icon(Icons.key),
              title: Text(entry.title),
              subtitle: entry.username != null ? Text(entry.username!) : null,
            ),
          ),
      ],
    ),
  );
}

Future<void> _apply(
  BuildContext context,
  WidgetRef ref,
  ApiKeyVaultSpec spec,
  String key,
  Future<void> Function(String key) onSaved,
) async {
  await onSaved(key);
  if (context.mounted) {
    context.showSuccessSnackbar(
      '${spec.serviceName} API key loaded from vault',
    );
  }
}

void _offerSaveToVault(
  BuildContext context,
  WidgetRef ref,
  ApiKeyVaultSpec spec,
  String key,
) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Save to Password Vault?'),
      content: Text(
        'Would you like to save the ${spec.serviceName} API key to your '
        'Password Vault for easy access on other devices?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('No thanks'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await ref
                .read(vaultEntriesProvider.notifier)
                .addEntry(
                  title: spec.vaultEntryTitle,
                  password: key,
                  url: spec.vaultEntryUrl,
                  category: 'API Keys',
                );
            if (context.mounted) {
              context.showSuccessSnackbar(
                '${spec.serviceName} API key saved to vault',
              );
            }
          },
          child: const Text('Save to Vault'),
        ),
      ],
    ),
  );
}
