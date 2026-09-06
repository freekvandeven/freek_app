import 'package:flutter/material.dart';

/// One destination in the bottom navigation bar / rail.
///
/// [key] is the stable identifier stored in account settings, so the
/// user's order survives a release that adds, removes or reorders
/// branches (WISH-0106). [branchIndex] is the position of the matching
/// `StatefulShellBranch` in `app_router.dart` — the coupling is written
/// down here rather than implied by list position.
class NavDestination {
  final String key;
  final int branchIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const NavDestination({
    required this.key,
    required this.branchIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Key of the overflow destination, which is always shown and always last.
const String kMoreDestinationKey = 'more';

const List<NavDestination> kNavDestinations = [
  NavDestination(
    key: 'home',
    branchIndex: 0,
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
    label: 'Home',
  ),
  NavDestination(
    key: 'tasks',
    branchIndex: 1,
    icon: Icons.check_circle_outline,
    selectedIcon: Icons.check_circle_rounded,
    label: 'Tasks',
  ),
  NavDestination(
    key: 'calendar',
    branchIndex: 2,
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
    label: 'Calendar',
  ),
  NavDestination(
    key: 'finance',
    branchIndex: 3,
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet_rounded,
    label: 'Finance',
  ),
  NavDestination(
    key: 'recipes',
    branchIndex: 4,
    icon: Icons.restaurant_menu_outlined,
    selectedIcon: Icons.restaurant_menu_rounded,
    label: 'Recipes',
  ),
  NavDestination(
    key: 'knowledge',
    branchIndex: 5,
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book_rounded,
    label: 'Knowledge',
  ),
  NavDestination(
    key: 'inventory',
    branchIndex: 6,
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
    label: 'Inventory',
  ),
  NavDestination(
    key: 'gemini',
    branchIndex: 7,
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome_rounded,
    label: 'Gemini AI',
  ),
  NavDestination(
    key: kMoreDestinationKey,
    branchIndex: 8,
    icon: Icons.menu_rounded,
    selectedIcon: Icons.menu_rounded,
    label: 'More',
  ),
  NavDestination(
    key: 'watchlist',
    branchIndex: 9,
    icon: Icons.movie_outlined,
    selectedIcon: Icons.movie_rounded,
    label: 'Watchlist',
  ),
];

/// The order destinations appear in before the user has chosen one.
final List<String> defaultNavOrder = [
  'home',
  'tasks',
  'calendar',
  'finance',
  'watchlist',
  'recipes',
  'knowledge',
  'inventory',
  'gemini',
  kMoreDestinationKey,
];

NavDestination? _byKey(String key) {
  for (final destination in kNavDestinations) {
    if (destination.key == key) return destination;
  }
  return null;
}

/// The destination order to display, from the user's [saved] order.
///
/// Saved orders are self-healing rather than authoritative: keys that no
/// longer exist are dropped, destinations the saved order does not
/// mention are appended in default order (so a feature added in a later
/// release appears instead of vanishing), duplicates are ignored, and
/// More is forced last because it is the overflow for whatever does not
/// fit (WISH-0106).
List<NavDestination> resolveNavOrder(List<String> saved) {
  final resolved = <NavDestination>[];
  final seen = <String>{};

  for (final key in saved) {
    if (key == kMoreDestinationKey || !seen.add(key)) continue;
    final destination = _byKey(key);
    if (destination != null) resolved.add(destination);
  }

  for (final key in defaultNavOrder) {
    if (key == kMoreDestinationKey || !seen.add(key)) continue;
    final destination = _byKey(key);
    if (destination != null) resolved.add(destination);
  }

  final more = _byKey(kMoreDestinationKey);
  if (more != null) resolved.add(more);
  return resolved;
}

/// How many destinations fit at [width], counting More. Narrow screens
/// show the first few of the user's order, which is what makes the order
/// a statement of priority rather than only of arrangement.
int visibleNavCount(double width) {
  if (width < 600) return 5;
  if (width < 900) return 6;
  if (width < 1200) return 8;
  return kNavDestinations.length;
}

/// The destinations to show at [width], keeping More in the last slot.
List<NavDestination> visibleNavDestinations(
  List<NavDestination> order,
  double width,
) {
  final more = order.where((d) => d.key == kMoreDestinationKey);
  final rest = order.where((d) => d.key != kMoreDestinationKey);
  final count = visibleNavCount(width);
  return [...rest.take((count - more.length).clamp(0, rest.length)), ...more];
}
