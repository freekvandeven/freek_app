import 'package:flutter/material.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/feedback_entry.dart';
import '../providers/feedback_providers.dart';

class FeedbackListPage extends ConsumerWidget {
  const FeedbackListPage({super.key});

  void _copyAllToClipboard(
      BuildContext context, List<FeedbackEntry> entries) {
    final bugs = entries.where((e) => e.type == FeedbackType.bug).toList();
    final wishes = entries.where((e) => e.type == FeedbackType.wish).toList();

    final buffer = StringBuffer();
    buffer.writeln('# Freek App — Feedback & Improvement Instructions');
    buffer.writeln();
    buffer.writeln(
        'Below is a list of user-reported feedback items for the Freek App '
        '(a Flutter personal life-management app). Each item is either a bug '
        'report or a feature wish. Please address each item listed below.');
    buffer.writeln();
    buffer.writeln('## Instructions');
    buffer.writeln();
    buffer.writeln(
        'For EACH individual item below, follow these steps before moving on '
        'to the next item:');
    buffer.writeln(
        '1. Implement the fix or feature for that single item.');
    buffer.writeln(
        '2. Update the relevant project documentation under `docs/` '
        '(e.g. `docs/requirements/screens.md`, `docs/requirements/user_stories.md`, '
        '`docs/requirements/data_model.md`) to reflect any new or changed behavior.');
    buffer.writeln(
        '3. If a new feature is added, consider whether it needs a new feature spec '
        'in `docs/requirements/features/`.');
    buffer.writeln(
        '4. If a technical decision was made, document it in '
        '`docs/requirements/tech_decisions.md` or create an ADR in `docs/decisions/`.');
    buffer.writeln(
        '5. Update `CHANGELOG.md` (in the personal_app directory) under the '
        'current version\'s `### Added`, `### Changed`, or `### Fixed` section '
        'with a brief description of what was done.');
    buffer.writeln(
        '6. **Commit immediately** with a descriptive conventional commit message '
        '(e.g. `fix: resolve biometric lock not triggering at startup` or '
        '`feat: add recipe image upload via Firebase Storage`). '
        'Do NOT batch multiple items into a single commit.');
    buffer.writeln();
    buffer.writeln(
        'Each item = one commit. Keep commits small and focused.');
    buffer.writeln();

    if (bugs.isNotEmpty) {
      buffer.writeln('## Bugs (${bugs.length})');
      buffer.writeln();
      for (final bug in bugs) {
        buffer.writeln('### [Bug] ${bug.title}');
        buffer.writeln();
        buffer.writeln(bug.description);
        buffer.writeln();
        buffer.writeln(
            '- Status: ${bug.status.name[0].toUpperCase()}${bug.status.name.substring(1)}');
        buffer.writeln(
            '- Reported: ${bug.createdAt.toIso8601String().substring(0, 10)}');
        buffer.writeln();
      }
    }

    if (wishes.isNotEmpty) {
      buffer.writeln('## Wishes (${wishes.length})');
      buffer.writeln();
      for (final wish in wishes) {
        buffer.writeln('### [Wish] ${wish.title}');
        buffer.writeln();
        buffer.writeln(wish.description);
        buffer.writeln();
        buffer.writeln(
            '- Status: ${wish.status.name[0].toUpperCase()}${wish.status.name.substring(1)}');
        buffer.writeln(
            '- Reported: ${wish.createdAt.toIso8601String().substring(0, 10)}');
        buffer.writeln();
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Copied ${entries.length} feedback item${entries.length == 1 ? '' : 's'} to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(filteredFeedbackProvider);
    final typeFilter = ref.watch(feedbackTypeFilterProvider);
    final statusFilter = ref.watch(feedbackStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Feedback')),
        actions: [
          entriesAsync.whenOrNull(
            data: (entries) => entries.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.copy_all),
                    tooltip: 'Copy all to clipboard',
                    onPressed: () =>
                        _copyAllToClipboard(context, entries),
                  )
                : null,
          ) ?? const SizedBox.shrink(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'all_types') {
                ref.read(feedbackTypeFilterProvider.notifier).state = null;
              } else if (value == 'wish') {
                ref.read(feedbackTypeFilterProvider.notifier).state =
                    FeedbackType.wish;
              } else if (value == 'bug') {
                ref.read(feedbackTypeFilterProvider.notifier).state =
                    FeedbackType.bug;
              } else if (value == 'all_status') {
                ref.read(feedbackStatusFilterProvider.notifier).state = null;
              } else {
                ref.read(feedbackStatusFilterProvider.notifier).state =
                    FeedbackStatus.values.byName(value);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(enabled: false, child: Text('Type')),
              CheckedPopupMenuItem(
                value: 'all_types',
                checked: typeFilter == null,
                child: const Text('All'),
              ),
              CheckedPopupMenuItem(
                value: 'wish',
                checked: typeFilter == FeedbackType.wish,
                child: const Text('Wishes'),
              ),
              CheckedPopupMenuItem(
                value: 'bug',
                checked: typeFilter == FeedbackType.bug,
                child: const Text('Bugs'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(enabled: false, child: Text('Status')),
              CheckedPopupMenuItem(
                value: 'all_status',
                checked: statusFilter == null,
                child: const Text('All'),
              ),
              for (final s in FeedbackStatus.values)
                CheckedPopupMenuItem(
                  value: s.name,
                  checked: statusFilter == s,
                  child: Text(s.name[0].toUpperCase() + s.name.substring(1)),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/feedback/new'),
        child: const Icon(Icons.add),
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Text('No feedback entries yet.\nTap + to add one.'),
            );
          }
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _FeedbackTile(entry: entry);
            },
          );
        },
      ),
    );
  }
}

class _FeedbackTile extends ConsumerWidget {
  final FeedbackEntry entry;
  const _FeedbackTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = entry.type == FeedbackType.bug
        ? Colors.red
        : Theme.of(context).colorScheme.primary;
    final icon = entry.type == FeedbackType.bug
        ? Icons.bug_report
        : Icons.lightbulb;

    return ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          entry.title,
          style: entry.status == FeedbackStatus.resolved
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
        subtitle: Text(
          '${entry.status.name[0].toUpperCase()}${entry.status.name.substring(1)}'
          ' · ${entry.createdAt.toIso8601String().substring(0, 10)}',
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) async {
            switch (value) {
              case 'copy':
                Clipboard.setData(
                    ClipboardData(text: entry.toClipboardText()));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                }
              case 'resolve':
                await ref.read(feedbackListProvider.notifier).updateEntry(
                      entry.copyWith(status: FeedbackStatus.resolved),
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Marked as resolved')),
                  );
                }
              case 'delete':
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete feedback?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref
                      .read(feedbackListProvider.notifier)
                      .deleteEntry(entry.id);
                }
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'copy',
              child: ListTile(
                leading: Icon(Icons.copy),
                title: Text('Copy'),
                dense: true,
              ),
            ),
            if (entry.status != FeedbackStatus.resolved)
              const PopupMenuItem(
                value: 'resolve',
                child: ListTile(
                  leading: Icon(Icons.check_circle_outline),
                  title: Text('Resolve'),
                  dense: true,
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                dense: true,
              ),
            ),
          ],
        ),
        onTap: () => context.push('/feedback/${entry.id}'),
    );
  }
}
