import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';

import '../../auth/providers/auth_providers.dart';
import '../../gemini/providers/gemini_providers.dart';
import '../models/knowledge_page.dart';
import '../providers/knowledge_providers.dart';

class KnowledgeEditPage extends ConsumerStatefulWidget {
  final String? pageId;
  final String? initialParentId;
  const KnowledgeEditPage({super.key, this.pageId, this.initialParentId});

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
  Timer? _autosaveTimer;

  @override
  void initState() {
    super.initState();
    if (widget.pageId != null) {
      _loadPage();
    } else {
      _parentId = widget.initialParentId;
      _isLoading = false;
      _setupAutosaveTimer();
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
    if (mounted) _setupAutosaveTimer();
  }

  void _setupAutosaveTimer() {
    _autosaveTimer?.cancel();
    final minutes =
        ref.read(currentUserProvider)?.settings.autosaveIntervalMinutes ?? 0;
    if (minutes > 0) {
      _autosaveTimer = Timer.periodic(
        Duration(minutes: minutes),
        (_) => _autosave(),
      );
    }
  }

  Future<void> _autosave() async {
    if (!mounted || !_formKey.currentState!.validate()) return;

    final notifier = ref.read(knowledgeListProvider.notifier);
    try {
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
        final page = KnowledgePage(
          title: _titleController.text.trim(),
          content: _contentController.text,
          tags: _tags,
          parentId: _parentId,
        );
        await notifier.addPage(page);
        if (mounted) setState(() => _existing = page);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto-saved'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      // Silently ignore autosave errors
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
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

  Future<void> _showAiAssist() async {
    final keyAvailable = await ref.read(geminiApiKeyAvailableProvider.future);
    if (!mounted) return;

    if (!keyAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Gemini API key configured. Add one in Settings.'),
        ),
      );
      return;
    }

    final promptController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI Assist'),
        content: TextField(
          controller: promptController,
          decoration: const InputDecoration(
            hintText: 'e.g. "Improve formatting", "Make it more concise"',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          maxLines: 3,
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final instruction = promptController.text.trim();
    if (instruction.isEmpty) return;

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('AI is working…'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final service = ref.read(geminiServiceProvider);
      if (!service.isConfigured) {
        final apiKey = await ref.read(geminiApiKeyServiceProvider).getApiKey();
        service.configure(apiKey);
      }
      final result = await service.editMarkdown(
        _contentController.text,
        instruction,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        setState(() => _contentController.text = result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('AI error: $e')));
      }
    }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: 'AI Assist',
            onPressed: _showAiAssist,
          ),
          TextButton(onPressed: _save, child: const Text('Save')),
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

            // Markdown toolbar
            _MarkdownToolbar(controller: _contentController),
            const SizedBox(height: 4),

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

class _MarkdownToolbar extends StatelessWidget {
  final TextEditingController controller;
  const _MarkdownToolbar({required this.controller});

  void _insertAtLineStart(String prefix) {
    final text = controller.text;
    final sel = controller.selection;
    final start = sel.isValid ? sel.start : text.length;
    // Find the beginning of the line
    final lineStart = text.lastIndexOf('\n', start - 1) + 1;
    final newText =
        text.substring(0, lineStart) + prefix + text.substring(lineStart);
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: start + prefix.length),
    );
  }

  void _wrapSelection(String before, String after, String placeholder) {
    final text = controller.text;
    final sel = controller.selection;
    if (!sel.isValid) {
      final insertion = before + placeholder + after;
      controller.value = TextEditingValue(
        text: text + insertion,
        selection: TextSelection(
          baseOffset: text.length + before.length,
          extentOffset: text.length + before.length + placeholder.length,
        ),
      );
      return;
    }
    final selected = text.substring(sel.start, sel.end);
    final inner = selected.isEmpty ? placeholder : selected;
    final replacement = before + inner + after;
    final newText =
        text.substring(0, sel.start) + replacement + text.substring(sel.end);
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection(
        baseOffset: sel.start + before.length,
        extentOffset: sel.start + before.length + inner.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            _ToolbarTextButton(
              label: 'H1',
              color: color,
              onTap: () => _insertAtLineStart('# '),
            ),
            _ToolbarTextButton(
              label: 'H2',
              color: color,
              onTap: () => _insertAtLineStart('## '),
            ),
            _ToolbarTextButton(
              label: 'H3',
              color: color,
              onTap: () => _insertAtLineStart('### '),
            ),
            _divider(),
            _ToolbarIconButton(
              icon: Icons.format_bold,
              color: color,
              tooltip: 'Bold',
              onTap: () => _wrapSelection('**', '**', 'bold text'),
            ),
            _ToolbarIconButton(
              icon: Icons.format_italic,
              color: color,
              tooltip: 'Italic',
              onTap: () => _wrapSelection('*', '*', 'italic text'),
            ),
            _ToolbarIconButton(
              icon: Icons.code,
              color: color,
              tooltip: 'Inline code',
              onTap: () => _wrapSelection('`', '`', 'code'),
            ),
            _divider(),
            _ToolbarIconButton(
              icon: Icons.format_list_bulleted,
              color: color,
              tooltip: 'Bullet list',
              onTap: () => _insertAtLineStart('- '),
            ),
            _ToolbarIconButton(
              icon: Icons.format_list_numbered,
              color: color,
              tooltip: 'Numbered list',
              onTap: () => _insertAtLineStart('1. '),
            ),
            _ToolbarIconButton(
              icon: Icons.format_quote,
              color: color,
              tooltip: 'Blockquote',
              onTap: () => _insertAtLineStart('> '),
            ),
            _divider(),
            _ToolbarIconButton(
              icon: Icons.link,
              color: color,
              tooltip: 'Link',
              onTap: () => _wrapSelection('[', '](url)', 'link text'),
            ),
            _ToolbarIconButton(
              icon: Icons.horizontal_rule,
              color: color,
              tooltip: 'Horizontal rule',
              onTap: () => _insertAtLineStart('---\n'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() =>
      const SizedBox(height: 24, child: VerticalDivider(width: 12));
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ToolbarIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18, color: color),
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}

class _ToolbarTextButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ToolbarTextButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
