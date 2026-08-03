import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/app_config.dart';
import '../../../services/image_upload_service.dart';
import '../../../services/log_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/task.dart';
import '../services/firestore_task_service.dart';
import '../services/task_service.dart';

final taskServiceProvider = Provider<TaskService>((ref) {
  if (AppConfig.useFirebase) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return FirestoreTaskService(userId);
  }
  final service = MockTaskService(SharedPreferencesAsync());
  ref.onDispose(service.dispose);
  return service;
});

final taskListProvider = StreamNotifierProvider<TaskListNotifier, List<Task>>(
  TaskListNotifier.new,
);

class TaskListNotifier extends StreamNotifier<List<Task>> {
  TaskService get _service => ref.read(taskServiceProvider);

  @override
  Stream<List<Task>> build() {
    return ref.watch(taskServiceProvider).watchTasks();
  }

  Future<void> addTask(Task task) async {
    await _service.createTask(task);
    LogService.instance.info('Task created: ${task.title}');
  }

  Future<void> updateTask(Task task) async {
    await _service.updateTask(task);
    LogService.instance.info('Task updated: ${task.id}');
  }

  Future<void> deleteTask(String id) async {
    // Delete associated images from Storage
    final task = await _service.getTask(id);
    if (task != null && task.attachments.isNotEmpty) {
      final uploader = ref.read(imageUploadServiceProvider);
      for (final url in task.attachments) {
        await uploader.deleteImage(url);
      }
    }
    // Unlink any subtasks so children don't end up orphaned with a dangling
    // parentTaskId. Children become root tasks; users can re-link or delete.
    final all = state.valueOrNull ?? [];
    for (final child in all.where((t) => t.parentTaskId == id)) {
      await _service.updateTask(child.copyWith(clearParentTaskId: true));
    }
    await _service.deleteTask(id);
    LogService.instance.info('Task deleted: $id');
  }

  /// Returns null on success, or a user-facing reason string when the toggle
  /// was refused (currently: completing a parent task whose subtasks are not
  /// all done yet). Uncompleting is always allowed.
  Future<String?> toggleComplete(Task task) async {
    if (!task.isCompleted) {
      // Block completion if any subtask is still open.
      final all = state.valueOrNull ?? [];
      final openSubtasks = all
          .where((t) => t.parentTaskId == task.id && !t.isCompleted)
          .length;
      if (openSubtasks > 0) {
        return 'Complete the $openSubtasks remaining subtask'
            '${openSubtasks == 1 ? '' : 's'} first';
      }
      // Mark as completed
      final updated = task.copyWith(
        isCompleted: true,
        completedAt: DateTime.now(),
      );
      await _service.updateTask(updated);
      LogService.instance.info('Task completed: ${task.id}');

      // If repeatable, create next instance
      final nextDue = task.nextDueDate;
      if (task.isRepeatable && nextDue != null) {
        final nextTask = Task(
          title: task.title,
          description: task.description,
          dueDate: nextDue,
          priority: task.priority,
          category: task.category,
          isRepeatable: task.isRepeatable,
          repeatType: task.repeatType,
          repeatInterval: task.repeatInterval,
          repeatEndDate: task.repeatEndDate,
        );
        await _service.createTask(nextTask);
      }
    } else {
      // Mark as not completed — always allowed, per spec.
      final updated = task.copyWith(isCompleted: false, clearCompletedAt: true);
      await _service.updateTask(updated);
    }
    return null;
  }
}

enum TaskFilter { all, pending, completed }

enum TaskSort { dueDate, priority, createdDate, estimatedDuration }

final taskFilterProvider = StateProvider<TaskFilter>(
  (ref) => TaskFilter.pending,
);
final taskSortProvider = StateProvider<TaskSort>((ref) => TaskSort.dueDate);
final taskCategoryFilterProvider = StateProvider<String?>((ref) => null);

final filteredTasksProvider = Provider<AsyncValue<List<Task>>>((ref) {
  final tasksAsync = ref.watch(taskListProvider);
  final filter = ref.watch(taskFilterProvider);
  final sort = ref.watch(taskSortProvider);
  final categoryFilter = ref.watch(taskCategoryFilterProvider);

  return tasksAsync.whenData((tasks) {
    var filtered = switch (filter) {
      TaskFilter.all => tasks,
      TaskFilter.pending => tasks.where((t) => !t.isCompleted).toList(),
      TaskFilter.completed => tasks.where((t) => t.isCompleted).toList(),
    };

    if (categoryFilter != null) {
      filtered = filtered.where((t) => t.category == categoryFilter).toList();
    }

    filtered.sort((a, b) {
      return switch (sort) {
        TaskSort.dueDate => _compareDates(a.dueDate, b.dueDate),
        TaskSort.priority => b.priority.index.compareTo(a.priority.index),
        TaskSort.createdDate => b.createdAt.compareTo(a.createdAt),
        // Quickest first, so quick wins float to the top (WISH-0094).
        // Un-estimated tasks sink to the bottom, same nulls-last
        // convention as _compareDates.
        TaskSort.estimatedDuration => _compareEstimatedMinutes(
          a.estimatedMinutes,
          b.estimatedMinutes,
        ),
      };
    });

    return filtered;
  });
});

int _compareDates(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

int _compareEstimatedMinutes(int? a, int? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

final taskCategoriesProvider = Provider<List<String>>((ref) {
  final tasks = ref.watch(taskListProvider).valueOrNull ?? [];
  final categories = tasks
      .map((t) => t.category)
      .whereType<String>()
      .toSet()
      .toList();
  categories.sort();
  return categories;
});
