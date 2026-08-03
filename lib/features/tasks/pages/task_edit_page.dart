import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:personal_app/presentation/widgets/app_snackbar.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';

import '../../../presentation/widgets/image_attachment_picker.dart';
import '../../../presentation/widgets/image_attachment_strip.dart';
import '../../../presentation/widgets/unsaved_changes_guard.dart';
import '../../../services/image_attachment_controller.dart';
import '../../../services/image_upload_service.dart';
import '../models/task.dart';
import '../providers/task_providers.dart';

class TaskEditPage extends ConsumerStatefulWidget {
  final String? taskId;

  /// When the page opens for a new task, pre-select this task as the
  /// parent. Used by the "Create subtask" button on an existing task
  /// so the user doesn't have to hunt for the parent in the dropdown
  /// (WISH-0081).
  final String? initialParentTaskId;

  const TaskEditPage({super.key, this.taskId, this.initialParentTaskId});

  @override
  ConsumerState<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends ConsumerState<TaskEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _estimateHoursController = TextEditingController();
  final _estimateMinutesController = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  bool _hasDueTime = false;
  final _images = ImageAttachmentController(folder: 'tasks');
  bool _isUploading = false;
  bool _isRepeatable = false;
  RepeatType _repeatType = RepeatType.daily;
  int _repeatInterval = 1;
  DateTime? _repeatEndDate;
  String? _parentTaskId;
  bool _isEditing = false;
  // Captured after load (or on initState for new tasks) so we can
  // compare against the current form state and prompt the user before
  // a back-nav discards unsaved edits (WISH-0079).
  String _initialSnapshot = '';

  @override
  void initState() {
    super.initState();
    _images.addListener(_onImagesChanged);
    if (widget.taskId != null) {
      _isEditing = true;
      _loadTask();
    } else {
      // Pre-select the parent when arriving via the "Create subtask"
      // shortcut on an existing task (WISH-0081).
      _parentTaskId = widget.initialParentTaskId;
      _initialSnapshot = _snapshot();
    }
  }

  /// Rebuild when images change so the strip and the unsaved-changes
  /// guard pick up the new image state.
  void _onImagesChanged() {
    if (mounted) setState(() {});
  }

  /// Stable concatenation of the form fields used as a dirty-check
  /// baseline. Pure function of current state (WISH-0079).
  String _snapshot() => [
    _titleController.text,
    _descriptionController.text,
    _categoryController.text,
    _estimateHoursController.text,
    _estimateMinutesController.text,
    _priority.name,
    _dueDate?.toIso8601String() ?? '',
    _hasDueTime,
    _dueTime?.hour,
    _dueTime?.minute,
    _images.dirtySignature,
    _isRepeatable,
    _repeatType.name,
    _repeatInterval,
    _repeatEndDate?.toIso8601String() ?? '',
    _parentTaskId ?? '',
  ].join('|');

  bool get _isDirty => _initialSnapshot != _snapshot();

  Future<void> _loadTask() async {
    final service = ref.read(taskServiceProvider);
    final task = await service.getTask(widget.taskId!);
    if (task != null && mounted) {
      setState(() {
        _titleController.text = task.title;
        _descriptionController.text = task.description ?? '';
        _categoryController.text = task.category ?? '';
        if (task.estimatedMinutes != null) {
          _estimateHoursController.text = (task.estimatedMinutes! ~/ 60)
              .toString();
          _estimateMinutesController.text = (task.estimatedMinutes! % 60)
              .toString();
        }
        _priority = task.priority;
        _dueDate = task.dueDate;
        _hasDueTime = task.hasDueTime;
        if (task.hasDueTime && task.dueDate != null) {
          _dueTime = TimeOfDay(
            hour: task.dueDate!.hour,
            minute: task.dueDate!.minute,
          );
        }
        _images.seed(task.attachments);
        _isRepeatable = task.isRepeatable;
        _repeatType = task.repeatType ?? RepeatType.daily;
        _repeatInterval = task.repeatInterval;
        _repeatEndDate = task.repeatEndDate;
        _parentTaskId = task.parentTaskId;
      });
      _initialSnapshot = _snapshot();
    }
  }

