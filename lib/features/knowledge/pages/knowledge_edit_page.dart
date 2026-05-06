import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';

import '../../auth/providers/auth_providers.dart';
import '../../gemini/providers/gemini_providers.dart';
import '../../settings/providers/settings_providers.dart';
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
  final _contentFocusNode = FocusNode();

  List<String> _tags = [];
  String? _parentId;
  bool _isWip = false;
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
        _isWip = page.isWip;
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
            isWip: _isWip,
          ),
        );
      } else {
        final page = KnowledgePage(
          title: _titleController.text.trim(),
          content: _contentController.text,
          tags: _tags,
          parentId: _parentId,
          isWip: _isWip,
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
    _contentFocusNode.dispose();
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
          isWip: _isWip,
        ),
      );
    } else {
      await notifier.addPage(
        KnowledgePage(
          title: _titleController.text.trim(),
          content: _contentController.text,
          tags: _tags,
          parentId: _parentId,
          isWip: _isWip,
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
      final model = ref.read(geminiModelProvider);
      if (!service.isConfigured) {
        final apiKey = await ref.read(geminiApiKeyServiceProvider).getApiKey();
        service.configure(apiKey, model: model);
      } else {
        service.setModel(model);
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

            SwitchListTile(
              title: const Text('Work in Progress'),
              subtitle: const Text('Mark this page as WIP'),
              value: _isWip,
              onChanged: (v) => setState(() => _isWip = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),

            // Markdown toolbar
            _MarkdownToolbar(
              controller: _contentController,
              focusNode: _contentFocusNode,
            ),
            const SizedBox(height: 4),

            // Content
            TextFormField(
              controller: _contentController,
              focusNode: _contentFocusNode,
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

class _MarkdownToolbar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  const _MarkdownToolbar({required this.controller, required this.focusNode});

  @override
  State<_MarkdownToolbar> createState() => _MarkdownToolbarState();
}

enum _MdFormat { h1, h2, h3, bold, italic, code, bullet, numbered, quote }

class _MarkdownToolbarState extends State<_MarkdownToolbar> {
  // Last known valid selection — updated while the field has focus.
  // Clicking a toolbar button blurs the field on web/desktop, making
  // controller.selection invalid, so we cache it here instead.
  TextSelection _lastSel = const TextSelection.collapsed(offset: 0);
  Set<_MdFormat> _active = const {};

  static final _numberedRe = RegExp(r'^\d+\.\s');
  static final _trailingHashesRe = RegExp(r'\s+#+\s*$');
  static final _leadingHeadingRe = RegExp(r'^#{1,6}\s+');

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final sel = widget.controller.selection;
    if (sel.isValid) _lastSel = sel;
    final next = _detectFormats();
    if (!setEquals(next, _active)) {
      setState(() => _active = next);
    }
  }

  Set<_MdFormat> _detectFormats() {
    final text = widget.controller.text;
    final sel = _lastSel;
    if (text.isEmpty) return const {};
    final start = sel.start.clamp(0, text.length);
    final lineStart = text.lastIndexOf('\n', start - 1) + 1;
    final lineEndIdx = text.indexOf('\n', start);
    final lineEnd = lineEndIdx == -1 ? text.length : lineEndIdx;
    final line = text.substring(lineStart, lineEnd);

    final out = <_MdFormat>{};

    // Line-prefix formats — single heading level wins (longest first)
    if (line.startsWith('### ')) {
      out.add(_MdFormat.h3);
    } else if (line.startsWith('## ')) {
      out.add(_MdFormat.h2);
    } else if (line.startsWith('# ')) {
      out.add(_MdFormat.h1);
    }
    if (line.startsWith('- ')) out.add(_MdFormat.bullet);
    if (_numberedRe.hasMatch(line)) out.add(_MdFormat.numbered);
    if (line.startsWith('> ')) out.add(_MdFormat.quote);

    // Wrap formats — only when the user has a non-empty selection
    if (!sel.isCollapsed) {
      bool wrapped(String marker) {
        final m = marker.length;
        if (sel.start < m || sel.end + m > text.length) {
          // Inner not possible
        } else if (text.substring(sel.start - m, sel.start) == marker &&
            text.substring(sel.end, sel.end + m) == marker) {
          return true;
        }
        // Whole-marker case: selection itself starts/ends with the marker
        if (sel.end - sel.start >= 2 * m) {
          final selText = text.substring(sel.start, sel.end);
          if (selText.startsWith(marker) && selText.endsWith(marker)) {
            return true;
          }
        }
        return false;
      }

      // Bold first; italic only if not bold (since `**` contains `*`)
      final bold = wrapped('**');
      if (bold) out.add(_MdFormat.bold);
      if (!bold && wrapped('*')) out.add(_MdFormat.italic);
      if (wrapped('`')) out.add(_MdFormat.code);
    }

    return out;
  }

  void _setText(String text, TextSelection selection) {
    widget.controller.value = TextEditingValue(
      text: text,
      selection: selection,
    );
    widget.focusNode.requestFocus();
  }

  void _insertAtLineStart(String prefix) {
    final text = widget.controller.text;
    final start = _lastSel.start.clamp(0, text.length);
    final lineStart = text.lastIndexOf('\n', start - 1) + 1;
    final newText =
        text.substring(0, lineStart) + prefix + text.substring(lineStart);
    _setText(newText, TextSelection.collapsed(offset: start + prefix.length));
  }

  void _wrapSelection(String before, String after) {
    final text = widget.controller.text;
    final sel = _lastSel;
    if (sel.isCollapsed) {
      final pos = sel.start.clamp(0, text.length);
      _setText(
        text.substring(0, pos) + before + after + text.substring(pos),
        TextSelection.collapsed(offset: pos + before.length),
      );
    } else {
      final selected = text.substring(sel.start, sel.end);
      final replacement = before + selected + after;
      _setText(
        text.substring(0, sel.start) + replacement + text.substring(sel.end),
        TextSelection.collapsed(offset: sel.start + replacement.length),
      );
    }
  }

  void _toggleHeading(int level) {
    final text = widget.controller.text;
    final start = _lastSel.start.clamp(0, text.length);
    final lineStart = text.lastIndexOf('\n', start - 1) + 1;
    final lineEndIdx = text.indexOf('\n', start);
    final lineEnd = lineEndIdx == -1 ? text.length : lineEndIdx;
    final line = text.substring(lineStart, lineEnd);
    final hashes = '#' * level;
    final activePrefix = '$hashes ';

    String newLine;
    if (line.startsWith(activePrefix)) {
      // Already this level — strip leading prefix and optional trailing close.
      newLine = line
          .substring(activePrefix.length)
          .replaceFirst(_trailingHashesRe, '');
    } else {
      // Different level or no heading — strip any heading prefix, then wrap.
      final stripped = line
          .replaceFirst(_leadingHeadingRe, '')
          .replaceFirst(_trailingHashesRe, '');
      newLine = '$activePrefix$stripped $hashes';
    }
    final newText =
        text.substring(0, lineStart) + newLine + text.substring(lineEnd);
    final caret = (lineStart + newLine.length).clamp(0, newText.length);
    _setText(newText, TextSelection.collapsed(offset: caret));
  }

  void _toggleWrap(String marker, _MdFormat fmt) {
    if (_active.contains(fmt)) {
      _unwrapSelection(marker);
    } else {
      _wrapSelection(marker, marker);
    }
  }

  void _unwrapSelection(String marker) {
    final text = widget.controller.text;
    final sel = _lastSel;
    if (sel.isCollapsed) return;
    final m = marker.length;
    final selText = text.substring(sel.start, sel.end);

    // Whole-markers selected: strip marker prefix/suffix from the selection.
    if (selText.length >= 2 * m &&
        selText.startsWith(marker) &&
        selText.endsWith(marker)) {
      final inner = selText.substring(m, selText.length - m);
      _setText(
        text.substring(0, sel.start) + inner + text.substring(sel.end),
        TextSelection(
          baseOffset: sel.start,
          extentOffset: sel.start + inner.length,
        ),
      );
      return;
    }
    // Markers immediately outside the selection.
    if (sel.start >= m &&
        sel.end + m <= text.length &&
        text.substring(sel.start - m, sel.start) == marker &&
        text.substring(sel.end, sel.end + m) == marker) {
      _setText(
        text.substring(0, sel.start - m) +
            selText +
            text.substring(sel.end + m),
        TextSelection(baseOffset: sel.start - m, extentOffset: sel.end - m),
      );
    }
  }

  void _toggleLinePrefix(String prefix, _MdFormat fmt) {
    if (_active.contains(fmt)) {
      _removeLinePrefix(prefix);
    } else {
      _insertAtLineStart(prefix);
    }
  }

  void _removeLinePrefix(String prefix) {
    final text = widget.controller.text;
    final start = _lastSel.start.clamp(0, text.length);
    final lineStart = text.lastIndexOf('\n', start - 1) + 1;
    final lineEndIdx = text.indexOf('\n', start);
    final lineEnd = lineEndIdx == -1 ? text.length : lineEndIdx;
    final line = text.substring(lineStart, lineEnd);
    if (!line.startsWith(prefix)) return;
    final newText =
        text.substring(0, lineStart) +
        line.substring(prefix.length) +
        text.substring(lineEnd);
    final caret = (start - prefix.length).clamp(lineStart, newText.length);
    _setText(newText, TextSelection.collapsed(offset: caret));
  }

  void _toggleNumbered() {
    if (!_active.contains(_MdFormat.numbered)) {
      _insertAtLineStart('1. ');
      return;
    }
    final text = widget.controller.text;
    final start = _lastSel.start.clamp(0, text.length);
    final lineStart = text.lastIndexOf('\n', start - 1) + 1;
    final lineEndIdx = text.indexOf('\n', start);
    final lineEnd = lineEndIdx == -1 ? text.length : lineEndIdx;
    final line = text.substring(lineStart, lineEnd);
    final match = _numberedRe.firstMatch(line);
    if (match == null) return;
    final removed = match.end;
    final newText =
        text.substring(0, lineStart) +
        line.substring(removed) +
        text.substring(lineEnd);
    final caret = (start - removed).clamp(lineStart, newText.length);
    _setText(newText, TextSelection.collapsed(offset: caret));
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
              active: _active.contains(_MdFormat.h1),
              onTap: () => _toggleHeading(1),
            ),
            _ToolbarTextButton(
              label: 'H2',
              color: color,
              active: _active.contains(_MdFormat.h2),
              onTap: () => _toggleHeading(2),
            ),
            _ToolbarTextButton(
              label: 'H3',
              color: color,
              active: _active.contains(_MdFormat.h3),
              onTap: () => _toggleHeading(3),
            ),
            _divider(),
            _ToolbarIconButton(
              icon: Icons.format_bold,
              color: color,
              tooltip: 'Bold',
              active: _active.contains(_MdFormat.bold),
              onTap: () => _toggleWrap('**', _MdFormat.bold),
            ),
            _ToolbarIconButton(
              icon: Icons.format_italic,
              color: color,
              tooltip: 'Italic',
              active: _active.contains(_MdFormat.italic),
              onTap: () => _toggleWrap('*', _MdFormat.italic),
            ),
            _ToolbarIconButton(
              icon: Icons.code,
              color: color,
              tooltip: 'Inline code',
              active: _active.contains(_MdFormat.code),
              onTap: () => _toggleWrap('`', _MdFormat.code),
            ),
            _divider(),
            _ToolbarIconButton(
              icon: Icons.format_list_bulleted,
              color: color,
              tooltip: 'Bullet list',
              active: _active.contains(_MdFormat.bullet),
              onTap: () => _toggleLinePrefix('- ', _MdFormat.bullet),
            ),
            _ToolbarIconButton(
              icon: Icons.format_list_numbered,
              color: color,
              tooltip: 'Numbered list',
              active: _active.contains(_MdFormat.numbered),
              onTap: _toggleNumbered,
            ),
            _ToolbarIconButton(
              icon: Icons.format_quote,
              color: color,
              tooltip: 'Blockquote',
              active: _active.contains(_MdFormat.quote),
              onTap: () => _toggleLinePrefix('> ', _MdFormat.quote),
            ),
            _divider(),
            _ToolbarIconButton(
              icon: Icons.link,
              color: color,
              tooltip: 'Link',
              active: false,
              onTap: () => _wrapSelection('[', '](url)'),
            ),
            _ToolbarIconButton(
              icon: Icons.horizontal_rule,
              color: color,
              tooltip: 'Horizontal rule',
              active: false,
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
  final bool active;
  final VoidCallback onTap;
  const _ToolbarIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = active ? scheme.onPrimaryContainer : color;
    final button = IconButton(
      icon: Icon(icon, size: 18, color: iconColor),
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );
    if (!active) return button;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: button,
    );
  }
}

class _ToolbarTextButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _ToolbarTextButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textColor = active ? scheme.onPrimaryContainer : color;
    const padding = EdgeInsets.symmetric(horizontal: 8, vertical: 6);
    final text = Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: active
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(padding: padding, child: text),
            )
          : Padding(padding: padding, child: text),
    );
  }
}
