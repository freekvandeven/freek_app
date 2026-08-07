import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:personal_app/presentation/widgets/app_snackbar.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../presentation/hooks/use_autosave.dart';
import '../../../presentation/widgets/file_drop_target.dart';
import '../../../presentation/widgets/unsaved_changes_guard.dart';
import '../../../services/image_upload_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../../gemini/providers/gemini_providers.dart';
import '../models/knowledge_page.dart';
import '../providers/knowledge_providers.dart';
import '../utils/autosave_snapshot.dart';
import '../utils/markdown_toolbar_logic.dart';

class KnowledgeEditPage extends StatefulHookConsumerWidget {
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
  final _searchAliasesController = TextEditingController();
  final _contentFocusNode = FocusNode();

  List<String> _tags = [];
  String? _parentId;
  bool _isWip = false;
  bool _isLoading = true;
  bool _showPreview = false;
  bool _isUploadingAttachment = false;
  KnowledgePage? _existing;
  AutosaveController? _autosave;

  /// Attachments already persisted to Firestore + Storage. Mutated in
  /// place on add/remove; the new value is sent on save.
  List<KnowledgeAttachment> _savedAttachments = [];

  /// Attachment URLs the user removed during this edit session. We hang
  /// onto these and delete them from Storage on save so a partial edit
  /// doesn't orphan files; same shape as recipe_edit_page's
  /// `_removedImageUrls`.
  final List<String> _removedAttachmentUrls = [];

  static const double _previewBreakpoint = 900;

  @override
  void initState() {
    super.initState();
    if (widget.pageId != null) {
      _loadPage();
    } else {
      _parentId = widget.initialParentId;
      _isLoading = false;
    }
  }

