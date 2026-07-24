import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../features/inventory/providers/inventory_providers.dart';
import '../../features/knowledge/providers/knowledge_providers.dart';
import '../../features/recipes/providers/recipe_providers.dart';

const double _kRailBreakpoint = 600;
const double _kExtendedRailBreakpoint = 1200;

// Breakpoints for showing additional nav items in the rail.
// Each level adds more items; "More" is always last.
const double _kShowRecipes = 600;
const double _kShowKnowledgeInventory = 900;
const double _kShowGemini = 1200;

class AppShell extends HookConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  // Shell-branch pages keep their search StateProvider populated even
  // while their tab is hidden (StatefulShellRoute.indexedStack never
  // disposes an inactive branch), so — unlike the pushed, non-branch
  // list pages — they can't reset their own search on a fresh mount.
  // Reset the branch being left instead, whenever the active branch
  // index changes (BUG-0047). Keys match the branch order in
  // app_router.dart, same coupling as _allDestinations below.
  static void _resetSearchForBranch(int branchIndex, WidgetRef ref) {
    switch (branchIndex) {
      case 4: // Recipes
        ref.read(recipeSearchProvider.notifier).state = '';
      case 5: // Knowledge
        ref.read(knowledgeSearchProvider.notifier).state = '';
      case 6: // Inventory
        ref.read(inventorySearchProvider.notifier).state = '';
    }
  }

  // Ordered list of all shell branches (index matches branch index in router).
  static const _allDestinations = <_Dest>[
    _Dest(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      label: 'Home',
    ),
    _Dest(
      icon: Icons.check_circle_outline,
      selectedIcon: Icons.check_circle_rounded,
      label: 'Tasks',
    ),
    _Dest(
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
      label: 'Calendar',
    ),
    _Dest(
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      label: 'Finance',
    ),
    _Dest(
      icon: Icons.restaurant_menu_outlined,
      selectedIcon: Icons.restaurant_menu_rounded,
      label: 'Recipes',
    ),
    _Dest(
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book_rounded,
      label: 'Knowledge',
    ),
    _Dest(
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      label: 'Inventory',
    ),
    _Dest(
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome_rounded,
      label: 'Gemini AI',
    ),
    _Dest(
      icon: Icons.menu_rounded,
      selectedIcon: Icons.menu_rounded,
      label: 'More',
    ),
  ];

  // Returns the ordered branch indices to display at a given screen width.
  static List<int> _visibleIndices(double width) {
    if (width < _kShowRecipes) return [0, 1, 2, 3, 8]; // mobile
    if (width < _kShowKnowledgeInventory) return [0, 1, 2, 3, 4, 8];
    if (width < _kShowGemini) return [0, 1, 2, 3, 4, 5, 6, 8];
    return [0, 1, 2, 3, 4, 5, 6, 7, 8]; // all items
  }

  void _onTap(int displayIndex, List<int> visible) {
    final branchIndex = visible[displayIndex];
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  // Returns the display-level selected index, falling back to the "More"
  // position when the active branch is not visible at the current breakpoint.
  int _displaySelected(List<int> visible) {
    final pos = visible.indexOf(navigationShell.currentIndex);
    if (pos >= 0) return pos;
    return visible.indexOf(8); // More
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
    final visible = _visibleIndices(width);
    final displaySelected = _displaySelected(visible);
    final useRail = width >= _kRailBreakpoint;
    final extendedRail = width >= _kExtendedRailBreakpoint;
    final hideBottomNav = _hideBottomNavRe.hasMatch(
      GoRouterState.of(context).matchedLocation,
    );

    final destinations = visible.map((i) => _allDestinations[i]).toList();

    if (!useRail) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: hideBottomNav
            ? null
            : NavigationBar(
                selectedIndex: displaySelected,
                onDestinationSelected: (i) => _onTap(i, visible),
                destinations: destinations
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
            destinations: destinations
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

class _Dest {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _Dest({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
