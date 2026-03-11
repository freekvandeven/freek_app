import 'package:flutter/material.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_providers.dart';
import '../models/feedback_entry.dart';
import '../providers/feedback_providers.dart';

class FeedbackEditPage extends ConsumerStatefulWidget {
  final String? entryId;
  final FeedbackType? initialType;
  const FeedbackEditPage({super.key, this.entryId, this.initialType});

  @override
  ConsumerState<FeedbackEditPage> createState() => _FeedbackEditPageState();
}

class _FeedbackEditPageState extends ConsumerState<FeedbackEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  FeedbackType _type = FeedbackType.wish;
  FeedbackStatus _status = FeedbackStatus.open;
  bool _isPrivate = false;
  bool _isLoading = true;
  FeedbackEntry? _existing;

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _type = widget.initialType!;
    }
    if (widget.entryId != null) {
      _loadEntry();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadEntry() async {
    final entry = await ref
        .read(feedbackServiceProvider)
        .getEntry(widget.entryId!);
    if (entry != null && mounted) {
      setState(() {
        _existing = entry;
        _titleController.text = entry.title;
        _descriptionController.text = entry.description;
        _type = entry.type;
        _status = entry.status;
        _isPrivate = entry.isPrivate;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(feedbackListProvider.notifier);
    final userId = ref.read(currentUserProvider)?.id;
    if (_existing != null) {
      await notifier.updateEntry(
        _existing!.copyWith(
          type: _type,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          status: _status,
          isPrivate: _isPrivate,
        ),
      );
    } else {
      await notifier.addEntry(
        FeedbackEntry(
          type: _type,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          isPrivate: _isPrivate,
          userId: userId,
        ),
      );
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entryId != null;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: QuickActionsTitle(child: Text(isEditing ? 'Edit Feedback' : 'New Feedback')),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: QuickActionsTitle(child: Text(isEditing ? 'Edit Feedback' : 'New Feedback')),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<FeedbackType>(
              segments: const [
                ButtonSegment(
                  value: FeedbackType.wish,
                  label: Text('Wish'),
                  icon: Icon(Icons.lightbulb),
                ),
                ButtonSegment(
                  value: FeedbackType.bug,
                  label: Text('Bug'),
                  icon: Icon(Icons.bug_report),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selected) {
                setState(() => _type = selected.first);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 8,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Private'),
              subtitle: const Text('Only visible to you'),
              value: _isPrivate,
              onChanged: (v) => setState(() => _isPrivate = v),
            ),
            if (isEditing) ...[
              const SizedBox(height: 24),
              const Text(
                'Status',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<FeedbackStatus>(
                segments: FeedbackStatus.values
                    .map(
                      (s) => ButtonSegment(
                        value: s,
                        label: Text(
                          s.name[0].toUpperCase() + s.name.substring(1),
                        ),
                      ),
                    )
                    .toList(),
                selected: {_status},
                onSelectionChanged: (selected) {
                  setState(() => _status = selected.first);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
