import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/feedback_entry.dart';
import '../providers/feedback_providers.dart';

class FeedbackListPage extends ConsumerWidget {
  const FeedbackListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(filteredFeedbackProvider);
    final typeFilter = ref.watch(feedbackTypeFilterProvider);
    final statusFilter = ref.watch(feedbackStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback'),
        actions: [
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

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
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
      },
      onDismissed: (_) {
        ref.read(feedbackListProvider.notifier).deleteEntry(entry.id);
      },
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(entry.title),
        subtitle: Text(
          '${entry.status.name[0].toUpperCase()}${entry.status.name.substring(1)}'
          ' · ${entry.createdAt.toIso8601String().substring(0, 10)}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy),
          tooltip: 'Copy to clipboard',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: entry.toClipboardText()));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied to clipboard')),
            );
          },
        ),
        onTap: () => context.push('/feedback/${entry.id}'),
      ),
    );
  }
}
