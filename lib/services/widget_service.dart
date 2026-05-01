import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../features/tasks/models/task.dart';

class WidgetService {
  static const _appGroupId = 'group.nl.freekvandeven.personal_app';
  static const _androidWidgetName = 'HomeWidgetProvider';
  static const _iOSWidgetName = 'TasksWidget';

  static bool get _isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> initialize() async {
    if (!_isSupported) return;
    if (Platform.isIOS) {
      await HomeWidget.setAppGroupId(_appGroupId);
    }
  }

  static Future<void> updateTaskWidget(List<Task> allTasks) async {
    if (!_isSupported) return;

    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    final dueTasks =
        allTasks
            .where(
              (t) =>
                  !t.isCompleted &&
                  t.dueDate != null &&
                  t.dueDate!.isBefore(tomorrow),
            )
            .toList()
          ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    final today = DateTime(now.year, now.month, now.day);
    final lines = dueTasks.take(5).map((t) {
      final d = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      final isOverdue = d.isBefore(today);
      return '${isOverdue ? '⚠ ' : '• '}${t.title}';
    });

    final content = dueTasks.isEmpty ? 'No tasks due today' : lines.join('\n');
    final count = dueTasks.length;

    await HomeWidget.saveWidgetData<String>('tasks_content', content);
    await HomeWidget.saveWidgetData<String>('tasks_count', count.toString());
    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
      iOSName: _iOSWidgetName,
    );
  }
}