  /// True when the form has unsaved edits vs. the most recently saved
  /// snapshot — drives the unsaved-changes confirmation on back nav
  /// (WISH-0079).
  bool get _isDirty => _autosave?.isDirty ?? false;

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
        _savedAttachments = List.of(page.attachments);
        _searchAliasesController.text = page.searchAliases ?? '';
        _isLoading = false;
      });
      _autosave?.markClean();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _autosaveSnapshot() => knowledgeAutosaveSnapshot(
    title: _titleController.text,
    content: _contentController.text,
    tags: _tags,
    parentId: _parentId,
    isWip: _isWip,
    attachments: _savedAttachments,
    searchAliases: _searchAliasesController.text,
  );

  /// Persist step for [useAutosave]: returns false when validation fails.
  /// The first autosave of a brand-new page creates it; edits after that
  /// update it.
  Future<bool> _autosavePersist() async {
    if (!_formKey.currentState!.validate()) return false;

    final notifier = ref.read(knowledgeListProvider.notifier);
    final aliases = _searchAliasesController.text.trim();
    if (_existing != null) {
      await notifier.updatePage(
        _existing!.copyWith(
          title: _titleController.text.trim(),
          content: _contentController.text,
          tags: _tags,
          parentId: () => _parentId,
          isWip: _isWip,
          attachments: _savedAttachments,
          searchAliases: () => aliases.isEmpty ? null : aliases,
        ),
      );
    } else {
      final page = KnowledgePage(
        title: _titleController.text.trim(),
        content: _contentController.text,
        tags: _tags,
        parentId: _parentId,
        isWip: _isWip,
        attachments: _savedAttachments,
        searchAliases: aliases.isEmpty ? null : aliases,
      );
      await notifier.addPage(page);
      if (mounted) setState(() => _existing = page);
    }
    return true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _searchAliasesController.dispose();
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
    final aliases = _searchAliasesController.text.trim();
    if (_existing != null) {
      await notifier.updatePage(
        _existing!.copyWith(
          title: _titleController.text.trim(),
          content: _contentController.text,
          tags: _tags,
          parentId: () => _parentId,
          isWip: _isWip,
          attachments: _savedAttachments,
          searchAliases: () => aliases.isEmpty ? null : aliases,
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
          attachments: _savedAttachments,
          searchAliases: aliases.isEmpty ? null : aliases,
        ),
      );
    }

    // Clean up files the user removed during this edit session. Storage
    // triggers will decrement storageUsedBytes automatically.
    final uploader = ref.read(imageUploadServiceProvider);
    for (final url in _removedAttachmentUrls) {
      await uploader.deleteFile(url);
    }

    // Mark the form as clean so the unsaved-changes guard lets the
    // post-save pop through unprompted (WISH-0079).
    _autosave?.markClean();
    if (mounted) context.pop();
  }

  Future<void> _pickAndUploadAttachment() async {
    final uploader = ref.read(imageUploadServiceProvider);
    final picked = await uploader.pickAnyFile();
    if (picked == null || picked.bytes == null) return;

    setState(() => _isUploadingAttachment = true);
    try {
      final upload = await uploader.uploadFileBytes(
        picked.bytes!,
        fileName: picked.name,
        folder: 'knowledge',
      );
      if (!mounted) return;
      setState(() {
        _savedAttachments = [
          ..._savedAttachments,
          KnowledgeAttachment(
            url: upload.url,
            fileName: upload.fileName,
            contentType: upload.contentType,
            sizeBytes: upload.sizeBytes,
          ),
        ];
      });
    } on StorageLimitExceededException catch (e) {
      if (mounted) {
        context.showErrorSnackbar(e.toString());
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Upload failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploadingAttachment = false);
    }
  }

  void _removeAttachment(int index) {
    final removed = _savedAttachments[index];
    setState(() {
      _savedAttachments = [..._savedAttachments]..removeAt(index);
      _removedAttachmentUrls.add(removed.url);
    });
  }

  Future<void> _showAiAssist() async {
    final keyAvailable = await ref.read(geminiApiKeyAvailableProvider.future);
    if (!mounted) return;

    if (!keyAvailable) {
      context.showSnackbar(
        'No Gemini API key configured. Add one in Settings.',
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
      final ready = await configureGeminiForCurrentSettings(ref);
      if (!ready) {
        if (mounted) {
          context.showSnackbar(
            'Gemini is not configured. Set it up in Settings → AI.',
          );
        }
        return;
      }
      final service = ref.read(geminiServiceProvider);
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
        context.showErrorSnackbar('AI error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.pageId != null;
    _autosave = useAutosave(
      intervalMinutes:
          ref.watch(currentUserProvider)?.settings.autosaveIntervalMinutes ?? 0,
      captureInitialBaseline: !isEditing,
      snapshot: _autosaveSnapshot,
      save: _autosavePersist,
    );
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

    final width = MediaQuery.sizeOf(context).width;
    final canShowPreview = width >= _previewBreakpoint;
    final showPreview = _showPreview && canShowPreview;

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      child: Scaffold(
        appBar: AppBar(
          title: QuickActionsTitle(
            child: Text(isEditing ? 'Edit Page' : 'New Page'),
          ),
          actions: [
            if (canShowPreview)
              IconButton(
                isSelected: _showPreview,
                icon: const Icon(Icons.preview_outlined),
                selectedIcon: const Icon(Icons.preview),
                tooltip: _showPreview ? 'Hide preview' : 'Show preview',
                onPressed: () => setState(() => _showPreview = !_showPreview),
              ),
            IconButton(
              icon: const Icon(Icons.auto_awesome_outlined),
              tooltip: 'AI Assist',
              onPressed: _showAiAssist,
            ),
            TextButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
        body: FileDropTarget(
          onFiles: _attachDroppedFiles,
          child: Form(
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

                TextFormField(
                  controller: _searchAliasesController,
                  decoration: const InputDecoration(
                    labelText: 'Nicknames',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sell_outlined),
                    helperText:
                        'Extra search words, separated by space, comma or '
                        'period. Not shown in lists.',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 16),

                SwitchListTile(
                  title: const Text('Work in Progress'),
                  subtitle: const Text('Mark this page as WIP'),
                  value: _isWip,
                  onChanged: (v) => setState(() => _isWip = v),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),

                // Attachments
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Attachments',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton.icon(
                      onPressed: _isUploadingAttachment
                          ? null
                          : _pickAndUploadAttachment,
                      icon: _isUploadingAttachment
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.attach_file, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                if (_savedAttachments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'No attachments. Any file type — counts toward your '
                      'storage quota.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ..._savedAttachments.asMap().entries.map(
                    (entry) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(
                        entry.value.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${entry.value.contentType} · '
                        '${formatBytes(entry.value.sizeBytes)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.open_in_new, size: 18),
                            tooltip: 'Open',
                            onPressed: () =>
                                launchUrl(Uri.parse(entry.value.url)),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 20,
                            ),
                            tooltip: 'Remove',
                            onPressed: () => _removeAttachment(entry.key),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Content area — single column or side-by-side preview
                if (showPreview)
                  SizedBox(
                    height: 600,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _MarkdownToolbar(
                                controller: _contentController,
                                focusNode: _contentFocusNode,
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: TextFormField(
                                  controller: _contentController,
                                  focusNode: _contentFocusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Content (Markdown)',
                                    border: OutlineInputBorder(),
                                    alignLabelWithHint: true,
                                  ),
                                  expands: true,
                                  maxLines: null,
                                  minLines: null,
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                      ? 'Required'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _previewPanel(context)),
                      ],
                    ),
                  )
                else ...[
                  _MarkdownToolbar(
                    controller: _contentController,
                    focusNode: _contentFocusNode,
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _contentController,
                    focusNode: _contentFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Content (Markdown)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                      hintText:
                          '# Heading\n\nWrite your content in Markdown...',
                    ),
                    maxLines: 20,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _attachDroppedFiles(List<DroppedFile> files) async {
    final uploader = ref.read(imageUploadServiceProvider);
    setState(() => _isUploadingAttachment = true);
    try {
      for (final dropped in files) {
        final upload = await uploader.uploadFileBytes(
          dropped.bytes,
          fileName: dropped.fileName,
          contentType: dropped.mimeType,
          folder: 'knowledge',
        );
        if (!mounted) return;
        setState(() {
          _savedAttachments = [
            ..._savedAttachments,
            KnowledgeAttachment(
              url: upload.url,
              fileName: upload.fileName,
              contentType: upload.contentType,
              sizeBytes: upload.sizeBytes,
            ),
          ];
        });
      }
    } on StorageLimitExceededException catch (e) {
      if (mounted) {
        context.showErrorSnackbar(e.toString());
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Upload failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploadingAttachment = false);
    }
  }

  Widget _previewPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _contentController,
            builder: (context, value, _) {
              final empty = value.text.trim().isEmpty;
              return MarkdownBody(
                data: empty ? '_Preview will appear here…_' : value.text,
                selectable: true,
                onTapLink: (text, href, title) async {
                  if (href == null) return;
                  final uri = Uri.tryParse(href);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              );
            },
          ),
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

class _MarkdownToolbarState extends State<_MarkdownToolbar> {
  // Last known valid selection — updated while the field has focus.
  // Clicking a toolbar button blurs the field on web/desktop, making
  // controller.selection invalid, so we cache it here instead.
  TextSelection _lastSel = const TextSelection.collapsed(offset: 0);
  Set<MarkdownFormat> _active = const {};

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
    final next = detectMarkdownFormats(widget.controller.text, _lastSel);
    if (!setEquals(next, _active)) {
      setState(() => _active = next);
    }
  }

  void _apply(ToolbarEditResult result) {
    widget.controller.value = TextEditingValue(
      text: result.text,
      selection: result.selection,
    );
    widget.focusNode.requestFocus();
  }

  void _toggleHeading(int level) {
    _apply(toggleHeading(widget.controller.text, _lastSel, level));
  }

  void _toggleWrap(String marker, MarkdownFormat fmt) {
    final text = widget.controller.text;
    _apply(
      _active.contains(fmt)
          ? unwrapSelection(text, _lastSel, marker)
          : wrapSelection(text, _lastSel, marker, marker),
    );
  }

  void _toggleLinePrefix(String prefix, MarkdownFormat fmt) {
    final text = widget.controller.text;
    _apply(
      _active.contains(fmt)
          ? removeLinePrefix(text, _lastSel, prefix)
          : insertAtLineStart(text, _lastSel, prefix),
    );
  }

  void _toggleNumbered() {
    final text = widget.controller.text;
    _apply(
      _active.contains(MarkdownFormat.numbered)
          ? removeNumberedPrefix(text, _lastSel)
          : insertAtLineStart(text, _lastSel, '1. '),
    );
  }

  void _wrapSelectionInline(String before, String after) {
    _apply(wrapSelection(widget.controller.text, _lastSel, before, after));
  }

  void _insertAtLineStart(String prefix) {
    _apply(insertAtLineStart(widget.controller.text, _lastSel, prefix));
  }

  void _insertTable() {
    _apply(insertTable(widget.controller.text, _lastSel));
  }

  void _addTableRow() =>
      _applyTableEdit(addTableRow(widget.controller.text, _lastSel));

  void _removeTableRow() =>
      _applyTableEdit(removeTableRow(widget.controller.text, _lastSel));

  void _addTableColumn() =>
      _applyTableEdit(addTableColumn(widget.controller.text, _lastSel));

  void _removeTableColumn() =>
      _applyTableEdit(removeTableColumn(widget.controller.text, _lastSel));

  /// Row/column edits are no-ops (return null) when the caret isn't
  /// inside a table — surface that instead of silently doing nothing
  /// (WISH-0095).
  void _applyTableEdit(ToolbarEditResult? result) {
    if (result == null) {
      context.showSnackbar('Place your cursor inside a table first');
      return;
    }
    _apply(result);
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
              active: _active.contains(MarkdownFormat.h1),
              onTap: () => _toggleHeading(1),
            ),
            _ToolbarTextButton(
              label: 'H2',
              color: color,
              active: _active.contains(MarkdownFormat.h2),
              onTap: () => _toggleHeading(2),
            ),
            _ToolbarTextButton(
              label: 'H3',
              color: color,
              active: _active.contains(MarkdownFormat.h3),
              onTap: () => _toggleHeading(3),
            ),
            _divider(),
            _ToolbarIconButton(
              icon: Icons.format_bold,
              color: color,
              tooltip: 'Bold',
              active: _active.contains(MarkdownFormat.bold),
              onTap: () => _toggleWrap('**', MarkdownFormat.bold),
            ),
            _ToolbarIconButton(
              icon: Icons.format_italic,
              color: color,
              tooltip: 'Italic',
              active: _active.contains(MarkdownFormat.italic),
              onTap: () => _toggleWrap('*', MarkdownFormat.italic),
            ),
            _ToolbarIconButton(
              icon: Icons.code,
              color: color,
              tooltip: 'Inline code',
              active: _active.contains(MarkdownFormat.code),
              onTap: () => _toggleWrap('`', MarkdownFormat.code),
            ),
            _divider(),
            _ToolbarIconButton(
              icon: Icons.format_list_bulleted,
              color: color,
              tooltip: 'Bullet list',
              active: _active.contains(MarkdownFormat.bullet),
              onTap: () => _toggleLinePrefix('- ', MarkdownFormat.bullet),
            ),
            _ToolbarIconButton(
              icon: Icons.format_list_numbered,
              color: color,
              tooltip: 'Numbered list',
              active: _active.contains(MarkdownFormat.numbered),
              onTap: _toggleNumbered,
            ),
            _ToolbarIconButton(
              icon: Icons.format_quote,
              color: color,
              tooltip: 'Blockquote',
              active: _active.contains(MarkdownFormat.quote),
              onTap: () => _toggleLinePrefix('> ', MarkdownFormat.quote),
            ),
            _divider(),
            _ToolbarIconButton(
              icon: Icons.link,
              color: color,
              tooltip: 'Link',
              active: false,
              onTap: () => _wrapSelectionInline('[', '](url)'),
            ),
            _ToolbarIconButton(
              icon: Icons.horizontal_rule,
              color: color,
              tooltip: 'Horizontal rule',
              active: false,
              onTap: () => _insertAtLineStart('---\n'),
            ),
            _divider(),
            _ToolbarIconButton(
              icon: Icons.table_chart_outlined,
              color: color,
              tooltip: 'Insert table',
              active: false,
              onTap: _insertTable,
            ),
            _ToolbarTextButton(
              label: '+Row',
              color: color,
              onTap: _addTableRow,
            ),
            _ToolbarTextButton(
              label: '-Row',
              color: color,
              onTap: _removeTableRow,
            ),
            _ToolbarTextButton(
              label: '+Col',
              color: color,
              onTap: _addTableColumn,
            ),
            _ToolbarTextButton(
              label: '-Col',
              color: color,
              onTap: _removeTableColumn,
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
