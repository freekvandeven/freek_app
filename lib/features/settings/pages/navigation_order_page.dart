import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';

import '../../../presentation/shell/nav_destinations.dart';
import '../../auth/providers/auth_providers.dart';

/// Drag the navigation destinations into the order you want (WISH-0106).
///
/// The order is a statement of priority, not just arrangement: narrow
/// screens show only the first few, so what sits at the top is what
/// survives on a phone. The cut-off is drawn in the list so that is
/// visible while reordering rather than a surprise afterwards.
class NavigationOrderPage extends ConsumerWidget {
  const NavigationOrderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Scaffold();

    final order = resolveNavOrder(user.settings.navOrder);
    // More is pinned last and cannot be moved, so it is not part of the
    // draggable list.
    final movable = order.where((d) => d.key != kMoreDestinationKey).toList();
    final width = MediaQuery.sizeOf(context).width;
    final shownHere = visibleNavCount(width) - 1;

    Future<void> save(List<NavDestination> next) async {
      final updated = user.copyWith(
        settings: user.settings.copyWith(
          navOrder: [...next.map((d) => d.key), kMoreDestinationKey],
        ),
      );
      await ref.read(authServiceProvider).updateProfile(updated);
    }

    return Scaffold(
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Navigation Order')),
        actions: [
          if (user.settings.navOrder.isNotEmpty)
            TextButton(
              onPressed: () async {
                final updated = user.copyWith(
                  settings: user.settings.copyWith(navOrder: const []),
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
            itemCount: movable.length + 1,
            // The handle on each row is the only drag affordance, rather
            // than a real one hiding under a look-alike icon (BUG-0053).
            buildDefaultDragHandles: false,
            header: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Drag to choose which features matter most. This screen '
                'shows the first $shownHere; the rest live under More.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            itemBuilder: (context, index) {
              // The last row is More, shown for context but not draggable.
              if (index == movable.length) {
                final more = order.last;
                return ListTile(
                  key: const ValueKey(kMoreDestinationKey),
                  leading: Icon(more.icon),
                  title: Text(more.label),
                  subtitle: const Text('Always last — holds everything else'),
                  enabled: false,
                );
              }

              final destination = movable[index];
              final inMore = index >= shownHere;
              return ListTile(
                key: ValueKey(destination.key),
                leading: Icon(destination.icon),
                title: Text(destination.label),
                subtitle: Text(
                  inMore
                      ? 'Under More on this screen'
                      : 'In the navigation bar',
                ),
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
              // More occupies the trailing row and never moves.
              if (oldIndex >= movable.length) return;
              final next = List.of(movable);
              final target = newIndex.clamp(0, movable.length - 1);
              next.insert(target, next.removeAt(oldIndex));
              save(next);
            },
          ),
        ),
      ),
    );
  }
}
