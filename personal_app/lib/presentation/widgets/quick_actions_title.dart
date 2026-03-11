import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Wraps any AppBar title widget with a long-press gesture that opens
/// the app-wide Quick Actions bottom sheet.
class QuickActionsTitle extends StatelessWidget {
  final Widget child;

  const QuickActionsTitle({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => showQuickActions(context),
      child: child,
    );
  }
}

void showQuickActions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report, color: Colors.red),
            title: const Text('Report a Bug'),
            onTap: () {
              Navigator.pop(ctx);
              context.push('/feedback/new?type=bug');
            },
          ),
          ListTile(
            leading: Icon(Icons.lightbulb,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Request a Feature'),
            onTap: () {
              Navigator.pop(ctx);
              context.push('/feedback/new?type=wish');
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_task),
            title: const Text('New Task'),
            onTap: () {
              Navigator.pop(ctx);
              context.push('/tasks');
            },
          ),
          ListTile(
            leading: const Icon(Icons.restaurant_menu),
            title: const Text('New Recipe'),
            onTap: () {
              Navigator.pop(ctx);
              context.push('/recipes/new');
            },
          ),
          ListTile(
            leading: const Icon(Icons.note_add),
            title: const Text('New Knowledge Entry'),
            onTap: () {
              Navigator.pop(ctx);
              context.push('/knowledge/new');
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
