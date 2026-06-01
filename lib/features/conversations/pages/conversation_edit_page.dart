import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';

import '../../../presentation/widgets/fullscreen_image_viewer.dart';
import '../../../presentation/widgets/image_upload_preview_dialog.dart';
import '../../../services/image_upload_service.dart';
import '../../contacts/providers/contact_providers.dart';
import '../../contacts/widgets/contact_picker.dart';
import '../models/conversation_topic.dart';
import '../providers/conversation_providers.dart';

class ConversationEditPage extends ConsumerStatefulWidget {
  final String? topicId;
  const ConversationEditPage({super.key, this.topicId});

  @override
  ConsumerState<ConversationEditPage> createState() =>
      _ConversationEditPageState();
}

class _ConversationEditPageState extends ConsumerState<ConversationEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _personController = TextEditingController();
  String? _contactId;
  TopicPriority _priority = TopicPriority.medium;
  TopicStatus _status = TopicStatus.open;
  List<String> _imageUrls = [];
  bool _isLoading = true;
  bool _isUploading = false;
  ConversationTopic? _existing;

  @override
  void initState() {
    super.initState();
    if (widget.topicId != null) {
      _loadTopic();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadTopic() async {
    final topic = await ref
        .read(conversationServiceProvider)
        .getTopic(widget.topicId!);
    if (topic != null && mounted) {
      setState(() {
        _existing = topic;
        _titleController.text = topic.title;
        _descriptionController.text = topic.description;
        _personController.text = topic.personOrGroup;
        _contactId = topic.contactId;
        _priority = topic.priority;
        _status = topic.status;
        _imageUrls = List<String>.from(topic.imageUrls);
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
    _personController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(conversationListProvider.notifier);
    if (_existing != null) {
      final resolvedAt =
          _status == TopicStatus.resolved &&
              _existing!.status != TopicStatus.resolved
          ? DateTime.now()
          : _existing!.resolvedAt;
      await notifier.updateTopic(
        _existing!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          personOrGroup: _personController.text.trim(),
          contactId: () => _contactId,
          priority: _priority,
          status: _status,
          imageUrls: _imageUrls,
          resolvedAt: resolvedAt,
          clearResolvedAt: _status == TopicStatus.open,
        ),
      );
    } else {
      await notifier.addTopic(
        ConversationTopic(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          personOrGroup: _personController.text.trim(),
          contactId: _contactId,
          priority: _priority,
          imageUrls: _imageUrls,
        ),
      );
    }

    if (mounted) context.pop();
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
        folder: 'conversations',
      );
      if (mounted) {
        setState(() => _imageUrls = [..._imageUrls, url]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
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
    final isEditing = widget.topicId != null;
    final linkedContact = _contactId == null
        ? null
        : ref.watch(contactByIdProvider(_contactId!));

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: QuickActionsTitle(
            child: Text(isEditing ? 'Edit Topic' : 'New Topic'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: QuickActionsTitle(
          child: Text(isEditing ? 'Edit Topic' : 'New Topic'),
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
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            FormField<String>(
              initialValue: _personController.text,
              validator: (_) {
                if (_personController.text.trim().isEmpty &&
                    _contactId == null) {
                  return 'Required';
                }
                return null;
              },
              builder: (state) {
                final hasLink = linkedContact != null;
                final displayName = hasLink
                    ? linkedContact.name
                    : _personController.text;
                return InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Person / Group',
                    border: const OutlineInputBorder(),
                    errorText: state.errorText,
                    prefixIcon: Icon(
                      hasLink
                          ? (linkedContact.isGroup
                                ? Icons.groups_rounded
                                : Icons.person_rounded)
                          : Icons.person_outline,
                    ),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  child: InkWell(
                    onTap: () async {
                      final result = await showContactPicker(context);
                      if (result == null) return;
                      setState(() {
                        if (result.contact != null) {
                          _contactId = result.contact!.id;
                          _personController.text = result.contact!.name;
                        } else if (result.freeText != null) {
                          _contactId = null;
                          _personController.text = result.freeText!;
                        }
                      });
                      state.didChange(_personController.text);
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName.isEmpty
                                ? 'Tap to choose a contact'
                                : displayName,
                            style: displayName.isEmpty
                                ? TextStyle(color: Theme.of(context).hintColor)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 6,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            const Text(
              'Priority',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<TopicPriority>(
              segments: const [
                ButtonSegment(
                  value: TopicPriority.low,
                  label: Text('Low'),
                  icon: Icon(Icons.keyboard_double_arrow_down),
                ),
                ButtonSegment(
                  value: TopicPriority.medium,
                  label: Text('Medium'),
                  icon: Icon(Icons.remove),
                ),
                ButtonSegment(
                  value: TopicPriority.high,
                  label: Text('High'),
                  icon: Icon(Icons.keyboard_double_arrow_up),
                ),
              ],
              selected: {_priority},
              onSelectionChanged: (selected) {
                setState(() => _priority = selected.first);
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Images'),
              subtitle: Text(
                _imageUrls.isEmpty
                    ? 'None'
                    : '${_imageUrls.length} image${_imageUrls.length == 1 ? '' : 's'}',
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
              SegmentedButton<TopicStatus>(
                segments: const [
                  ButtonSegment(value: TopicStatus.open, label: Text('Open')),
                  ButtonSegment(
                    value: TopicStatus.resolved,
                    label: Text('Resolved'),
                  ),
                ],
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
