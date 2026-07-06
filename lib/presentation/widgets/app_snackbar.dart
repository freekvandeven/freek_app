import 'package:flutter/material.dart';

/// App-wide snackbar helpers.
///
/// Prefer these over building [SnackBar]s inline so success/error styling and
/// durations stay consistent across the app. All variants replace any snackbar
/// currently on screen instead of queueing behind it.
extension AppSnackbar on BuildContext {
  /// Neutral, informational message.
  void showSnackbar(
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) => _showSnackbar(this, message, duration: duration, action: action);

  /// Positive confirmation (e.g. "Saved", "Copied to clipboard").
  void showSuccessSnackbar(
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    final scheme = Theme.of(this).colorScheme;
    _showSnackbar(
      this,
      message,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      duration: duration,
      action: action,
    );
  }

  /// Failure message, styled with the theme's error colors.
  void showErrorSnackbar(
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    final scheme = Theme.of(this).colorScheme;
    _showSnackbar(
      this,
      message,
      backgroundColor: scheme.errorContainer,
      foregroundColor: scheme.onErrorContainer,
      duration: duration,
      action: action,
    );
  }
}

void _showSnackbar(
  BuildContext context,
  String message, {
  Color? backgroundColor,
  Color? foregroundColor,
  Duration? duration,
  SnackBarAction? action,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: foregroundColor == null
              ? null
              : TextStyle(color: foregroundColor),
        ),
        backgroundColor: backgroundColor,
        duration: duration ?? const Duration(seconds: 4),
        action: action,
      ),
    );
}
