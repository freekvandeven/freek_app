import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/inventory/providers/inventory_providers.dart';
import '../../features/knowledge/providers/knowledge_providers.dart';
import '../../features/recipes/providers/recipe_providers.dart';
import '../../features/watchlist/providers/watchlist_providers.dart';
import 'nav_destinations.dart';

const double _kRailBreakpoint = 600;
const double _kExtendedRailBreakpoint = 1200;

class AppShell extends HookConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  // Shell-branch pages keep their search StateProvider populated even
  // while their tab is hidden (StatefulShellRoute.indexedStack never
  // disposes an inactive branch), so — unlike the pushed, non-branch
  // list pages — they can't reset their own search on a fresh mount.
  // Reset the branch being left instead, whenever the active branch
  // index changes (BUG-0047). Keyed off the destination rather than a
  // literal branch index, so adding a branch cannot silently shift it.
  static void _resetSearchForBranch(int branchIndex, WidgetRef ref) {
    final key = kNavDestinations
        .where((d) => d.branchIndex == branchIndex)
        .map((d) => d.key)
        .firstOrNull;
    switch (key) {
      case 'recipes':
        ref.read(recipeSearchProvider.notifier).state = '';
      case 'knowledge':
        ref.read(knowledgeSearchProvider.notifier).state = '';
      case 'inventory':
        ref.read(inventorySearchProvider.notifier).state = '';
      case 'watchlist':
        ref.read(watchlistSearchProvider.notifier).state = '';
    }
  }

  void _onTap(int displayIndex, List<NavDestination> visible) {
    final branchIndex = visible[displayIndex].branchIndex;
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  // Returns the display-level selected index, falling back to the "More"
  // position when the active branch is not visible at the current breakpoint.
  int _displaySelected(List<NavDestination> visible) {
    final pos = visible.indexWhere(
      (d) => d.branchIndex == navigationShell.currentIndex,
    );
    if (pos >= 0) return pos;
    return visible.indexWhere((d) => d.key == kMoreDestinationKey);
  }

  // Routes where the bottom navigation bar is hidden to maximise content
  // space — currently any recipe view/edit/new screen.
  static final _hideBottomNavRe = RegExp(r'^/recipes/[^/]+(/.*)?$');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = navigationShell.currentIndex;
    final previousIndex = usePrevious(currentIndex);
    useEffect(() {
      if (previousIndex != null && previousIndex != currentIndex) {
        _resetSearchForBranch(previousIndex, ref);
      }
      return null;
    }, [currentIndex]);

    final width = MediaQuery.sizeOf(context).width;
    final order = resolveNavOrder(
      ref.watch(currentUserProvider)?.settings.navOrder ?? const [],
    );
    final visible = visibleNavDestinations(order, width);
    final displaySelected = _displaySelected(visible);
    final useRail = width >= _kRailBreakpoint;
    final extendedRail = width >= _kExtendedRailBreakpoint;
    final hideBottomNav = _hideBottomNavRe.hasMatch(
      GoRouterState.of(context).matchedLocation,
    );

    if (!useRail) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: hideBottomNav
            ? null
            : NavigationBar(
                selectedIndex: displaySelected,
                onDestinationSelected: (i) => _onTap(i, visible),
                destinations: visible
                    .map(
                      (d) => NavigationDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: d.label,
                      ),
                    )
                    .toList(),
              ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: displaySelected,
            onDestinationSelected: (i) => _onTap(i, visible),
            extended: extendedRail,
            labelType: extendedRail
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            destinations: visible
                .map(
                  (d) => NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
