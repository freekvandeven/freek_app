import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'dashboard_tiles.dart';

/// Icons a custom shortcut can use (WISH-0107).
///
/// A fixed registry rather than a stored codepoint: Flutter tree-shakes
/// icon fonts, so an `IconData` built from a number at runtime can render
/// as a blank box in a release build. Keys are stored; the icons
/// themselves stay const and therefore survive tree-shaking.
const Map<String, IconData> kShortcutIcons = {
  'link': Icons.link_rounded,
  'star': Icons.star_rounded,
  'bookmark': Icons.bookmark_rounded,
  'note': Icons.sticky_note_2_rounded,
  'book': Icons.menu_book_rounded,
  'person': Icons.person_rounded,
  'group': Icons.groups_rounded,
  'task': Icons.check_circle_rounded,
  'calendar': Icons.calendar_month_rounded,
  'movie': Icons.movie_rounded,
  'recipe': Icons.restaurant_menu_rounded,
  'shopping': Icons.shopping_cart_rounded,
  'money': Icons.account_balance_wallet_rounded,
  'home': Icons.home_rounded,
  'work': Icons.work_rounded,
  'idea': Icons.lightbulb_rounded,
};

const String kDefaultShortcutIcon = 'link';

IconData shortcutIcon(String key) =>
    kShortcutIcons[key] ?? kShortcutIcons[kDefaultShortcutIcon]!;

/// A user-defined home screen tile pointing anywhere in the app — a
/// knowledge page, a person, a specific recipe (WISH-0107).
class CustomShortcut {
  final String id;
  final String label;

  /// In-app route, e.g. `/knowledge/abc123`. Free-form: the app has too
  /// many addressable things to enumerate, and an unknown route simply
  /// fails to match rather than corrupting anything.
  final String route;

  final String iconKey;

  CustomShortcut({
    String? id,
    required this.label,
    required this.route,
    this.iconKey = kDefaultShortcutIcon,
  }) : id = id ?? const Uuid().v4();

  /// Key used in the home screen order, namespaced so a shortcut can
  /// never collide with a built-in tile's key.
  String get orderKey => 'custom:$id';

  IconData get icon => shortcutIcon(iconKey);

  /// Rendered by the same grid as the built-in tiles. Never a shell
  /// branch: a shortcut points at an arbitrary route, so it is pushed.
  DashboardTile asTile() => DashboardTile(
    key: orderKey,
    icon: icon,
    label: label,
    color: Colors.blueGrey,
    route: route,
  );

  CustomShortcut copyWith({String? label, String? route, String? iconKey}) =>
      CustomShortcut(
        id: id,
        label: label ?? this.label,
        route: route ?? this.route,
        iconKey: iconKey ?? this.iconKey,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'route': route,
    'iconKey': iconKey,
  };

  factory CustomShortcut.fromMap(Map<String, dynamic> map) => CustomShortcut(
    id: map['id'] as String,
    label: map['label'] as String,
    route: map['route'] as String,
    iconKey: map['iconKey'] as String? ?? kDefaultShortcutIcon,
  );
}

/// Whether [route] is usable as a shortcut target. Kept deliberately
/// loose — anything the router might match starts with a slash.
String? validateShortcutRoute(String? route) {
  final value = route?.trim() ?? '';
  if (value.isEmpty) return 'A route is required';
  if (!value.startsWith('/')) return 'Routes start with /';
  return null;
}