  @override
  void dispose() {
    _images.removeListener(_onImagesChanged);
    _images.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _estimateHoursController.dispose();
    _estimateMinutesController.dispose();
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

    setState(() => _isUploading = true);
    try {
      final uploader = ref.read(imageUploadServiceProvider);
      await _images.uploadPending(uploader);

      final category = _categoryController.text.trim();
      final description = _descriptionController.text.trim();

      final estimateHours =
          int.tryParse(_estimateHoursController.text.trim()) ?? 0;
      final estimateMinutesPart =
          int.tryParse(_estimateMinutesController.text.trim()) ?? 0;
      final totalEstimateMinutes = estimateHours * 60 + estimateMinutesPart;
      final estimatedMinutes = totalEstimateMinutes > 0
          ? totalEstimateMinutes
          : null;

      // Build due date with optional time
      DateTime? dueDate = _dueDate;
      if (dueDate != null && _hasDueTime && _dueTime != null) {
        dueDate = DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day,
          _dueTime!.hour,
          _dueTime!.minute,
        );
      }

      if (_isEditing) {
        final service = ref.read(taskServiceProvider);
        final existing = await service.getTask(widget.taskId!);
        if (existing != null) {
          final updated = existing.copyWith(
            title: _titleController.text.trim(),
            description: description.isEmpty ? null : description,
            clearDescription: description.isEmpty,
            priority: _priority,
            dueDate: dueDate,
            hasDueTime: _hasDueTime,
            clearDueDate: _dueDate == null,
            category: category.isEmpty ? null : category,
            clearCategory: category.isEmpty,
            attachments: _images.savedUrls,
            isRepeatable: _isRepeatable,
            repeatType: _isRepeatable ? _repeatType : null,
            clearRepeatType: !_isRepeatable,
            repeatInterval: _isRepeatable ? _repeatInterval : 1,
            repeatEndDate: _isRepeatable ? _repeatEndDate : null,
            clearRepeatEndDate: !_isRepeatable,
            estimatedMinutes: estimatedMinutes,
            clearEstimatedMinutes: estimatedMinutes == null,
            parentTaskId: _parentTaskId,
            clearParentTaskId: _parentTaskId == null,
          );
          await ref.read(taskListProvider.notifier).updateTask(updated);
        }
      } else {
        final task = Task(
          title: _titleController.text.trim(),
          description: description.isEmpty ? null : description,
          priority: _priority,
          dueDate: dueDate,
          hasDueTime: _hasDueTime,
          category: category.isEmpty ? null : category,
          attachments: _images.savedUrls,
          isRepeatable: _isRepeatable,
          repeatType: _isRepeatable ? _repeatType : null,
          repeatInterval: _isRepeatable ? _repeatInterval : 1,
          repeatEndDate: _isRepeatable ? _repeatEndDate : null,
          estimatedMinutes: estimatedMinutes,
          parentTaskId: _parentTaskId,
        );
        await ref.read(taskListProvider.notifier).addTask(task);
      }

      await _images.deleteRemoved(uploader);

      // Mark form clean so the unsaved-changes guard lets the post-
      // save pop through unprompted (WISH-0079).
      _initialSnapshot = _snapshot();
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Save failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(taskCategoriesProvider);

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      child: Scaffold(
        appBar: AppBar(
          title: QuickActionsTitle(
            child: Text(_isEditing ? 'Edit Task' : 'New Task'),
          ),
          actions: [
            // Only root tasks can be parents (one nesting level), so
            // the shortcut is hidden on subtasks (WISH-0081).
            if (_isEditing && _parentTaskId == null)
              IconButton(
                icon: const Icon(Icons.subdirectory_arrow_right_rounded),
                tooltip: 'Create subtask',
                onPressed: _isUploading
                    ? null
                    : () => context.push('/tasks/new?parent=${widget.taskId!}'),
              ),
            TextButton(
              onPressed: _isUploading ? null : _save,
              child: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
        body: ResponsiveCenter(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Title is required'
                      : null,
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
                    ButtonSegment(
                      value: TaskPriority.high,
                      label: Text('High'),
                    ),
                  ],
                  selected: {_priority},
                  onSelectionChanged: (s) =>
                      setState(() => _priority = s.first),
                ),
                const SizedBox(height: 16),

                // Estimated duration — a rough time guess so tasks can be
                // compared and quick wins spotted at a glance (WISH-0094).
                Text(
                  'Estimated duration',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _estimateHoursController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Hours'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _estimateMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Minutes'),
                      ),
                    ),
                  ],
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
                          onPressed: () => setState(() {
                            _dueDate = null;
                            _hasDueTime = false;
                            _dueTime = null;
                          }),
                        )
                      : null,
                  onTap: () => _pickDate(
                    current: _dueDate,
                    onPicked: (d) => setState(() => _dueDate = d),
                  ),
                ),

                // Due time (only when due date is set)
                if (_dueDate != null) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Set time'),
                    value: _hasDueTime,
                    onChanged: (v) => setState(() {
                      _hasDueTime = v;
                      if (v && _dueTime == null) {
                        _dueTime = TimeOfDay(
                          hour: DateTime.now().hour,
                          minute: 0,
                        );
                      }
                    }),
                  ),
                  if (_hasDueTime)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time),
                      title: Text(
                        _dueTime != null
                            ? _dueTime!.format(context)
                            : 'No time set',
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _dueTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() => _dueTime = picked);
                        }
                      },
                    ),
                ],
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

                // Parent task (subtasks limited to one nesting level — only
                // root tasks (no parent) are eligible parents, a task cannot
                // be its own parent, and completed tasks are filtered out
                // so the list stays focused on actionable parents
                // (BUG-0044).
                Consumer(
                  builder: (context, ref, _) {
                    final all =
                        ref.watch(taskListProvider).valueOrNull ?? const [];
                    final candidates =
                        all
                            .where(
                              (t) =>
                                  t.id != widget.taskId &&
                                  t.parentTaskId == null &&
                                  !t.isCompleted,
                            )
                            .toList()
                          ..sort(
                            (a, b) => a.title.toLowerCase().compareTo(
                              b.title.toLowerCase(),
                            ),
                          );
                    // If the current parent isn't in the candidates (e.g. it
                    // was deleted), null it out to avoid a dropdown error.
                    final parentValue =
                        candidates.any((t) => t.id == _parentTaskId)
                        ? _parentTaskId
                        : null;
                    return DropdownButtonFormField<String?>(
                      initialValue: parentValue,
                      decoration: const InputDecoration(
                        labelText: 'Parent task',
                        prefixIcon: Icon(Icons.account_tree_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('None (root task)'),
                        ),
                        for (final t in candidates)
                          DropdownMenuItem(value: t.id, child: Text(t.title)),
                      ],
                      onChanged: (v) => setState(() => _parentTaskId = v),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Attachments
                Text(
                  'Attachments',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                ImageAttachmentStrip(controller: _images),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => pickImageInto(
                    context,
                    ref.read(imageUploadServiceProvider),
                    _images,
                  ),
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add image'),
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
                          onChanged: (v) =>
                              _repeatInterval = int.tryParse(v) ?? 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<RepeatType>(
                          initialValue: _repeatType,
                          items: RepeatType.values
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(
                            () => _repeatType = v ?? RepeatType.daily,
                          ),
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
                            onPressed: () =>
                                setState(() => _repeatEndDate = null),
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
        ),
      ),
    );
  }
}
