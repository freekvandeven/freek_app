import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_app/presentation/widgets/app_snackbar.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';

import '../../../presentation/widgets/file_drop_target.dart';
import '../../../presentation/widgets/fullscreen_image_viewer.dart';
import '../../../presentation/widgets/image_upload_preview_dialog.dart';
import '../../../services/image_upload_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/feedback_entry.dart';
import '../providers/feedback_providers.dart';
import 'log_selection_page.dart';

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
  bool _isManual = false;
  bool _isWip = false;
  bool _isLoading = true;
  String? _attachedLogs;
  List<String> _imageUrls = [];
  bool _isUploading = false;
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
        _isManual = entry.isManual;
        _isWip = entry.isWip;
        _attachedLogs = entry.attachedLogs;
        _imageUrls = List<String>.from(entry.imageUrls);
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
          isManual: _isManual,
          isWip: _isWip,
          attachedLogs: _attachedLogs,
          clearAttachedLogs: _attachedLogs == null,
          imageUrls: _imageUrls,
        ),
      );
    } else {
      await notifier.addEntry(
        FeedbackEntry(
          type: _type,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          isPrivate: _isPrivate,
          isManual: _isManual,
          isWip: _isWip,
          userId: userId,
          attachedLogs: _attachedLogs,
          imageUrls: _imageUrls,
        ),
      );
    }

    if (mounted) context.pop();
  }

  Future<void> _pickLogs() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const LogSelectionPage()),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _attachedLogs = result);
    }
  }

  void _showAttachedLogs() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Attached Logs'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              _attachedLogs ?? '',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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

    setState(() => _isUploading = true);
    try {
      final url = await uploader.uploadImageBytes(
        result.bytes,
        fileName: result.fileName,
        folder: 'feedback',
      );
      if (mounted) {
        setState(() => _imageUrls = [..._imageUrls, url]);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Image upload failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _removeImage(int index) async {
    final url = _imageUrls[index];
    setState(() => _imageUrls = List.from(_imageUrls)..removeAt(index));
    await ref.read(imageUploadServiceProvider).deleteImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entryId != null;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: QuickActionsTitle(
            child: Text(isEditing ? 'Edit Feedback' : 'New Feedback'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: QuickActionsTitle(
          child: Text(isEditing ? 'Edit Feedback' : 'New Feedback'),
        ),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: FileDropTarget(
        imagesOnly: true,
        onFiles: _onDroppedImages,
        child: Form(
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
                  ButtonSegment(
                    value: FeedbackType.improvement,
                    label: Text('Improvement'),
                    icon: Icon(Icons.tune),
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
                title: const Text('Work in Progress'),
                subtitle: const Text('Description not yet complete'),
                value: _isWip,
                onChanged: (v) => setState(() => _isWip = v),
              ),
              SwitchListTile(
                title: const Text('Private'),
                subtitle: const Text('Only visible to you'),
                value: _isPrivate,
                onChanged: (v) => setState(() => _isPrivate = v),
              ),
              SwitchListTile(
                title: const Text('Manual'),
                subtitle: const Text(
                  'Manually handled — excluded from AI export',
                ),
                value: _isManual,
                onChanged: (v) => setState(() => _isManual = v),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Attached Logs'),
                subtitle: Text(
                  _attachedLogs != null
                      ? '${_attachedLogs!.split('\n').length} lines attached'
                      : 'None',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_attachedLogs != null)
                      IconButton(
                        icon: const Icon(Icons.visibility),
                        tooltip: 'View logs',
                        onPressed: () => _showAttachedLogs(),
                      ),
                    if (_attachedLogs != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove logs',
                        onPressed: () => setState(() => _attachedLogs = null),
                      ),
                  ],
                ),
                onTap: () => _pickLogs(),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Images'),
                subtitle: Text(
                  _imageUrls.isEmpty
                      ? 'None'
                      : '${_imageUrls.length} image${_imageUrls.length == 1 ? '' : 's'} attached',
                ),
                trailing: _isUploading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.add_photo_alternate),
                        tooltip: 'Add image',
                        onPressed: _addImage,
                      ),
              ),
              if (_imageUrls.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _imageUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => Stack(
                      children: [
                        GestureDetector(
                          onTap: () => showFullscreenNetworkImage(
                            context,
                            _imageUrls[index],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: _imageUrls[index],
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 120,
                                height: 120,
                                color: Colors.grey[300],
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
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
                    ),
                  ),
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
              if (_existing?.referenceId != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Reference: ${_existing!.referenceId}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_existing?.aiSummary != null &&
                  _existing!.aiSummary!.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'AI Summary',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _existing!.aiSummary!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onDroppedImages(List<DroppedFile> files) async {
    final uploader = ref.read(imageUploadServiceProvider);
    for (final dropped in files) {
      if (!mounted) return;
      final result = await showImageUploadPreviewDialog(
        context: context,
        originalBytes: dropped.bytes,
        fileName: dropped.fileName,
      );
      if (result == null || !mounted) continue;
      setState(() => _isUploading = true);
      try {
        final url = await uploader.uploadImageBytes(
          result.bytes,
          fileName: result.fileName,
          folder: 'feedback',
        );
        if (mounted) setState(() => _imageUrls = [..._imageUrls, url]);
      } on StorageLimitExceededException catch (e) {
        if (mounted) {
          context.showErrorSnackbar(e.toString());
        }
        break;
      } catch (e) {
        if (mounted) {
          context.showErrorSnackbar('Upload failed: $e');
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }
}
