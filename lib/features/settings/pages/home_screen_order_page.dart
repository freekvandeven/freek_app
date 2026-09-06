import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';

import '../../auth/providers/auth_providers.dart';
import '../../dashboard/custom_shortcut.dart';
import '../../dashboard/dashboard_tiles.dart';

/// Drag the home screen tiles into the order you want, and add shortcuts
/// that jump straight to a page (WISH-0106, WISH-0107).
class HomeScreenOrderPage extends ConsumerWidget {
  const HomeScreenOrderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Scaffold();

    final shortcuts = [
      for (final map in user.settings.customShortcuts)
        CustomShortcut.fromMap(map),
    ];
    final tiles = resolveDashboardOrder(
      user.settings.dashboardOrder,
      shortcuts: shortcuts,
    );

    Future<void> saveOrder(List<DashboardTile> next) async {
      final updated = user.copyWith(
        settings: user.settings.copyWith(
          dashboardOrder: next.map((t) => t.key).toList(),
        ),
      );
      await ref.read(authServiceProvider).updateProfile(updated);
    }

    Future<void> saveShortcuts(List<CustomShortcut> next) async {
      final updated = user.copyWith(
        settings: user.settings.copyWith(
          customShortcuts: next.map((s) => s.toMap()).toList(),
        ),
      );
      await ref.read(authServiceProvider).updateProfile(updated);
    }

    return Scaffold(
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Home Screen')),
        actions: [
          if (user.settings.dashboardOrder.isNotEmpty)
            TextButton(
              onPressed: () async {
                final updated = user.copyWith(
                  settings: user.settings.copyWith(dashboardOrder: const []),
                );
                await ref.read(authServiceProvider).updateProfile(updated);
              },
              child: const Text('Reset order'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final shortcut = await showShortcutDialog(context);
          if (shortcut == null) return;
          await saveShortcuts([...shortcuts, shortcut]);
        },
        icon: const Icon(Icons.add_link),
        label: const Text('Add shortcut'),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: tiles.length,
            // One real handle per row, per BUG-0053.
            buildDefaultDragHandles: false,
            header: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Drag to arrange the tiles on your home screen. Add '
                'shortcuts to jump straight to a page you use often.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            itemBuilder: (context, index) {
              final tile = tiles[index];
              final shortcut = shortcuts
                  .where((s) => s.orderKey == tile.key)
                  .firstOrNull;

              return ListTile(
                key: ValueKey(tile.key),
                leading: Icon(tile.icon, color: tile.color),
                title: Text(tile.label),
                subtitle: shortcut == null ? null : Text(shortcut.route),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (shortcut != null) ...[
                      IconButton(
                        tooltip: 'Edit shortcut',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          final edited = await showShortcutDialog(
                            context,
                            existing: shortcut,
                          );
                          if (edited == null) return;
                          await saveShortcuts([
                            for (final s in shortcuts)
                              if (s.id == edited.id) edited else s,
                          ]);
                        },
                      ),
                      IconButton(
                        tooltip: 'Remove shortcut',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => saveShortcuts([
                          for (final s in shortcuts)
                            if (s.id != shortcut.id) s,
                        ]),
                      ),
                    ],
                    ReorderableDragStartListener(
                      index: index,
                      child: const MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  ],
                ),
              );
            },
            onReorderItem: (oldIndex, newIndex) {
              final next = List.of(tiles);
              next.insert(newIndex, next.removeAt(oldIndex));
              saveOrder(next);
            },
          ),
        ),
      ),
    );
  }
}

/// Create or edit a custom home screen shortcut (WISH-0107). Returns the
/// shortcut to save, or null if the user backs out.
Future<CustomShortcut?> showShortcutDialog(
  BuildContext context, {
  CustomShortcut? existing,
}) {
  return showDialog<CustomShortcut>(
    context: context,
    builder: (ctx) => _ShortcutDialog(existing: existing),
  );
}

class _ShortcutDialog extends StatefulWidget {
  final CustomShortcut? existing;
  const _ShortcutDialog({this.existing});

  @override
  State<_ShortcutDialog> createState() => _ShortcutDialogState();
}

class _ShortcutDialogState extends State<_ShortcutDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label = TextEditingController(
    text: widget.existing?.label ?? '',
  );
  late final TextEditingController _route = TextEditingController(
    text: widget.existing?.route ?? '',
  );
  late String _iconKey = widget.existing?.iconKey ?? kDefaultShortcutIcon;

  @override
  void dispose() {
    _label.dispose();
    _route.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New Shortcut' : 'Edit Shortcut'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _label,
                decoration: const InputDecoration(
                  labelText: 'Label *',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'A label is required'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _route,
                decoration: const InputDecoration(
                  labelText: 'Route *',
                  hintText: '/knowledge/abc123',
                  border: OutlineInputBorder(),
                  helperText: 'Where it opens, e.g. /people or a page URL',
                  helperMaxLines: 2,
                ),
                validator: validateShortcutRoute,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Icon',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in kShortcutIcons.entries)
                    IconButton(
                      icon: Icon(entry.value),
                      isSelected: _iconKey == entry.key,
                      style: IconButton.styleFrom(
                        backgroundColor: _iconKey == entry.key
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : null,
                      ),
                      onPressed: () => setState(() => _iconKey = entry.key),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              CustomShortcut(
                id: widget.existing?.id,
                label: _label.text.trim(),
                route: _route.text.trim(),
                iconKey: _iconKey,
              ),
            );
          },
          child: Text(widget.existing == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
