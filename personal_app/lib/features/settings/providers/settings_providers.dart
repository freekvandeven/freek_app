import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';

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
