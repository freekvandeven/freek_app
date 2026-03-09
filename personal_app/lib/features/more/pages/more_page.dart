import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          _buildSection(context, 'Features', [
            _MenuItem(
              icon: Icons.restaurant_menu_rounded,
              label: 'Recipes',
              route: '/recipes',
            ),
            _MenuItem(
              icon: Icons.lock_rounded,
              label: 'Password Vault',
              route: '/passwords',
            ),
            _MenuItem(
              icon: Icons.inventory_2_rounded,
              label: 'Inventory',
              route: '/inventory',
            ),
            _MenuItem(
              icon: Icons.menu_book_rounded,
              label: 'Knowledge Bank',
              route: '/knowledge',
            ),
            _MenuItem(
              icon: Icons.feedback_rounded,
              label: 'Feedback',
              route: '/feedback',
            ),
            _MenuItem(
              icon: Icons.link_rounded,
              label: 'Connections',
              route: '/connections',
            ),
            _MenuItem(
              icon: Icons.auto_awesome_rounded,
              label: 'Gemini AI',
              route: '/gemini',
            ),
          ]),
          _buildSection(context, 'App', [
            _MenuItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              route: '/settings',
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<_MenuItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ...items.map(
          (item) => ListTile(
            leading: Icon(item.icon),
            title: Text(item.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(item.route),
          ),
        ),
      ],
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String route;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}
