import 'package:flutter/material.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/knowledge_page.dart';
import '../providers/knowledge_providers.dart';

class KnowledgeEditPage extends ConsumerStatefulWidget {
  final String? pageId;
  const KnowledgeEditPage({super.key, this.pageId});

  @override
  ConsumerState<KnowledgeEditPage> createState() => _KnowledgeEditPageState();
}

class _KnowledgeEditPageState extends ConsumerState<KnowledgeEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();

  List<String> _tags = [];
  String? _parentId;
  bool _isLoading = true;
  KnowledgePage? _existing;

  @override
  void initState() {
    super.initState();
    if (widget.pageId != null) {
      _loadPage();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadPage() async {
    final page = await ref
        .read(knowledgeServiceProvider)
        .getPage(widget.pageId!);
    if (page != null && mounted) {
      setState(() {
        _existing = page;
        _titleController.text = page.title;
        _contentController.text = page.content;
        _tags = List.from(page.tags);
        _parentId = page.parentId;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(knowledgeListProvider.notifier);
    if (_existing != null) {
      await notifier.updatePage(
        _existing!.copyWith(
          title: _titleController.text.trim(),
          content: _contentController.text,
          tags: _tags,
          parentId: () => _parentId,
        ),
      );
    } else {
      await notifier.addPage(
        KnowledgePage(
          title: _titleController.text.trim(),
          content: _contentController.text,
          tags: _tags,
          parentId: _parentId,
        ),
      );
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.pageId != null;
    final allPages = ref.watch(knowledgeListProvider);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: QuickActionsTitle(
            child: Text(isEditing ? 'Edit Page' : 'New Page'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Available parent pages (exclude self and descendants)
    final parentOptions =
        allPages.valueOrNull?.where((p) => p.id != widget.pageId).toList() ??
        [];

    return Scaffold(
      appBar: AppBar(
        title: QuickActionsTitle(
          child: Text(isEditing ? 'Edit Page' : 'New Page'),
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

            // Parent page selector
            DropdownButtonFormField<String?>(
              initialValue: _parentId,
              decoration: const InputDecoration(
                labelText: 'Parent Page',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('None (root level)'),
                ),
                for (final p in parentOptions)
                  DropdownMenuItem(value: p.id, child: Text(p.title)),
              ],
              onChanged: (v) => setState(() => _parentId = v),
            ),
            const SizedBox(height: 16),

            // Tags
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      labelText: 'Add tag',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: _tags
                    .map(
                      (tag) => Chip(
                        label: Text(tag),
                        onDeleted: () {
                          setState(() => _tags.remove(tag));
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),

            // Content
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Content (Markdown)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                hintText: '# Heading\n\nWrite your content in Markdown...',
              ),
              maxLines: 20,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
          ],
        ),
      ),
    );
  }
}
