import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// A [TextEditingController] whose displayed text is kept in sync with
/// [value] — the search string's source of truth, normally a Riverpod
/// `StateProvider<String>` watched by the caller (BUG-0047).
///
/// Search fields across the app read and write their filter through a
/// provider that outlives the widget (it isn't disposed when the page
/// is). Without this, the visible field can drift from that provider:
/// seeded once from whatever the provider held when the controller was
/// created, and never updated again — so a stale filter kept applying
/// silently while the box looked empty (or showed old text) after
/// navigating away and back, and the "clear" button's search-reset
/// wouldn't visibly clear the box either. Any change to [value] other
/// than the field's own `onChanged` — the clear button, or the app
/// resetting the search when leaving a feature — now updates the
/// visible text too.
///
/// Skips reassigning the controller when [value] already matches its
/// text (the normal case while the user is actively typing, since
/// `onChanged` already wrote [value] moments earlier) so the cursor
/// position and IME composing state are left undisturbed.
TextEditingController useSyncedSearchController(String value) {
  final controller = useTextEditingController(text: value);
  useEffect(() {
    if (controller.text != value) {
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    return null;
  }, [value]);
  return controller;
}
