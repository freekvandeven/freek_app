import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/theme/app_theme.dart';
import '../../auth/providers/auth_providers.dart';
import '../../changelog/data/changelog_parser.dart';
import '../../gemini/services/gemini_service.dart';

/// Derives the Flutter ThemeMode from the user's stored preference
final themeModeProvider = Provider<ThemeMode>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return ThemeMode.system;
  switch (user.settings.themeMode) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
});

/// Custom seed color from user settings, or null for the default.
final customSeedColorProvider = Provider<Color?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return AppTheme.parseHex(user.settings.customSeedColor);
});

/// Selected Gemini model from user settings, or the default.
final geminiModelProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.settings.geminiModel ?? GeminiService.defaultModel;
});

/// Whether the CHANGELOG contains an [Unreleased] section with entries.
final hasUnreleasedChangesProvider = FutureProvider<bool>((ref) async {
  try {
    final markdown = await rootBundle.loadString('CHANGELOG.md');
    final entries = parseChangelog(markdown);
    if (entries.isEmpty) return false;
    final first = entries.first;
    return first.isUnreleased &&
        (first.added.isNotEmpty ||
            first.changed.isNotEmpty ||
            first.fixed.isNotEmpty);
  } catch (_) {
    return false;
  }
});
