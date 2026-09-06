import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../presentation/theme/app_theme.dart';
import '../../auth/providers/auth_providers.dart';
import 'section_header.dart';

class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final settings = user.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader('Appearance'),
        ListTile(
          leading: const Icon(Icons.reorder),
          title: const Text('Navigation order'),
          subtitle: const Text(
            'Choose which features sit in the navigation bar',
          ),
          onTap: () => context.push('/settings/navigation'),
        ),
        ListTile(
          leading: const Icon(Icons.grid_view_rounded),
          title: const Text('Home screen order'),
          subtitle: const Text('Arrange the tiles on your home screen'),
          onTap: () => context.push('/settings/home-screen'),
        ),
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
                      settings: settings.copyWith(clearCustomSeedColor: true),
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
        if (_supportsFullscreenMode)
          SwitchListTile(
            secondary: const Icon(Icons.fullscreen),
            title: const Text('Fullscreen mode'),
            subtitle: const Text(
              'Hide the status and navigation bars; swipe from an edge to reveal them temporarily',
            ),
            value: settings.fullscreenMode,
            onChanged: (v) {
              final updated = user.copyWith(
                settings: settings.copyWith(fullscreenMode: v),
              );
              ref.read(authServiceProvider).updateProfile(updated);
            },
          ),
      ],
    );
  }

  // Immersive system-UI hiding only really lands on Android. iOS has no
  // user-app equivalent; web/desktop don't have system bars at all in
  // the sense the wish describes (WISH-0074).
  static bool get _supportsFullscreenMode {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
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
