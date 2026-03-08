import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final settings = user.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Appearance'),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Theme'),
            subtitle: Text(
              settings.themeMode[0].toUpperCase() +
                  settings.themeMode.substring(1),
            ),
            onTap: () => _showThemePicker(context, ref, settings.themeMode),
          ),

          const _SectionHeader('Preferences'),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Default Currency'),
            subtitle: Text(settings.defaultCurrency),
            onTap: () =>
                _showCurrencyPicker(context, ref, settings.defaultCurrency),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            value: settings.notificationsEnabled,
            onChanged: (v) {
              final updated = user.copyWith(
                settings: settings.copyWith(notificationsEnabled: v),
              );
              ref.read(authServiceProvider).updateProfile(updated);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Biometric Lock'),
            value: settings.biometricEnabled,
            onChanged: (v) {
              final updated = user.copyWith(
                settings: settings.copyWith(biometricEnabled: v),
              );
              ref.read(authServiceProvider).updateProfile(updated);
            },
          ),

          const _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export Data'),
            subtitle: const Text('Export your data to CSV'),
            onTap: () => context.push('/settings/export'),
          ),

          const _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            subtitle: const Text('0.1.0+1'),
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
      ),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, String current) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Theme'),
        children: [
          for (final mode in ['system', 'light', 'dark'])
            ListTile(
              title: Text(mode[0].toUpperCase() + mode.substring(1)),
              trailing: current == mode ? const Icon(Icons.check) : null,
              onTap: () {
                final user = ref.read(currentUserProvider)!;
                final updated = user.copyWith(
                  settings: user.settings.copyWith(themeMode: mode),
                );
                ref.read(authServiceProvider).updateProfile(updated);
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
  }

  void _showCurrencyPicker(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    const currencies = ['EUR', 'USD', 'GBP', 'JPY', 'CHF', 'CAD', 'AUD'];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Default Currency'),
        children: [
          for (final c in currencies)
            ListTile(
              title: Text(c),
              trailing: current == c ? const Icon(Icons.check) : null,
              onTap: () {
                final user = ref.read(currentUserProvider)!;
                final updated = user.copyWith(
                  settings: user.settings.copyWith(defaultCurrency: c),
                );
                ref.read(authServiceProvider).updateProfile(updated);
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
