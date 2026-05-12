import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/biometric_service.dart';
import 'currency_picker_dialog.dart';
import 'section_header.dart';

class PreferencesSection extends ConsumerWidget {
  const PreferencesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final settings = user.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader('Preferences'),
        ListTile(
          leading: const Icon(Icons.attach_money),
          title: const Text('Default Currency'),
          subtitle: Text(
            '${settings.defaultCurrency} ${currencySymbol(settings.defaultCurrency)}',
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
                        .map((d) => d == 1 ? '1 day before' : '$d days before')
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
            await ref.read(authServiceProvider).updateProfile(updated);
          },
        ),
        ListTile(
          leading: const SizedBox(width: 24),
          title: const Text('Test Biometric Lock'),
          trailing: const Icon(Icons.play_arrow),
          onTap: () => _testBiometric(context),
        ),
        ListTile(
          leading: const Icon(Icons.save_outlined),
          title: const Text('Auto-save Interval'),
          subtitle: Text(
            settings.autosaveIntervalMinutes == 0
                ? 'Disabled'
                : 'Every ${settings.autosaveIntervalMinutes} min (recipes & knowledge)',
          ),
          onTap: () => _showAutosavePicker(context, ref, settings),
        ),
      ],
    );
  }

  Future<void> _testBiometric(BuildContext context) async {
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
  }

  void _showCurrencyPicker(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => CurrencyPickerDialog(
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

  void _showAutosavePicker(
    BuildContext context,
    WidgetRef ref,
    UserSettings settings,
  ) {
    const options = [0, 1, 2, 5, 10, 15, 30];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Auto-save Interval'),
        children: [
          for (final minutes in options)
            ListTile(
              title: Text(minutes == 0 ? 'Disabled' : 'Every $minutes min'),
              trailing: settings.autosaveIntervalMinutes == minutes
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                final user = ref.read(currentUserProvider)!;
                final updated = user.copyWith(
                  settings: settings.copyWith(autosaveIntervalMinutes: minutes),
                );
                ref.read(authServiceProvider).updateProfile(updated);
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
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
}
