import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';

import '../../../presentation/theme/app_theme.dart';
import '../../../services/version_check_service.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/biometric_service.dart';
import '../../gemini/providers/gemini_providers.dart';
import '../../gemini/services/gemini_service.dart';
import '../../passwords/providers/vault_providers.dart';
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
      body: ResponsiveCenter(
        child: ListView(
          children: [
            const _SectionHeader('Profile'),
            ListTile(
              leading: user.photoUrl != null
                  ? CircleAvatar(
                      backgroundImage: CachedNetworkImageProvider(
                        user.photoUrl!,
                      ),
                    )
                  : const Icon(Icons.person),
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
                color:
                    AppTheme.parseHex(settings.customSeedColor) ??
                    AppTheme.defaultSeedColor,
              ),
              title: const Text('Accent Color'),
              subtitle: Text(
                settings.customSeedColor != null
                    ? '#${settings.customSeedColor}'
                    : 'Default',
              ),
              trailing: settings.customSeedColor != null
                  ? IconButton(
                      icon: const Icon(Icons.restart_alt),
                      tooltip: 'Reset to default',
                      onPressed: () {
                        final updated = user.copyWith(
                          settings: settings.copyWith(
                            clearCustomSeedColor: true,
                          ),
                        );
                        ref.read(authServiceProvider).updateProfile(updated);
                      },
                    )
                  : null,
              onTap: () => _showColorPicker(context, ref),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.image),
              title: const Text('Image Previews in Lists'),
              subtitle: const Text(
                'Show thumbnail images in inventory and recipe lists',
              ),
              value: settings.showImagePreviews,
              onChanged: (v) {
                final updated = user.copyWith(
                  settings: settings.copyWith(showImagePreviews: v),
                );
                ref.read(authServiceProvider).updateProfile(updated);
              },
            ),

            const _SectionHeader('Preferences'),
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Default Currency'),
              subtitle: Text(
                '${settings.defaultCurrency} ${_currencySymbol(settings.defaultCurrency)}',
              ),
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
            if (settings.notificationsEnabled)
              ListTile(
                leading: const SizedBox(width: 24),
                title: const Text('Expiry Reminders'),
                subtitle: Text(
                  settings.expiryReminderDays.isEmpty
                      ? 'Disabled'
                      : settings.expiryReminderDays
                            .map(
                              (d) => d == 1 ? '1 day before' : '$d days before',
                            )
                            .join(', '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _showExpiryReminderDialog(context, ref, user, settings),
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
                        content: Text(
                          'Biometrics not available on this device',
                        ),
                      ),
                    );
                    return;
                  }
                }
                final updated = user.copyWith(
                  settings: settings.copyWith(biometricEnabled: v),
                );
                await ref.read(authServiceProvider).updateProfile(updated);
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
                      success
                          ? 'Authentication successful!'
                          : 'Authentication failed',
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

            const _SectionHeader('Storage'),
            _StorageUsageTile(user: user),

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
              subtitle: _VersionSubtitle(),
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
        ),
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

  static const _currencies = {
    'EUR': '€',
    'USD': '\$',
    'GBP': '£',
    'CHF': 'Fr',
    'CNY': '¥',
    'JPY': '¥',
    'CAD': 'CA\$',
    'AUD': 'A\$',
    'SEK': 'kr',
    'NOK': 'kr',
    'DKK': 'kr',
    'PLN': 'zł',
    'CZK': 'Kč',
  };

  void _showCurrencyPicker(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _CurrencyPickerDialog(
        current: current,
        onSelected: (code) {
          final user = ref.read(currentUserProvider)!;
          final updated = user.copyWith(
            settings: user.settings.copyWith(defaultCurrency: code),
          );
          ref.read(authServiceProvider).updateProfile(updated);
        },
      ),
    );
  }

  String _currencySymbol(String code) {
    return _currencies[code] ?? code;
  }

  void _showExpiryReminderDialog(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
    UserSettings settings,
  ) {
    final options = [1, 2, 3, 7, 14, 30];
    final selected = Set<int>.from(settings.expiryReminderDays);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Expiry Reminders'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Get notified before inventory items expire:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              ...options.map(
                (days) => CheckboxListTile(
                  title: Text(days == 1 ? '1 day before' : '$days days before'),
                  value: selected.contains(days),
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        selected.add(days);
                      } else {
                        selected.remove(days);
                      }
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final sorted = selected.toList()..sort();
                final updated = user.copyWith(
                  settings: settings.copyWith(expiryReminderDays: sorted),
                );
                ref.read(authServiceProvider).updateProfile(updated);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
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

  void _showApiKeyDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final vaultLocked = ref.read(vaultLockedProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gemini API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'Enter your Gemini API key',
              ),
              obscureText: true,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            if (!vaultLocked)
              OutlinedButton.icon(
                icon: const Icon(Icons.lock_open, size: 18),
                label: const Text('Load from Password Vault'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _loadFromVault(context, ref);
                },
              ),
            if (vaultLocked)
              Text(
                'Unlock your Password Vault to load or save the key there.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
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
              if (!vaultLocked && context.mounted) {
                _offerSaveToVault(context, ref, key);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _loadFromVault(BuildContext context, WidgetRef ref) {
    final entries = ref.read(vaultEntriesProvider).valueOrNull ?? [];
    final geminiEntries = entries
        .where((e) => e.title.toLowerCase().contains('gemini'))
        .toList();

    if (geminiEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No Gemini API key found in vault. '
            'Save one first by entering a key manually.',
          ),
        ),
      );
      return;
    }

    if (geminiEntries.length == 1) {
      _applyVaultEntry(context, ref, geminiEntries.first.password);
      return;
    }

    // Multiple matches — let the user pick
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Vault Entry'),
        children: geminiEntries
            .map(
              (e) => SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(ctx);
                  _applyVaultEntry(context, ref, e.password);
                },
                child: ListTile(
                  leading: const Icon(Icons.key),
                  title: Text(e.title),
                  subtitle: e.username != null ? Text(e.username!) : null,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _applyVaultEntry(BuildContext context, WidgetRef ref, String key) {
    ref.read(geminiApiKeyServiceProvider).setApiKey(key);
    ref.invalidate(geminiApiKeyAvailableProvider);
    ref.read(geminiServiceProvider).configure(key);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gemini API key loaded from vault')),
    );
  }

  void _offerSaveToVault(BuildContext context, WidgetRef ref, String key) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save to Password Vault?'),
        content: const Text(
          'Would you like to save the Gemini API key to your '
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
                    title: _vaultEntryTitle,
                    password: key,
                    url: 'https://aistudio.google.com/apikey',
                    category: 'API Keys',
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Gemini API key saved to vault'),
                  ),
                );
              }
            },
            child: const Text('Save to Vault'),
          ),
        ],
      ),
    );
  }
}

