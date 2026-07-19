import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';

abstract class TaskService {
  Future<List<Task>> getTasks();

  /// Emits the full task list on listen and again after every change,
  /// so consumers never need to re-fetch after a mutation (IMPR-0018).
  Stream<List<Task>> watchTasks();
  Future<Task> createTask(Task task);
  Future<Task> updateTask(Task task);
  Future<void> deleteTask(String id);
  Future<Task?> getTask(String id);
}

class MockTaskService implements TaskService {
  final SharedPreferencesAsync _prefs;
  static const _key = 'mock_tasks';
  final _changes = StreamController<List<Task>>.broadcast();

  MockTaskService(this._prefs);

  @override
  Future<List<Task>> getTasks() async {
    final json = await _prefs.getString(_key);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => Task.fromMap(e as Map<String, dynamic>)).toList();
  }

  @override
  Stream<List<Task>> watchTasks() async* {
    yield await getTasks();
    yield* _changes.stream;
  }

  @override
  Future<Task> createTask(Task task) async {
    final tasks = await getTasks();
    tasks.add(task);
    await _save(tasks);
    return task;
  }

  @override
  Future<Task> updateTask(Task task) async {
    final tasks = await getTasks();
    final index = tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) throw Exception('Task not found');
    tasks[index] = task;
    await _save(tasks);
    return task;
  }

  @override
  Future<void> deleteTask(String id) async {
    final tasks = await getTasks();
    tasks.removeWhere((t) => t.id == id);
    await _save(tasks);
  }

  @override
  Future<Task?> getTask(String id) async {
    final tasks = await getTasks();
    return tasks.where((t) => t.id == id).firstOrNull;
  }

  Future<void> _save(List<Task> tasks) async {
    await _prefs.setString(
      _key,
      jsonEncode(tasks.map((t) => t.toMap()).toList()),
    );
    _changes.add(List.of(tasks));
  }

  void dispose() {
    _changes.close();
  }
}
