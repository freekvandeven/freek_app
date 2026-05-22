import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';

import '../../admin/providers/admin_providers.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const QuickActionsTitle(child: Text('More'))),
      body: ResponsiveCenter(
        child: ListView(
          children: [
            _buildSection(context, 'Features', [
              // Shell-branch routes — use go() to properly activate the branch.
              const _MenuItem(
                icon: Icons.restaurant_menu_rounded,
                label: 'Recipes',
                route: '/recipes',
                useGo: true,
              ),
              const _MenuItem(
                icon: Icons.lock_rounded,
                label: 'Password Vault',
                route: '/passwords',
              ),
              const _MenuItem(
                icon: Icons.inventory_2_rounded,
                label: 'Inventory',
                route: '/inventory',
                useGo: true,
              ),
              const _MenuItem(
                icon: Icons.auto_stories_rounded,
                label: 'Catalog',
                route: '/catalog',
              ),
              const _MenuItem(
                icon: Icons.shopping_cart_rounded,
                label: 'Shopping List',
                route: '/shopping',
              ),
              const _MenuItem(
                icon: Icons.menu_book_rounded,
                label: 'Knowledge Bank',
                route: '/knowledge',
                useGo: true,
              ),
              const _MenuItem(
                icon: Icons.folder_rounded,
                label: 'Files',
                route: '/files',
              ),
              const _MenuItem(
                icon: Icons.feedback_rounded,
                label: 'Feedback',
                route: '/feedback',
              ),
              const _MenuItem(
                icon: Icons.forum_rounded,
                label: 'Conversations',
                route: '/conversations',
              ),
              const _MenuItem(
                icon: Icons.link_rounded,
                label: 'Connections',
                route: '/connections',
              ),
              const _MenuItem(
                icon: Icons.auto_awesome_rounded,
                label: 'Gemini AI',
                route: '/gemini',
                useGo: true,
              ),
              const _MenuItem(
                icon: Icons.people_rounded,
                label: 'People',
                route: '/people',
              ),
            ]),
            _buildSection(context, 'App', [
              const _MenuItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                route: '/settings',
              ),
              if (isAdmin)
                const _MenuItem(
                  icon: Icons.admin_panel_settings_rounded,
                  label: 'Admin',
                  route: '/admin',
                ),
            ]),
          ],
        ),
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
            onTap: () =>
                item.useGo ? context.go(item.route) : context.push(item.route),
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
  final bool useGo;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.route,
    this.useGo = false,
  });
}
