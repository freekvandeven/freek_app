import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../features/tasks/models/task.dart';
import '../features/wip/providers/wip_providers.dart';

class WidgetService {
  static const _appGroupId = 'group.nl.freekvandeven.personal_app';
  static const _dailyTaskAndroidName = 'DailyTaskWidgetProvider';
  static const _wipAndroidName = 'WipItemsWidgetProvider';
  static const _dailyTaskIOSName = 'TasksWidget';
  static const _wipIOSName = 'WipItemsWidget';
  static const _channel = MethodChannel(
    'nl.freekvandeven.personal_app/widgets',
  );

  static StreamSubscription<Uri?>? _clickSub;
  static bool _initialClickChecked = false;

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
    await _saveColor(seedColor);
    await HomeWidget.updateWidget(
      androidName: _dailyTaskAndroidName,
      iOSName: _dailyTaskIOSName,
    );
  }

  static Future<void> updateWipItemsWidget(
    List<WipItem> wipItems, {
    Color? seedColor,
  }) async {
    if (!_isSupported) return;

    final lines = wipItems.take(5).map((i) {
      final prefix = switch (i.source) {
        WipSource.recipe => '🍴',
        WipSource.knowledge => '📖',
        WipSource.shopping => '🛒',
        WipSource.feedback => '💬',
      };
      return '$prefix ${i.title}';
    });

    final content = wipItems.isEmpty
        ? 'No items in progress'
        : lines.join('\n');
    final count = wipItems.length;

    await HomeWidget.saveWidgetData<String>('wip_content', content);
    await HomeWidget.saveWidgetData<String>('wip_count', count.toString());
    await _saveColor(seedColor);
    await HomeWidget.updateWidget(
      androidName: _wipAndroidName,
      iOSName: _wipIOSName,
    );
  }

  static Future<void> _saveColor(Color? seedColor) async {
    await HomeWidget.saveWidgetData<String>(
      'widget_color',
      seedColor != null ? seedColor.toARGB32().toRadixString(16) : '',
    );
  }

  // Prompts the user to pin a widget to the home screen.
  // [widget] selects which provider to pin: 'daily' (default) or 'wip'.
  static Future<bool> requestPinWidget({String widget = 'daily'}) async {
    if (!_isSupported || !Platform.isAndroid) return false;
    final providerName = switch (widget) {
      'wip' => _wipAndroidName,
      _ => _dailyTaskAndroidName,
    };
    return await _channel.invokeMethod<bool>('requestPinWidget', {
          'widget': providerName,
        }) ??
        false;
  }

  // Subscribes to widget tap events. The callback fires for both cold-start
  // launches (initially launched from a widget) and warm-start clicks while
  // the app is running. Safe to call across rebuilds — the cold-start URI is
  // only delivered once per app lifecycle, the stream subscription is replaced.
  static void registerClickHandler(void Function(Uri uri) onClick) {
    if (!_isSupported) return;
    _clickSub?.cancel();
    _clickSub = HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) onClick(uri);
    });
    if (!_initialClickChecked) {
      _initialClickChecked = true;
      HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
        if (uri != null) onClick(uri);
      });
    }
  }
}
