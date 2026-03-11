import 'dart:async';

import 'package:flutter/material.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/password_entry.dart';
import '../providers/vault_providers.dart';

class PasswordDetailPage extends ConsumerStatefulWidget {
  final String entryId;
  const PasswordDetailPage({super.key, required this.entryId});

  @override
  ConsumerState<PasswordDetailPage> createState() => _PasswordDetailPageState();
}

class _PasswordDetailPageState extends ConsumerState<PasswordDetailPage> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(vaultEntriesProvider);
    final theme = Theme.of(context);

    return entries.when(
      data: (list) {
        final entry = list.where((e) => e.id == widget.entryId).firstOrNull;
        if (entry == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Not Found')),
            body: const Center(child: Text('Entry not found.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: QuickActionsTitle(child: Text(entry.title)),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () =>
                    context.push('/passwords/list/${entry.id}/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _confirmDelete(context, ref, entry),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (entry.category != null) Chip(label: Text(entry.category!)),
              const SizedBox(height: 16),

              // Username
              if (entry.username != null) ...[
                _FieldTile(
                  label: 'Username',
                  value: entry.username!,
                  icon: Icons.person,
                  copyable: true,
                ),
                const Divider(),
              ],

              // Password
              _FieldTile(
                label: 'Password',
                value: _showPassword ? entry.password : '\u2022' * 12,
                icon: Icons.lock,
                copyable: true,
                onCopy: () => _copyPassword(context, entry.password),
                trailing: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
              const Divider(),

              // URL
              if (entry.url != null) ...[
                _FieldTile(
                  label: 'URL',
                  value: entry.url!,
                  icon: Icons.link,
                  copyable: true,
                ),
                const Divider(),
              ],

              // Notes
              if (entry.notes != null) ...[
                const SizedBox(height: 8),
                Text('Notes', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(entry.notes!),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Text(
                'Updated: ${entry.updatedAt.toString().split('.').first}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  void _copyPassword(BuildContext context, String password) {
    Clipboard.setData(ClipboardData(text: password));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password copied (auto-clears in 30s)'),
        duration: Duration(seconds: 2),
      ),
    );
    Timer(const Duration(seconds: 30), () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    DecryptedPasswordEntry entry,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text('Delete "${entry.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(vaultEntriesProvider.notifier).deleteEntry(entry.id);
              context.pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool copyable;
  final VoidCallback? onCopy;
  final Widget? trailing;

  const _FieldTile({
    required this.label,
    required this.value,
    required this.icon,
    this.copyable = false,
    this.onCopy,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label, style: Theme.of(context).textTheme.bodySmall),
      subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?trailing,
          if (copyable)
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed:
                  onCopy ??
                  () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label copied'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
            ),
        ],
      ),
    );
  }
}