class _GeminiModelTile extends ConsumerWidget {
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

/// Dialog that shows available currencies with live EUR conversion rates
/// fetched from the Frankfurter API (ECB exchange rates, no API key needed).
class _CurrencyPickerDialog extends StatefulWidget {
  final String current;
  final ValueChanged<String> onSelected;

  const _CurrencyPickerDialog({
    required this.current,
    required this.onSelected,
  });

  @override
  State<_CurrencyPickerDialog> createState() => _CurrencyPickerDialogState();
}

class _CurrencyPickerDialogState extends State<_CurrencyPickerDialog> {
  Map<String, double>? _rates;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRates();
  }

  Future<void> _fetchRates() async {
    try {
      final codes = SettingsPage._currencies.keys
          .where((c) => c != 'EUR')
          .join(',');
      final response = await http.get(
        Uri.parse(
          'https://api.frankfurter.dev/v1/latest?base=EUR&symbols=$codes',
        ),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rates = (body['rates'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        );
        if (mounted) setState(() => _rates = rates);
      }
    } catch (_) {
      // Rates are informational — silently ignore failures
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Default Currency'),
      children: [
        for (final entry in SettingsPage._currencies.entries)
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
            subtitle: _rateSubtitle(entry.key),
            trailing: widget.current == entry.key
                ? const Icon(Icons.check)
                : null,
            onTap: () {
              widget.onSelected(entry.key);
              Navigator.pop(context);
            },
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }

  Widget? _rateSubtitle(String code) {
    if (code == 'EUR') return const Text('Base currency');
    if (_rates == null) return null;
    final rate = _rates![code];
    if (rate == null) return null;
    return Text('1 EUR = ${rate.toStringAsFixed(rate < 10 ? 4 : 2)} $code');
  }
}

class _StorageUsageTile extends StatelessWidget {
  final UserProfile user;
  const _StorageUsageTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final used = user.storageUsedBytes;
    final limit = user.storageLimitBytes;
    final fraction = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final colorScheme = Theme.of(context).colorScheme;

    Color barColor;
    if (fraction > 0.9) {
      barColor = colorScheme.error;
    } else if (fraction > 0.7) {
      barColor = Colors.orange;
    } else {
      barColor = colorScheme.primary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_outlined, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_formatBytes(used)} of ${_formatBytes(limit)} used',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Text(
                '${(fraction * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: barColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: barColor,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _VersionSubtitle extends ConsumerWidget {
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
