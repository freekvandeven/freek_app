import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:personal_app/features/auth/providers/auth_providers.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import '../../../services/version_check_service.dart';
import '../../calendar/models/calendar_event.dart';
import '../../calendar/providers/calendar_providers.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _versionChecked = false;

  void _checkVersion() {
    if (_versionChecked) return;
    _versionChecked = true;

    final status = ref.read(versionCheckProvider).valueOrNull;
    if (status == null) return;

    if (status.updateRequired) {
      _showUpdateDialog(status, required: true);
    } else if (status.updateAvailable) {
      _showUpdateDialog(status, required: false);
    }
  }

  void _showUpdateDialog(VersionStatus status, {required bool required}) {
    showDialog(
      context: context,
      barrierDismissible: !required,
      builder: (context) => AlertDialog(
        title: Text(required ? 'Update Required' : 'Update Available'),
        content: Text(
          required
              ? 'A new version (${status.latest ?? status.minRequired}) is required. '
                    'Your current version (${status.current}) is no longer supported.'
              : 'A new version (${status.latest}) is available. '
                    'You are running ${status.current}.',
        ),
        actions: [
          if (!required)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          FilledButton(
            onPressed: () {
              if (status.updateUrl != null) {
                launchUrl(Uri.parse(status.updateUrl!));
              }
              if (!required) Navigator.of(context).pop();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Listen for version check completion
    ref.listen(versionCheckProvider, (_, next) {
      if (next.hasValue) _checkVersion();
    });

    return Scaffold(
      appBar: AppBar(
        title: QuickActionsTitle(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Personal App'),
              if (ref.watch(versionCheckProvider).valueOrNull?.isDevBuild ??
                  false) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'DEV',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onTertiary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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
          _buildThisWeek(context, ref),
          const SizedBox(height: 24),
          _buildFeatureGrid(context, colorScheme),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () => context.push('/settings/changelog'),
              icon: const Icon(Icons.new_releases_outlined),
              label: const Text("What's New"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThisWeek(BuildContext context, WidgetRef ref) {
    final events = ref.watch(thisWeekEventsProvider);
    if (events.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.date_range, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('This Week', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        ...events.take(5).map((e) {
          final eventDay = DateTime(e.date.year, e.date.month, e.date.day);
          final isToday = eventDay == today;
          final isPast = eventDay.isBefore(today);
          final dayLabel = isToday ? 'Today' : DateFormat.E().format(e.date);

          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: _eventColor(
                e,
              ).withValues(alpha: isPast ? 0.3 : 1.0),
              child: Icon(_eventIcon(e.type), size: 14, color: Colors.white),
            ),
            title: Text(
              e.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: isPast
                  ? TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : null,
            ),
            trailing: Text(
              dayLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isToday
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isToday ? FontWeight.bold : null,
              ),
            ),
            onTap: () => context.go('/calendar'),
          );
        }),
        if (events.length > 5)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: TextButton(
              onPressed: () => context.go('/calendar'),
              child: Text('+${events.length - 5} more'),
            ),
          ),
      ],
    );
  }

  Color _eventColor(CalendarEvent event) {
    if (event.color != null) {
      return Color(int.parse(event.color!));
    }
    return switch (event.type) {
      EventType.task => Colors.orange,
      EventType.finance => Colors.green,
      EventType.custom => Colors.purple,
    };
  }

  IconData _eventIcon(EventType type) {
    return switch (type) {
      EventType.task => Icons.check_circle_outline,
      EventType.finance => Icons.attach_money,
      EventType.custom => Icons.event,
    };
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
      _FeatureTile(
        icon: Icons.forum_rounded,
        label: 'Conversations',
        color: Colors.pink,
        route: '/conversations',
      ),
      _FeatureTile(
        icon: Icons.people_rounded,
        label: 'People',
        color: Colors.brown,
        route: '/people',
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
