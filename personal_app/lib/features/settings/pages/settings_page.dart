import 'package:flutter/material.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_providers.dart';
import '../../auth/services/biometric_service.dart';
import '../../gemini/providers/gemini_providers.dart';
import '../../gemini/services/gemini_service.dart';
import '../../../presentation/theme/app_theme.dart';
import '../providers/settings_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final settings = user.settings;

    return Scaffold(
      appBar: AppBar(title: const QuickActionsTitle(child: Text('Settings'))),
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
          ListTile(
            leading: Icon(
              Icons.color_lens,
              color: AppTheme.parseHex(settings.customSeedColor) ??
                  AppTheme.defaultSeedColor,
            ),
            title: const Text('Accent Color'),
            subtitle: Text(settings.customSeedColor != null
                ? '#${settings.customSeedColor}'
                : 'Default'),
            trailing: settings.customSeedColor != null
                ? IconButton(
                    icon: const Icon(Icons.restart_alt),
                    tooltip: 'Reset to default',
                    onPressed: () {
                      final updated = user.copyWith(
                        settings: settings.copyWith(clearCustomSeedColor: true),
                      );
                      ref.read(authServiceProvider).updateProfile(updated);
                    },
                  )
                : null,
            onTap: () => _showColorPicker(context, ref),
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

          const _SectionHeader('AI'),
          _GeminiApiKeyTile(),
          _GeminiModelTile(),

          const _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/change-password'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            subtitle: const Text('0.4.0'),
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

  static const _presetColors = [
    Color(0xFF2D77BB), // Default blue
    Color(0xFFE53935), // Red
    Color(0xFF43A047), // Green
    Color(0xFFFB8C00), // Orange
    Color(0xFF8E24AA), // Purple
    Color(0xFF00ACC1), // Cyan
    Color(0xFFD81B60), // Pink
    Color(0xFF3949AB), // Indigo
    Color(0xFF00897B), // Teal
    Color(0xFF6D4C41), // Brown
    Color(0xFF546E7A), // Blue Grey
    Color(0xFFFFB300), // Amber
  ];

  void _showColorPicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accent Color'),
        content: SizedBox(
          width: 280,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _presetColors.map((color) {
              return GestureDetector(
                onTap: () {
                  final user = ref.read(currentUserProvider)!;
                  final hex = AppTheme.toHex(color);
                  final updated = user.copyWith(
                    settings: user.settings.copyWith(customSeedColor: hex),
                  );
                  ref.read(authServiceProvider).updateProfile(updated);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: 2,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
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

class _GeminiApiKeyTile extends ConsumerWidget {
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
              icon: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
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

  void _showApiKeyDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gemini API Key'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'API Key',
            hintText: 'Enter your Gemini API key',
          ),
          obscureText: true,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final key = controller.text.trim();
              if (key.isEmpty) return;
              await ref.read(geminiApiKeyServiceProvider).setApiKey(key);
              ref.invalidate(geminiApiKeyAvailableProvider);
              ref.read(geminiServiceProvider).configure(key);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }
}

class _GeminiModelTile extends ConsumerWidget {
  static const _models = [
    ('gemini-2.5-flash', 'Gemini 2.5 Flash', 'Latest, fast & capable'),
    ('gemini-2.0-flash', 'Gemini 2.0 Flash', 'Fast & versatile'),
    ('gemini-1.5-flash', 'Gemini 1.5 Flash', 'Lightweight & widely available'),
    ('gemini-1.5-pro', 'Gemini 1.5 Pro', 'Advanced reasoning'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentModel = ref.watch(geminiModelProvider);
    final label = _models
        .where((m) => m.$1 == currentModel)
        .map((m) => m.$2)
        .firstOrNull ?? currentModel;

    return ListTile(
      leading: const Icon(Icons.smart_toy),
      title: const Text('Gemini Model'),
      subtitle: Text(label),
      onTap: () => _showModelPicker(context, ref, currentModel),
    );
  }

  void _showModelPicker(BuildContext context, WidgetRef ref, String current) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Gemini Model'),
        children: [
          for (final (id, name, desc) in _models)
            ListTile(
              title: Text(name),
              subtitle: Text(desc),
              trailing: current == id ? const Icon(Icons.check) : null,
              onTap: () {
                final user = ref.read(currentUserProvider)!;
                final updated = user.copyWith(
                  settings: user.settings.copyWith(geminiModel: id),
                );
                ref.read(authServiceProvider).updateProfile(updated);
                ref.read(geminiServiceProvider).setModel(id);
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
  }
}
