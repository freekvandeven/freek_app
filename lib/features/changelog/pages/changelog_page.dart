import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';

import '../data/changelog_parser.dart';
import '../models/changelog_entry.dart';

class ChangelogPage extends StatelessWidget {
  const ChangelogPage({super.key});

  Future<({List<ChangelogEntry> entries, String appVersion})>
  _loadChangelog() async {
    final markdown = await rootBundle.loadString('CHANGELOG.md');
    final info = await PackageInfo.fromPlatform();
    return (entries: parseChangelog(markdown), appVersion: info.version);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const QuickActionsTitle(child: Text('Changelog'))),
      body: FutureBuilder<({List<ChangelogEntry> entries, String appVersion})>(
        future: _loadChangelog(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Could not load changelog.'));
          }
          final entries = snapshot.data!.entries;
          final appVersion = snapshot.data!.appVersion;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final isCurrentVersion = entry.version == appVersion;
              return _VersionCard(
                entry: entry,
                isLatest: !entry.isUnreleased && isCurrentVersion,
              );
            },
          );
        },
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  final ChangelogEntry entry;
  final bool isLatest;

  const _VersionCard({required this.entry, required this.isLatest});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.isUnreleased)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.tertiaryContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.construction,
                    size: 16,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'You are running an unreleased build',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.isUnreleased ? 'Unreleased' : 'v${entry.version}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isLatest) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Current',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (entry.date != null)
                      Text(
                        entry.date!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (entry.added.isNotEmpty)
                  _Section(
                    icon: Icons.add_circle_outline,
                    label: 'Added',
                    color: Colors.green,
                    items: entry.added,
                  ),
                if (entry.changed.isNotEmpty)
                  _Section(
                    icon: Icons.change_circle_outlined,
                    label: 'Changed',
                    color: Colors.orange,
                    items: entry.changed,
                  ),
                if (entry.fixed.isNotEmpty)
                  _Section(
                    icon: Icons.bug_report_outlined,
                    label: 'Fixed',
                    color: Colors.red,
                    items: entry.fixed,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final List<String> items;

  const _Section({
    required this.icon,
    required this.label,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 12)),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
