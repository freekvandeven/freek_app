import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../providers/inventory_providers.dart';

/// Dialog for viewing / changing the default inventory location
/// setting (WISH-0084). Shared between Settings → Preferences and the
/// quick-access icon on the inventory overview so both stay in sync.
///
/// Offers the known locations (derived from existing items) as one-tap
/// chips plus a free-text field for new rooms; clearing the field
/// removes the default.
Future<void> showDefaultLocationDialog(BuildContext context, WidgetRef ref) {
  final current =
      ref.read(currentUserProvider)?.settings.defaultInventoryLocation ?? '';
  final known = ref.read(inventoryLocationsProvider).valueOrNull ?? const [];
  final controller = TextEditingController(text: current);

  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Default location'),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New inventory items start with this location pre-filled. '
                'Leave empty for no default.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Location',
                  border: const OutlineInputBorder(),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear',
                          onPressed: () => setDialogState(controller.clear),
                        )
                      : null,
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
              if (known.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final location in known)
                      ActionChip(
                        label: Text(location),
                        onPressed: () =>
                            setDialogState(() => controller.text = location),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final user = ref.read(currentUserProvider);
              if (user == null) {
                Navigator.of(ctx).pop();
                return;
              }
              final value = controller.text.trim();
              final updated = user.copyWith(
                settings: value.isEmpty
                    ? user.settings.copyWith(
                        clearDefaultInventoryLocation: true,
                      )
                    : user.settings.copyWith(defaultInventoryLocation: value),
              );
              ref.read(authServiceProvider).updateProfile(updated);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
