import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';

import '../../../presentation/widgets/image_upload_preview_dialog.dart';
import '../../../services/image_upload_service.dart';
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
  TimeOfDay? _dueTime;
  bool _hasDueTime = false;
  List<String> _savedImageUrls = [];
  List<({Uint8List bytes, String fileName})> _pendingImages = [];
  final List<String> _removedImageUrls = [];
  bool _isUploading = false;
  bool _isRepeatable = false;
  RepeatType _repeatType = RepeatType.daily;
  int _repeatInterval = 1;
  DateTime? _repeatEndDate;
  String? _parentTaskId;
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
        _hasDueTime = task.hasDueTime;
        if (task.hasDueTime && task.dueDate != null) {
          _dueTime = TimeOfDay(
            hour: task.dueDate!.hour,
            minute: task.dueDate!.minute,
          );
        }
        _savedImageUrls = List.of(task.attachments);
        _isRepeatable = task.isRepeatable;
        _repeatType = task.repeatType ?? RepeatType.daily;
        _repeatInterval = task.repeatInterval;
        _repeatEndDate = task.repeatEndDate;
        _parentTaskId = task.parentTaskId;
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

    setState(() => _isUploading = true);
    try {
      // Upload pending images
      final uploader = ref.read(imageUploadServiceProvider);
      for (final pending in _pendingImages) {
        final url = await uploader.uploadImageBytes(
          pending.bytes,
          fileName: pending.fileName,
          folder: 'tasks',
        );
        _savedImageUrls.add(url);
      }

      final category = _categoryController.text.trim();
      final description = _descriptionController.text.trim();

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
            attachments: _savedImageUrls,
            isRepeatable: _isRepeatable,
            repeatType: _isRepeatable ? _repeatType : null,
            clearRepeatType: !_isRepeatable,
            repeatInterval: _isRepeatable ? _repeatInterval : 1,
            repeatEndDate: _isRepeatable ? _repeatEndDate : null,
            clearRepeatEndDate: !_isRepeatable,
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
          attachments: _savedImageUrls,
          isRepeatable: _isRepeatable,
          repeatType: _isRepeatable ? _repeatType : null,
          repeatInterval: _isRepeatable ? _repeatInterval : 1,
          repeatEndDate: _isRepeatable ? _repeatEndDate : null,
          parentTaskId: _parentTaskId,
        );
        await ref.read(taskListProvider.notifier).addTask(task);
      }

      // Delete removed images from Storage
      for (final url in _removedImageUrls) {
        await uploader.deleteImage(url);
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(taskCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: QuickActionsTitle(
          child: Text(_isEditing ? 'Edit Task' : 'New Task'),
        ),
        actions: [
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
              // root tasks (no parent) are eligible parents, and a task
              // cannot be its own parent).
              Consumer(
                builder: (context, ref, _) {
                  final all =
                      ref.watch(taskListProvider).valueOrNull ?? const [];
                  final candidates =
                      all
                          .where(
                            (t) =>
                                t.id != widget.taskId && t.parentTaskId == null,
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
              if (_savedImageUrls.isNotEmpty || _pendingImages.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _savedImageUrls.length + _pendingImages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final isExisting = index < _savedImageUrls.length;
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: isExisting
                                ? CachedNetworkImage(
                                    imageUrl: _savedImageUrls[index],
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  )
                                : Image.memory(
                                    _pendingImages[index -
                                            _savedImageUrls.length]
                                        .bytes,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => _removeAttachment(index),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addAttachment,
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
    );
  }

  Future<void> _addAttachment() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final uploader = ref.read(imageUploadServiceProvider);
    final file = source == 'gallery'
        ? await uploader.pickImage()
        : await uploader.captureImage();
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;

    final result = await showImageUploadPreviewDialog(
      context: context,
      originalBytes: bytes,
      fileName: file.name,
      sourcePath: file.path,
    );
    if (result == null || !mounted) return;
    await result.maybeRemoveSourceFromDevice();

    setState(() {
      _pendingImages = [
        ..._pendingImages,
        (bytes: result.bytes, fileName: result.fileName),
      ];
    });
  }

  void _removeAttachment(int index) {
    setState(() {
      if (index < _savedImageUrls.length) {
        _removedImageUrls.add(_savedImageUrls[index]);
        _savedImageUrls = List.of(_savedImageUrls)..removeAt(index);
      } else {
        final pendingIndex = index - _savedImageUrls.length;
        _pendingImages = List.of(_pendingImages)..removeAt(pendingIndex);
      }
    });
  }
}
