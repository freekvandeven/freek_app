import 'package:flutter/material.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../providers/task_providers.dart';

class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(filteredTasksProvider);
    final filter = ref.watch(taskFilterProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Tasks')),
        actions: [
          PopupMenuButton<TaskSort>(
            icon: const Icon(Icons.sort),
            onSelected: (sort) =>
                ref.read(taskSortProvider.notifier).state = sort,
            itemBuilder: (context) => const [
              PopupMenuItem(value: TaskSort.dueDate, child: Text('Due Date')),
              PopupMenuItem(value: TaskSort.priority, child: Text('Priority')),
              PopupMenuItem(
                value: TaskSort.createdDate,
                child: Text('Created Date'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<TaskFilter>(
              segments: const [
                ButtonSegment(
                  value: TaskFilter.pending,
                  label: Text('Pending'),
                ),
                ButtonSegment(value: TaskFilter.all, label: Text('All')),
                ButtonSegment(value: TaskFilter.completed, label: Text('Done')),
              ],
              selected: {filter},
              onSelectionChanged: (selection) =>
                  ref.read(taskFilterProvider.notifier).state = selection.first,
            ),
          ),
          Expanded(
            child: tasksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (tasks) => tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: colorScheme.onSurfaceVariant.withAlpha(100),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            filter == TaskFilter.completed
                                ? 'No completed tasks'
                                : 'No tasks yet',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) =>
                          _TaskTile(task: tasks[index]),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/tasks/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  final Task task;
  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: colorScheme.error,
        child: Icon(Icons.delete, color: colorScheme.onError),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Task'),
            content: Text('Delete "${task.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) =>
          ref.read(taskListProvider.notifier).deleteTask(task.id),
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (_) =>
              ref.read(taskListProvider.notifier).toggleComplete(task),
        ),
        title: Text(
          task.title,
          style: task.isCompleted
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
        subtitle: _buildSubtitle(context, colorScheme),
        trailing: _priorityIcon(task.priority, colorScheme),
        onTap: () => context.push('/tasks/${task.id}'),
      ),
    );
  }

  Widget? _buildSubtitle(BuildContext context, ColorScheme colorScheme) {
    final parts = <Widget>[];
    if (task.dueDate != null) {
      final isOverdue =
          !task.isCompleted && task.dueDate!.isBefore(DateTime.now());
      final dateText = task.hasDueTime
          ? '${DateFormat.MMMd().format(task.dueDate!)} ${DateFormat.Hm().format(task.dueDate!)}'
          : DateFormat.MMMd().format(task.dueDate!);
      parts.add(
        Text(
          dateText,
          style: TextStyle(
            color: isOverdue ? colorScheme.error : null,
            fontWeight: isOverdue ? FontWeight.bold : null,
          ),
        ),
      );
    }
    if (task.category != null) {
      parts.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            task.category!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      );
    }
    if (task.isRepeatable) {
      parts.add(Icon(Icons.repeat, size: 14, color: colorScheme.primary));
    }
    if (task.attachments.isNotEmpty) {
      parts.add(Icon(Icons.attach_file, size: 14, color: colorScheme.primary));
    }
    if (parts.isEmpty) return null;
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: parts,
    );
  }

  Widget _priorityIcon(TaskPriority priority, ColorScheme colorScheme) {
    return switch (priority) {
      TaskPriority.high => Icon(Icons.flag, color: colorScheme.error, size: 20),
      TaskPriority.medium => Icon(Icons.flag, color: Colors.orange, size: 20),
      TaskPriority.low => Icon(
        Icons.flag_outlined,
        color: colorScheme.outline,
        size: 20,
      ),
    };
  }
}
