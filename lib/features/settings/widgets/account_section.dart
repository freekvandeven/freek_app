import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/version_check_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/settings_providers.dart';
import 'section_header.dart';

class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader('Account'),
        ListTile(
          leading: const Icon(Icons.lock_reset),
          title: const Text('Change Password'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/change-password'),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('App Version'),
          subtitle: const _VersionSubtitle(),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/changelog'),
        ),
        ListTile(
          leading: const Icon(Icons.developer_mode),
          title: const Text('Developer'),
          subtitle: const Text('Logs, debug info & tools'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/developer'),
        ),
        ListTile(
          leading: Icon(
            Icons.logout,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Logout',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          onTap: () => _confirmLogout(context, ref),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authServiceProvider).signOut();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _VersionSubtitle extends ConsumerWidget {
  const _VersionSubtitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version =
        ref.watch(versionCheckProvider).valueOrNull?.current ?? '...';
    final hasUnreleased =
        ref.watch(hasUnreleasedChangesProvider).valueOrNull ?? false;

    if (!hasUnreleased) return Text(version);

    return Row(
      children: [
        Text(version),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'unreleased changes',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
