import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/knowledge_page.dart';
import '../providers/knowledge_providers.dart';

class KnowledgeViewPage extends ConsumerStatefulWidget {
  final String pageId;
  const KnowledgeViewPage({super.key, required this.pageId});

  @override
  ConsumerState<KnowledgeViewPage> createState() => _KnowledgeViewPageState();
}

class _KnowledgeViewPageState extends ConsumerState<KnowledgeViewPage> {
  String? _lastContent;
  List<_ContentSection> _sections = const [];

  // Rebuilds sections only when content changes so GlobalKeys stay stable.
  void _updateSections(String content) {
    if (content == _lastContent) return;
    _lastContent = content;
    setState(() => _sections = _parseSections(content));
  }

  // Optional closing #s (CommonMark ATX heading closer) must be preceded by
  // whitespace, so `# C# tutorial` keeps its inline `#`.
  static final _headingRe = RegExp(r'^(#{1,6})\s+(.+?)(?:\s+#+)?\s*$');

  List<_ContentSection> _parseSections(String content) {
    if (content.trim().isEmpty) {
      return [_ContentSection(heading: null, content: content)];
    }

    final lines = content.split('\n');
    final sections = <_ContentSection>[];
    final current = <String>[];
    _TocEntry? heading;
    bool inFence = false;

    for (final line in lines) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        inFence = !inFence;
      }

      if (!inFence) {
        final m = _headingRe.firstMatch(line);
        if (m != null) {
          sections.add(
            _ContentSection(heading: heading, content: current.join('\n')),
          );
          current.clear();
          heading = _TocEntry(
            level: m.group(1)!.length,
            text: _stripInlineMarkdown(m.group(2)!.trim()),
          );
          current.add(line);
          continue;
        }
      }
      current.add(line);
    }
    sections.add(
      _ContentSection(heading: heading, content: current.join('\n')),
    );

    return sections
        .where((s) => s.heading != null || s.content.trim().isNotEmpty)
        .toList();
  }

  static String _stripInlineMarkdown(String text) => text
      .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
      .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')
      .replaceAll(RegExp(r'__(.+?)__'), r'$1')
      .replaceAll(RegExp(r'_(.+?)_'), r'$1')
      .replaceAll(RegExp(r'`(.+?)`'), r'$1')
      .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
      .trim();

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPages = ref.watch(knowledgeListProvider);
    final breadcrumbs = ref.watch(breadcrumbProvider(widget.pageId));
    final children = ref.watch(childKnowledgePagesProvider(widget.pageId));

    return allPages.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (pages) {
        final page = pages.where((p) => p.id == widget.pageId).firstOrNull;
        if (page == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Page not found')),
          );
        }

        _updateSections(page.content);

        return Scaffold(
          appBar: AppBar(
            title: QuickActionsTitle(child: Text(page.title)),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add sub-page',
                onPressed: () =>
                    context.push('/knowledge/new?parentId=${widget.pageId}'),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () =>
                    context.push('/knowledge/${widget.pageId}/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete page?'),
                      content: const Text(
                        'Child pages will be moved to root level.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ref
                                .read(knowledgeListProvider.notifier)
                                .deletePage(page.id);
                            context.pop();
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          body: _buildBody(context, page, breadcrumbs, children),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    KnowledgePage page,
    AsyncValue<List<KnowledgePage>> breadcrumbs,
    AsyncValue<List<KnowledgePage>> children,
  ) {
    final crumbs = breadcrumbs.valueOrNull ?? [];
    final childPages = children.valueOrNull ?? [];
    final tocEntries = _sections.where((s) => s.heading != null).toList();

    final contentItems = <Widget>[
      if (crumbs.length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            children: [
              for (var i = 0; i < crumbs.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(' > '),
                  ),
                if (i < crumbs.length - 1)
                  GestureDetector(
                    onTap: () => context.push('/knowledge/${crumbs[i].id}'),
                    child: Text(
                      crumbs[i].title,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                else
                  Text(
                    crumbs[i].title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
              ],
            ],
          ),
        ),

      if (page.tags.isNotEmpty) ...[
        Wrap(
          spacing: 6,
          children: page.tags
              .map(
                (t) =>
                    Chip(label: Text(t), visualDensity: VisualDensity.compact),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
      ],

      // Markdown content split by heading so each section has a GlobalKey anchor
      for (final section in _sections)
        _SectionWidget(key: section.heading?.key, content: section.content),

      if (childPages.isNotEmpty) ...[
        const Divider(height: 32),
        Text('Sub-pages', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final child in childPages)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.article_outlined),
            title: Text(child.title),
            onTap: () => context.push('/knowledge/${child.id}'),
          ),
      ],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final showToc = constraints.maxWidth >= 900 && tocEntries.isNotEmpty;

        final contentList = ListView(
          padding: const EdgeInsets.all(16),
          children: contentItems,
        );

        if (!showToc) return contentList;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: contentList),
            _TocPanel(
              sections: tocEntries,
              onTap: (entry) => _scrollTo(entry.heading!.key),
            ),
          ],
        );
      },
    );
  }
}

// Renders one content section (heading + following paragraphs).
// Stateless so it doesn't create keys; the parent manages the GlobalKey.
class _SectionWidget extends StatelessWidget {
  final String content;
  const _SectionWidget({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: content,
      selectable: true,
      onTapLink: (text, href, title) async {
        if (href == null) return;
        final uri = Uri.tryParse(href);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}

class _TocPanel extends StatelessWidget {
  final List<_ContentSection> sections;
  final ValueChanged<_ContentSection> onTap;

  const _TocPanel({required this.sections, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Text(
              'Contents',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 16),
              itemCount: sections.length,
              itemBuilder: (context, i) {
                final section = sections[i];
                final entry = section.heading!;
                final indent = (entry.level - 1) * 10.0;
                return InkWell(
                  onTap: () => onTap(section),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(indent + 8, 4, 8, 4),
                    child: Text(
                      entry.text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: entry.level == 1
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                        fontWeight: entry.level == 1 ? FontWeight.w600 : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TocEntry {
  final int level;
  final String text;
  final GlobalKey key;
  _TocEntry({required this.level, required this.text}) : key = GlobalKey();
}

class _ContentSection {
  final _TocEntry? heading;
  final String content;
  _ContentSection({required this.heading, required this.content});
}
