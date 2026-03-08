import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/knowledge_providers.dart';

class KnowledgeViewPage extends ConsumerWidget {
  final String pageId;
  const KnowledgeViewPage({super.key, required this.pageId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allPages = ref.watch(knowledgeListProvider);
    final breadcrumbs = ref.watch(breadcrumbProvider(pageId));
    final children = ref.watch(childKnowledgePagesProvider(pageId));

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
        final page = pages.where((p) => p.id == pageId).firstOrNull;
        if (page == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Page not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(page.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => context.push('/knowledge/$pageId/edit'),
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
          body: _buildBody(context, ref, page, breadcrumbs, children),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    dynamic page,
    AsyncValue<List<dynamic>> breadcrumbs,
    AsyncValue<List<dynamic>> children,
  ) {
    final crumbs = breadcrumbs.valueOrNull ?? [];
    final childPages = children.valueOrNull ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Breadcrumbs
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
                        crumbs[i].title as String,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    )
                  else
                    Text(
                      crumbs[i].title as String,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                ],
              ],
            ),
          ),

        // Tags
        if ((page.tags as List).isNotEmpty) ...[
          Wrap(
            spacing: 6,
            children: (page.tags as List<String>)
                .map(
                  (t) => Chip(
                    label: Text(t),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Markdown content
        MarkdownBody(data: page.content as String, selectable: true),

        // Child pages
        if (childPages.isNotEmpty) ...[
          const Divider(height: 32),
          Text('Sub-pages', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final child in childPages)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.article_outlined),
              title: Text(child.title as String),
              onTap: () => context.push('/knowledge/${child.id}'),
            ),
        ],
      ],
    );
  }
}
