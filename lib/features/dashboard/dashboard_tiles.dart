import 'package:flutter/material.dart';

import 'custom_shortcut.dart';

/// One tile on the home screen grid.
///
/// [key] is the stable identifier stored in account settings so the
/// chosen order survives releases (WISH-0106). [isShellBranch] decides
/// whether tapping switches navigation branch (`go`) or pushes a route —
/// getting it wrong pushes a tab on top of the shell instead of
/// selecting it.
class DashboardTile {
  final String key;
  final IconData icon;
  final String label;
  final Color color;
  final String route;
  final bool isShellBranch;

  const DashboardTile({
    required this.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
    this.isShellBranch = false,
  });
}

const List<DashboardTile> kDashboardTiles = [
  DashboardTile(
    key: 'tasks',
    icon: Icons.check_circle_rounded,
    label: 'Tasks',
    color: Colors.blue,
    route: '/tasks',
    isShellBranch: true,
  ),
  DashboardTile(
    key: 'calendar',
    icon: Icons.calendar_month_rounded,
    label: 'Calendar',
    color: Colors.purple,
    route: '/calendar',
    isShellBranch: true,
  ),
  DashboardTile(
    key: 'finance',
    icon: Icons.account_balance_wallet_rounded,
    label: 'Finance',
    color: Colors.green,
    route: '/finance',
    isShellBranch: true,
  ),
  DashboardTile(
    key: 'recipes',
    icon: Icons.restaurant_menu_rounded,
    label: 'Recipes',
    color: Colors.orange,
    route: '/recipes',
    isShellBranch: true,
  ),
  DashboardTile(
    key: 'watchlist',
    icon: Icons.movie_rounded,
    label: 'Watchlist',
    color: Colors.indigo,
    route: '/watchlist',
    isShellBranch: true,
  ),
  DashboardTile(
    key: 'knowledge',
    icon: Icons.menu_book_rounded,
    label: 'Knowledge',
    color: Colors.indigo,
    route: '/knowledge',
    isShellBranch: true,
  ),
  DashboardTile(
    key: 'inventory',
    icon: Icons.inventory_2_rounded,
    label: 'Inventory',
    color: Colors.teal,
    route: '/inventory',
    isShellBranch: true,
  ),
  DashboardTile(
    key: 'gemini',
    icon: Icons.auto_awesome_rounded,
    label: 'Gemini AI',
    color: Colors.deepPurple,
    route: '/gemini',
    isShellBranch: true,
  ),
  DashboardTile(
    key: 'passwords',
    icon: Icons.lock_rounded,
    label: 'Passwords',
    color: Colors.red,
    route: '/passwords',
  ),
  DashboardTile(
    key: 'feedback',
    icon: Icons.feedback_rounded,
    label: 'Feedback',
    color: Colors.amber,
    route: '/feedback',
  ),
  DashboardTile(
    key: 'connections',
    icon: Icons.link_rounded,
    label: 'Connections',
    color: Colors.cyan,
    route: '/connections',
  ),
  DashboardTile(
    key: 'conversations',
    icon: Icons.forum_rounded,
    label: 'Conversations',
    color: Colors.pink,
    route: '/conversations',
  ),
  DashboardTile(
    key: 'people',
    icon: Icons.people_rounded,
    label: 'People',
    color: Colors.brown,
    route: '/people',
  ),
];

DashboardTile? _byKey(String key) {
  for (final tile in kDashboardTiles) {
    if (tile.key == key) return tile;
  }
  return null;
}

/// The home screen tiles in the user's [saved] order.
///
/// Self-healing on the same terms as the navigation order: unknown keys
/// are dropped, tiles the saved order does not mention are appended in
/// default order so a newly added feature still appears, and duplicates
/// are ignored (WISH-0106). [shortcuts] are the user's own tiles, which
/// take part in the same single order (WISH-0107).
List<DashboardTile> resolveDashboardOrder(
  List<String> saved, {
  List<CustomShortcut> shortcuts = const [],
}) {
  final custom = {
    for (final shortcut in shortcuts) shortcut.orderKey: shortcut.asTile(),
  };

  DashboardTile? lookup(String key) => _byKey(key) ?? custom[key];

  final resolved = <DashboardTile>[];
  final seen = <String>{};

  for (final key in saved) {
    if (!seen.add(key)) continue;
    final tile = lookup(key);
    if (tile != null) resolved.add(tile);
  }
  for (final tile in kDashboardTiles) {
    if (!seen.add(tile.key)) continue;
    resolved.add(tile);
  }
  // A shortcut the saved order does not mention yet — just created —
  // goes to the end rather than disappearing.
  for (final shortcut in shortcuts) {
    if (!seen.add(shortcut.orderKey)) continue;
    resolved.add(shortcut.asTile());
  }
  return resolved;
}
