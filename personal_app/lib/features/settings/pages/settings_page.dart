import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_providers.dart';
import '../../auth/services/biometric_service.dart';

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
          const _SectionHeader('Profile'),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Edit Profile'),
            subtitle: Text(user.displayName ?? user.email),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/profile'),
          ),

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
            subtitle: Text('${settings.defaultCurrency} ${_currencySymbol(settings.defaultCurrency)}'),
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
            onChanged: (v) async {
              if (v) {
                // Test biometrics before enabling
                final available = await BiometricService.isAvailable;
                if (!available && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Biometrics not available on this device'),
                    ),
                  );
                  return;
                }
              }
              final updated = user.copyWith(
                settings: settings.copyWith(biometricEnabled: v),
              );
              ref.read(authServiceProvider).updateProfile(updated);
            },
          ),
          ListTile(
            leading: const SizedBox(width: 24),
            title: const Text('Test Biometric Lock'),
            trailing: const Icon(Icons.play_arrow),
            onTap: () async {
              final available = await BiometricService.isAvailable;
              if (!context.mounted) return;
              if (!available) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Biometrics not available on this device'),
                  ),
                );
                return;
              }
              final success = await BiometricService.authenticate(
                reason: 'Testing biometric authentication',
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success ? 'Authentication successful!' : 'Authentication failed',
                  ),
                ),
              );
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
            subtitle: const Text('0.2.0'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/changelog'),
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
    const currencies = {
      'EUR': '€',
      'USD': '\$',
      'GBP': '£',
      'JPY': '¥',
      'CHF': 'Fr',
      'CAD': 'CA\$',
      'AUD': 'A\$',
      'CNY': '¥',
      'SEK': 'kr',
      'NOK': 'kr',
      'DKK': 'kr',
      'PLN': 'zł',
      'CZK': 'Kč',
      'HUF': 'Ft',
      'TRY': '₺',
      'INR': '₹',
      'BRL': 'R\$',
      'KRW': '₩',
      'SGD': 'S\$',
      'HKD': 'HK\$',
      'MXN': 'MX\$',
      'ZAR': 'R',
      'THB': '฿',
      'NZD': 'NZ\$',
    };
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Default Currency'),
        children: [
          for (final entry in currencies.entries)
            ListTile(
              leading: SizedBox(
                width: 36,
                child: Text(
                  entry.value,
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
              title: Text(entry.key),
              trailing: current == entry.key ? const Icon(Icons.check) : null,
              onTap: () {
                final user = ref.read(currentUserProvider)!;
                final updated = user.copyWith(
                  settings: user.settings.copyWith(defaultCurrency: entry.key),
                );
                ref.read(authServiceProvider).updateProfile(updated);
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
  }

  String _currencySymbol(String code) {
    const symbols = {
      'EUR': '€', 'USD': '\$', 'GBP': '£', 'JPY': '¥', 'CHF': 'Fr',
      'CAD': 'CA\$', 'AUD': 'A\$', 'CNY': '¥', 'SEK': 'kr', 'NOK': 'kr',
      'DKK': 'kr', 'PLN': 'zł', 'CZK': 'Kč', 'HUF': 'Ft', 'TRY': '₺',
      'INR': '₹', 'BRL': 'R\$', 'KRW': '₩', 'SGD': 'S\$', 'HKD': 'HK\$',
      'MXN': 'MX\$', 'ZAR': 'R', 'THB': '฿', 'NZD': 'NZ\$',
    };
    return symbols[code] ?? code;
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
