import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../services/widget_service.dart';
import 'section_header.dart';

/// Home-screen widget management. Only renders on Android — other
/// platforms either don't have a widget host (web/desktop) or use a
/// different model the user manages outside the app (iOS via long-press).
class WidgetsSection extends StatelessWidget {
  const WidgetsSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader('Widgets'),
        ListTile(
          leading: const Icon(Icons.today_outlined),
          title: const Text('Add Daily Task Preview'),
          subtitle: const Text('Tasks due today on your home screen'),
          trailing: const Icon(Icons.add),
          onTap: () => _pinWidget(context, 'daily'),
        ),
        ListTile(
          leading: const Icon(Icons.construction_outlined),
          title: const Text('Add WIP Items'),
          subtitle: const Text(
            'Work-in-progress items across recipes, knowledge, '
            'shopping, and feedback',
          ),
          trailing: const Icon(Icons.add),
          onTap: () => _pinWidget(context, 'wip'),
        ),
      ],
    );
  }

  Future<void> _pinWidget(BuildContext context, String widget) async {
    final added = await WidgetService.requestPinWidget(widget: widget);
    if (!added && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pinning widgets is not supported on this launcher'),
        ),
      );
    }
  }
}
