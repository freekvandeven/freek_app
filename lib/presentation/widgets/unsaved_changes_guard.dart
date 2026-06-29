import 'package:flutter/material.dart';

/// Intercepts back-navigation when [isDirty] is true and asks the user
/// to confirm before discarding their changes (WISH-0079).
///
/// Covers all back-pop entry points — the AppBar arrow, the Android
/// hardware back button, the iOS edge-swipe back gesture, and any
/// programmatic `Navigator.pop` from within [child]. When the user
/// confirms the discard, the widget pops the route itself; otherwise
/// the user stays on the page.
///
/// Wrap the entire body of an edit page (or the Scaffold itself).
/// When [isDirty] is false the wrapper is a no-op so unedited pages
/// dismiss instantly with no prompt.
class UnsavedChangesGuard extends StatelessWidget {
  final Widget child;

  /// Whether the form has any unsaved changes worth protecting. When
  /// false, back navigation is allowed without a prompt.
  final bool isDirty;

  /// Dialog title shown when intercepting a back. Defaults to a generic
  /// "Discard changes?" — most callers can leave this alone.
  final String title;

  /// Body text in the dialog.
  final String message;

  /// Label on the "leave anyway" confirm button.
  final String discardLabel;

  /// Label on the "stay" cancel button.
  final String stayLabel;

  const UnsavedChangesGuard({
    super.key,
    required this.child,
    required this.isDirty,
    this.title = 'Discard changes?',
    this.message =
        'You have unsaved changes on this page. Going back will lose them.',
    this.discardLabel = 'Discard',
    this.stayLabel = 'Keep editing',
  });

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirmed = await _confirm(context);
        if (confirmed == true && context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: child,
    );
  }

  Future<bool?> _confirm(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(stayLabel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(discardLabel),
          ),
        ],
      ),
    );
  }
}
