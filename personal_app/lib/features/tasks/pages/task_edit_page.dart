import 'package:flutter/material.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../providers/task_providers.dart';

class TaskEditPage extends ConsumerStatefulWidget {
  final String? taskId;
  const TaskEditPage({super.key, this.taskId});

  @override
  ConsumerState<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends ConsumerState<TaskEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _dueDate;
  bool _isRepeatable = false;
  RepeatType _repeatType = RepeatType.daily;
  int _repeatInterval = 1;
  DateTime? _repeatEndDate;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.taskId != null) {
      _isEditing = true;
      _loadTask();
    }
  }

  Future<void> _loadTask() async {
    final service = ref.read(taskServiceProvider);
    final task = await service.getTask(widget.taskId!);
    if (task != null && mounted) {
      setState(() {
        _titleController.text = task.title;
        _descriptionController.text = task.description ?? '';
        _categoryController.text = task.category ?? '';
        _priority = task.priority;
        _dueDate = task.dueDate;
        _isRepeatable = task.isRepeatable;
        _repeatType = task.repeatType ?? RepeatType.daily;
        _repeatInterval = task.repeatInterval;
        _repeatEndDate = task.repeatEndDate;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime?> onPicked,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null) onPicked(date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final category = _categoryController.text.trim();
    final description = _descriptionController.text.trim();

    if (_isEditing) {
      final service = ref.read(taskServiceProvider);
      final existing = await service.getTask(widget.taskId!);
      if (existing != null) {
        final updated = existing.copyWith(
          title: _titleController.text.trim(),
          description: description.isEmpty ? null : description,
          clearDescription: description.isEmpty,
          priority: _priority,
          dueDate: _dueDate,
          clearDueDate: _dueDate == null,
          category: category.isEmpty ? null : category,
          clearCategory: category.isEmpty,
          isRepeatable: _isRepeatable,
          repeatType: _isRepeatable ? _repeatType : null,
          clearRepeatType: !_isRepeatable,
          repeatInterval: _isRepeatable ? _repeatInterval : 1,
          repeatEndDate: _isRepeatable ? _repeatEndDate : null,
          clearRepeatEndDate: !_isRepeatable,
        );
        await ref.read(taskListProvider.notifier).updateTask(updated);
      }
    } else {
      final task = Task(
        title: _titleController.text.trim(),
        description: description.isEmpty ? null : description,
        priority: _priority,
        dueDate: _dueDate,
        category: category.isEmpty ? null : category,
        isRepeatable: _isRepeatable,
        repeatType: _isRepeatable ? _repeatType : null,
        repeatInterval: _isRepeatable ? _repeatInterval : 1,
        repeatEndDate: _isRepeatable ? _repeatEndDate : null,
      );
      await ref.read(taskListProvider.notifier).addTask(task);
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(taskCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: QuickActionsTitle(
          child: Text(_isEditing ? 'Edit Task' : 'New Task'),
        ),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Priority
            Text('Priority', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<TaskPriority>(
              segments: const [
                ButtonSegment(value: TaskPriority.low, label: Text('Low')),
                ButtonSegment(
                  value: TaskPriority.medium,
                  label: Text('Medium'),
                ),
                ButtonSegment(value: TaskPriority.high, label: Text('High')),
              ],
              selected: {_priority},
              onSelectionChanged: (s) => setState(() => _priority = s.first),
            ),
            const SizedBox(height: 16),

            // Due date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(
                _dueDate != null
                    ? DateFormat.yMMMd().format(_dueDate!)
                    : 'No due date',
              ),
              trailing: _dueDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _dueDate = null),
                    )
                  : null,
              onTap: () => _pickDate(
                current: _dueDate,
                onPicked: (d) => setState(() => _dueDate = d),
              ),
            ),
            const SizedBox(height: 8),

            // Category
            Autocomplete<String>(
              optionsBuilder: (value) {
                if (value.text.isEmpty) return categories;
                return categories.where(
                  (c) => c.toLowerCase().contains(value.text.toLowerCase()),
                );
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                if (controller.text.isEmpty &&
                    _categoryController.text.isNotEmpty) {
                  controller.text = _categoryController.text;
                }
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  onChanged: (v) => _categoryController.text = v,
                );
              },
              onSelected: (value) => _categoryController.text = value,
            ),
            const SizedBox(height: 16),

            // Repeatable
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Repeatable'),
              subtitle: const Text('Task repeats on a schedule'),
              value: _isRepeatable,
              onChanged: (v) => setState(() => _isRepeatable = v),
            ),
            if (_isRepeatable) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Every '),
                  SizedBox(
                    width: 60,
                    child: TextFormField(
                      initialValue: _repeatInterval.toString(),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (v) => _repeatInterval = int.tryParse(v) ?? 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<RepeatType>(
                      initialValue: _repeatType,
                      items: RepeatType.values
                          .map(
                            (t) =>
                                DropdownMenuItem(value: t, child: Text(t.name)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _repeatType = v ?? RepeatType.daily),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_repeat),
                title: Text(
                  _repeatEndDate != null
                      ? 'Ends ${DateFormat.yMMMd().format(_repeatEndDate!)}'
                      : 'No end date',
                ),
                trailing: _repeatEndDate != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _repeatEndDate = null),
                      )
                    : null,
                onTap: () => _pickDate(
                  current: _repeatEndDate,
                  onPicked: (d) => setState(() => _repeatEndDate = d),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
