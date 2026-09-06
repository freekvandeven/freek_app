import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';

import '../../auth/providers/auth_providers.dart';
import '../../dashboard/dashboard_tiles.dart';

/// Drag the home screen tiles into the order you want (WISH-0106).
class HomeScreenOrderPage extends ConsumerWidget {
  const HomeScreenOrderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Scaffold();

    final tiles = resolveDashboardOrder(user.settings.dashboardOrder);

    Future<void> save(List<DashboardTile> next) async {
      final updated = user.copyWith(
        settings: user.settings.copyWith(
          dashboardOrder: next.map((t) => t.key).toList(),
        ),
      );
      await ref.read(authServiceProvider).updateProfile(updated);
    }

    return Scaffold(
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Home Screen Order')),
        actions: [
          if (user.settings.dashboardOrder.isNotEmpty)
            TextButton(
              onPressed: () async {
                final updated = user.copyWith(
                  settings: user.settings.copyWith(dashboardOrder: const []),
                );
                await ref.read(authServiceProvider).updateProfile(updated);
              },
              child: const Text('Reset'),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: tiles.length,
            // One real handle per row, per BUG-0053.
            buildDefaultDragHandles: false,
            header: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Drag to arrange the tiles on your home screen.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            itemBuilder: (context, index) {
              final tile = tiles[index];
              return ListTile(
                key: ValueKey(tile.key),
                leading: Icon(tile.icon, color: tile.color),
                title: Text(tile.label),
                trailing: ReorderableDragStartListener(
                  index: index,
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Icon(Icons.drag_handle),
                  ),
                ),
              );
            },
            onReorderItem: (oldIndex, newIndex) {
              final next = List.of(tiles);
              next.insert(newIndex, next.removeAt(oldIndex));
              save(next);
            },
          ),
        ),
      ),
    );
  }
}
