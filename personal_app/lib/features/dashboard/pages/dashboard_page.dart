import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:personal_app/features/auth/providers/auth_providers.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: QuickActionsTitle(child: Text('Personal App')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Hi, ${user?.displayName ?? user?.email.split('@').first ?? 'there'}!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'What would you like to do today?',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _buildFeatureGrid(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid(BuildContext context, ColorScheme colorScheme) {
    final features = [
      _FeatureTile(
        icon: Icons.check_circle_rounded,
        label: 'Tasks',
        color: Colors.blue,
        route: '/tasks',
        isShellBranch: true,
      ),
      _FeatureTile(
        icon: Icons.calendar_month_rounded,
        label: 'Calendar',
        color: Colors.purple,
        route: '/calendar',
        isShellBranch: true,
      ),
      _FeatureTile(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Finance',
        color: Colors.green,
        route: '/finance',
        isShellBranch: true,
      ),
      _FeatureTile(
        icon: Icons.restaurant_menu_rounded,
        label: 'Recipes',
        color: Colors.orange,
        route: '/recipes',
      ),
      _FeatureTile(
        icon: Icons.lock_rounded,
        label: 'Passwords',
        color: Colors.red,
        route: '/passwords',
      ),
      _FeatureTile(
        icon: Icons.inventory_2_rounded,
        label: 'Inventory',
        color: Colors.teal,
        route: '/inventory',
      ),
      _FeatureTile(
        icon: Icons.menu_book_rounded,
        label: 'Knowledge',
        color: Colors.indigo,
        route: '/knowledge',
      ),
      _FeatureTile(
        icon: Icons.feedback_rounded,
        label: 'Feedback',
        color: Colors.amber,
        route: '/feedback',
      ),
      _FeatureTile(
        icon: Icons.link_rounded,
        label: 'Connections',
        color: Colors.cyan,
        route: '/connections',
      ),
      _FeatureTile(
        icon: Icons.auto_awesome_rounded,
        label: 'Gemini AI',
        color: Colors.deepPurple,
        route: '/gemini',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return _buildTile(context, feature, colorScheme);
      },
    );
  }

  Widget _buildTile(
    BuildContext context,
    _FeatureTile feature,
    ColorScheme colorScheme,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => feature.isShellBranch
            ? context.go(feature.route)
            : context.push(feature.route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(feature.icon, size: 32, color: feature.color),
              const SizedBox(height: 8),
              Text(
                feature.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile {
  final IconData icon;
  final String label;
  final Color color;
  final String route;
  final bool isShellBranch;

  const _FeatureTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
    this.isShellBranch = false,
  });
}
