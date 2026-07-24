import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_app/presentation/widgets/app_snackbar.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';

import '../../../presentation/widgets/pullable_center.dart';
import '../../contacts/providers/contact_providers.dart';
import '../models/conversation_topic.dart';
import '../providers/conversation_providers.dart';

class ConversationListPage extends ConsumerWidget {
  const ConversationListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(filteredConversationsProvider);
    final personFilter = ref.watch(conversationPersonFilterProvider);
    final statusFilter = ref.watch(conversationStatusFilterProvider);
    final sort = ref.watch(conversationSortProvider);
    final personsAsync = ref.watch(conversationPersonsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Conversations')),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: (value) {
              ref.read(conversationSortProvider.notifier).state =
                  ConversationSort.values.byName(value);
            },
            itemBuilder: (_) => ConversationSort.values
                .map(
                  (s) => PopupMenuItem(
                    value: s.name,
                    child: Row(
                      children: [
                        if (sort == s)
                          const Icon(Icons.check, size: 18)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(_sortLabel(s)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              switch (value) {
                case 'status_all':
                  ref.read(conversationStatusFilterProvider.notifier).state =
                      null;
                case 'status_open':
                  ref.read(conversationStatusFilterProvider.notifier).state =
                      TopicStatus.open;
                case 'status_resolved':
                  ref.read(conversationStatusFilterProvider.notifier).state =
                      TopicStatus.resolved;
                case 'person_all':
                  ref.read(conversationPersonFilterProvider.notifier).state =
                      null;
                default:
                  if (value.startsWith('person:')) {
                    ref.read(conversationPersonFilterProvider.notifier).state =
                        value.substring(7);
                  }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                enabled: false,
                child: Text(
                  'Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              PopupMenuItem(
                value: 'status_all',
                child: _filterItem('All', statusFilter == null),
              ),
              PopupMenuItem(
                value: 'status_open',
                child: _filterItem('Open', statusFilter == TopicStatus.open),
              ),
              PopupMenuItem(
                value: 'status_resolved',
                child: _filterItem(
                  'Resolved',
                  statusFilter == TopicStatus.resolved,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                enabled: false,
                child: Text(
                  'Person / Group',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              PopupMenuItem(
                value: 'person_all',
                child: _filterItem('All', personFilter == null),
              ),
              if (personsAsync.hasValue)
                ...personsAsync.value!.map(
                  (p) => PopupMenuItem<String>(
                    value: 'person:$p',
                    child: _filterItem(p, personFilter == p),
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/conversations/new'),
        child: const Icon(Icons.add),
      ),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(conversationListProvider.future),
          child: topicsAsync.when(
            loading: () =>
                const PullableCenter(child: CircularProgressIndicator()),
            error: (e, _) => PullableCenter(child: Text('Error: $e')),
            data: (topics) {
              if (topics.isEmpty) {
                return PullableCenter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.forum_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      const Text('No conversation topics yet'),
                    ],
                  ),
                );
              }
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: topics.length,
                itemBuilder: (context, index) =>
                    _TopicTile(topic: topics[index]),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _filterItem(String label, bool selected) => Row(
    children: [
      if (selected)
        const Icon(Icons.check, size: 18)
      else
        const SizedBox(width: 18),
      const SizedBox(width: 8),
      Text(label),
    ],
  );

  String _sortLabel(ConversationSort s) {
    switch (s) {
      case ConversationSort.priorityDesc:
        return 'Priority (high first)';
      case ConversationSort.priorityAsc:
        return 'Priority (low first)';
      case ConversationSort.newest:
        return 'Newest first';
      case ConversationSort.oldest:
        return 'Oldest first';
    }
  }
}

class _TopicTile extends ConsumerWidget {
  final ConversationTopic topic;
  const _TopicTile({required this.topic});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priorityColor = switch (topic.priority) {
      TopicPriority.high => Colors.red,
      TopicPriority.medium => Colors.orange,
      TopicPriority.low => Colors.green,
    };
    final priorityIcon = switch (topic.priority) {
      TopicPriority.high => Icons.keyboard_double_arrow_up,
      TopicPriority.medium => Icons.remove,
      TopicPriority.low => Icons.keyboard_double_arrow_down,
    };

    // Prefer the linked Contact's name when available; fall back to the
    // legacy free-text label for conversations created before WISH-0076.
    final linkedContact = topic.contactId == null
        ? null
        : ref.watch(contactByIdProvider(topic.contactId!));
    final personLabel = linkedContact?.name ?? topic.personOrGroup;

    return ListTile(
      leading: Icon(priorityIcon, color: priorityColor),
      title: Text(
        topic.title,
        style: topic.status == TopicStatus.resolved
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Text(
        '$personLabel'
        ' · ${topic.updatedAt.toIso8601String().substring(0, 10)}'
        '${topic.status == TopicStatus.resolved ? ' · Resolved' : ''}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (topic.imageUrls.isNotEmpty)
            const Icon(Icons.image, size: 18, color: Colors.grey),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'resolve':
                  await ref
                      .read(conversationListProvider.notifier)
                      .updateTopic(
                        topic.copyWith(
                          status: TopicStatus.resolved,
                          resolvedAt: DateTime.now(),
                        ),
                      );
                  if (context.mounted) {
                    context.showSuccessSnackbar('Marked as resolved');
                  }
                case 'reopen':
                  await ref
                      .read(conversationListProvider.notifier)
                      .updateTopic(
                        topic.copyWith(
                          status: TopicStatus.open,
                          clearResolvedAt: true,
                        ),
                      );
                case 'delete':
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete topic?'),
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
                        .read(conversationListProvider.notifier)
                        .deleteTopic(topic.id);
                  }
              }
            },
            itemBuilder: (_) => [
              if (topic.status == TopicStatus.open)
                const PopupMenuItem(
                  value: 'resolve',
                  child: ListTile(
                    leading: Icon(Icons.check_circle_outline),
                    title: Text('Resolve'),
                    dense: true,
                  ),
                ),
              if (topic.status == TopicStatus.resolved)
                const PopupMenuItem(
                  value: 'reopen',
                  child: ListTile(
                    leading: Icon(Icons.replay),
                    title: Text('Reopen'),
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
        ],
      ),
      onTap: () => context.push('/conversations/${topic.id}'),
    );
  }
}
