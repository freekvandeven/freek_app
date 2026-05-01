import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../features/tasks/models/task.dart';

class WidgetService {
  static const _appGroupId = 'group.nl.freekvandeven.personal_app';
  static const _androidWidgetName = 'DailyTaskWidgetProvider';
  static const _iOSWidgetName = 'TasksWidget';
  static const _channel = MethodChannel(
    'nl.freekvandeven.personal_app/widgets',
  );

  static bool get _isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> initialize() async {
    if (!_isSupported) return;
    if (Platform.isIOS) {
      await HomeWidget.setAppGroupId(_appGroupId);
    }
  }

  static Future<void> updateTaskWidget(
    List<Task> allTasks, {
    Color? seedColor,
  }) async {
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
    await HomeWidget.saveWidgetData<String>(
      'widget_color',
      seedColor != null ? seedColor.toARGB32().toRadixString(16) : '',
    );
    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
      iOSName: _iOSWidgetName,
    );
  }

  // Prompts the user to pin the Daily Task Preview widget to their home screen.
  // Returns true if the request was accepted, false if unsupported.
  static Future<bool> requestPinWidget() async {
    if (!_isSupported || !Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('requestPinWidget') ?? false;
  }
}
