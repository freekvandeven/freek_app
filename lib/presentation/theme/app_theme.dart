import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const defaultSeedColor = Color(0xFF2D77BB);

  static ThemeData lightTheme([Color? seedColor]) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor ?? defaultSeedColor,
      brightness: Brightness.light,
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData darkTheme([Color? seedColor]) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor ?? defaultSeedColor,
      brightness: Brightness.dark,
    );
    return _buildTheme(colorScheme);
  }

  /// Parse a hex color string like "FF2D77BB" or "2D77BB" to a Color.
  static Color? parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    final value = int.tryParse(hex, radix: 16);
    return value != null ? Color(value) : null;
  }

  /// Convert a Color to hex string like "FF2D77BB".
  static String toHex(Color color) {
    return color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.secondaryContainer,
        backgroundColor: colorScheme.surface,
      ),
    );
  }
}
