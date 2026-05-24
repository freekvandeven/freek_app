import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../presentation/widgets/image_upload_preview_dialog.dart';
import '../../../services/image_upload_service.dart';
import '../models/calendar_event.dart';
import '../providers/calendar_providers.dart';

class CalendarEventEditPage extends ConsumerStatefulWidget {
  final String? eventId;
  final DateTime? initialDate;

  const CalendarEventEditPage({super.key, this.eventId, this.initialDate});

  @override
  ConsumerState<CalendarEventEditPage> createState() =>
      _CalendarEventEditPageState();
}

class _CalendarEventEditPageState extends ConsumerState<CalendarEventEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  late DateTime _startDate;
  late TimeOfDay _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _isAllDay = true;
  bool _hasEndDate = false;

  List<String> _savedImageUrls = [];
  List<({Uint8List bytes, String fileName})> _pendingImages = [];
  final List<String> _removedImageUrls = [];
  bool _isUploading = false;

  bool get _isEditing => widget.eventId != null;
  CalendarEvent? _existingEvent;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();

    final now = DateTime.now();
    _startDate = widget.initialDate ?? DateTime(now.year, now.month, now.day);
    _startTime = TimeOfDay(hour: now.hour, minute: 0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _loadEvent(CalendarEvent event) {
    if (_existingEvent != null) return; // already loaded
    _existingEvent = event;
    _titleController.text = event.title;
    _descriptionController.text = event.description ?? '';
    _startDate = DateTime(event.date.year, event.date.month, event.date.day);
    _startTime = TimeOfDay(hour: event.date.hour, minute: event.date.minute);
    _isAllDay = event.isAllDay;
    _savedImageUrls = List.of(event.imageUrls);
    if (event.endDate != null) {
      _hasEndDate = true;
      _endDate = DateTime(
        event.endDate!.year,
        event.endDate!.month,
        event.endDate!.day,
      );
      _endTime = TimeOfDay(
        hour: event.endDate!.hour,
        minute: event.endDate!.minute,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      final events = ref.watch(calendarEventsProvider);
      final event = events.valueOrNull
          ?.where((e) => e.id == widget.eventId)
          .firstOrNull;
      if (event != null && event.type == EventType.custom) {
        _loadEvent(event);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Event' : 'New Event'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              autofocus: !_isEditing,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // All-day toggle
            SwitchListTile(
              title: const Text('All-day event'),
              value: _isAllDay,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _isAllDay = v),
            ),
            const Divider(),

            // Start date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Start date'),
              subtitle: Text(DateFormat.yMMMEd().format(_startDate)),
              onTap: () => _pickDate(isStart: true),
            ),

            // Start time (only when not all-day)
            if (!_isAllDay)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: const Text('Start time'),
                subtitle: Text(_startTime.format(context)),
                onTap: () => _pickTime(isStart: true),
              ),

            const Divider(),

            // End date toggle
            SwitchListTile(
              title: const Text('End date'),
              value: _hasEndDate,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) {
                setState(() {
                  _hasEndDate = v;
                  if (v && _endDate == null) {
                    _endDate = _startDate;
                    _endTime = TimeOfDay(
                      hour: _startTime.hour + 1,
                      minute: _startTime.minute,
                    );
                  }
                });
              },
            ),

            if (_hasEndDate) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('End date'),
                subtitle: Text(
                  _endDate != null
                      ? DateFormat.yMMMEd().format(_endDate!)
                      : 'Not set',
                ),
                onTap: () => _pickDate(isStart: false),
              ),
              if (!_isAllDay)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: const Text('End time'),
                  subtitle: Text(
                    _endTime != null ? _endTime!.format(context) : 'Not set',
                  ),
                  onTap: () => _pickTime(isStart: false),
                ),
            ],

            const SizedBox(height: 24),

            // Images
            Text('Images', style: Theme.of(context).textTheme.labelLarge),
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
                                  _pendingImages[index - _savedImageUrls.length]
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
                            onTap: () {
                              setState(() {
                                if (index < _savedImageUrls.length) {
                                  _removedImageUrls.add(_savedImageUrls[index]);
                                  _savedImageUrls = List.of(_savedImageUrls)
                                    ..removeAt(index);
                                } else {
                                  final pendingIndex =
                                      index - _savedImageUrls.length;
                                  _pendingImages = List.of(_pendingImages)
                                    ..removeAt(pendingIndex);
                                }
                              });
                            },
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
              onPressed: _addImage,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add image'),
            ),

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isUploading ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_isEditing ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : (_endDate ?? _startDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : (_endTime ?? _startTime);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
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
          folder: 'calendar',
        );
        _savedImageUrls.add(url);
      }

      final startDateTime = _isAllDay
          ? DateTime(_startDate.year, _startDate.month, _startDate.day)
          : DateTime(
              _startDate.year,
              _startDate.month,
              _startDate.day,
              _startTime.hour,
              _startTime.minute,
            );

      DateTime? endDateTime;
      if (_hasEndDate && _endDate != null) {
        endDateTime = _isAllDay
            ? DateTime(_endDate!.year, _endDate!.month, _endDate!.day)
            : DateTime(
                _endDate!.year,
                _endDate!.month,
                _endDate!.day,
                _endTime?.hour ?? _startTime.hour,
                _endTime?.minute ?? _startTime.minute,
              );
      }

      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();

      if (_isEditing && _existingEvent != null) {
        final updated = _existingEvent!.copyWith(
          title: _titleController.text.trim(),
          description: description,
          date: startDateTime,
          endDate: endDateTime,
          isAllDay: _isAllDay,
          imageUrls: _savedImageUrls,
          clearDescription: description == null,
          clearEndDate: !_hasEndDate,
        );
        await ref.read(calendarEventsProvider.notifier).updateEvent(updated);
      } else {
        await ref
            .read(calendarEventsProvider.notifier)
            .addEvent(
              CalendarEvent(
                title: _titleController.text.trim(),
                description: description,
                date: startDateTime,
                endDate: endDateTime,
                isAllDay: _isAllDay,
                imageUrls: _savedImageUrls,
              ),
            );
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

  Future<void> _addImage() async {
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
            const PasteFromClipboardTile(),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final uploader = ref.read(imageUploadServiceProvider);
    final picked = await resolveImageSource(context, source, uploader);
    if (picked == null || !mounted) return;

    final result = await showImageUploadPreviewDialog(
      context: context,
      originalBytes: picked.bytes,
      fileName: picked.fileName,
      sourcePath: picked.sourcePath,
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

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Delete "${_titleController.text}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(calendarEventsProvider.notifier)
                  .deleteEvent(widget.eventId!);
              context.pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
