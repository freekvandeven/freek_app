import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';

import '../models/knowledge_page.dart';
import '../providers/knowledge_providers.dart';

class KnowledgeBankPage extends ConsumerWidget {
  const KnowledgeBankPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(knowledgeSearchProvider);
    final isSearching = search.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Knowledge Bank')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/knowledge/new'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by title or tag...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
                suffixIcon: search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () =>
                            ref.read(knowledgeSearchProvider.notifier).state =
                                '',
                      )
                    : null,
              ),
              onChanged: (v) =>
                  ref.read(knowledgeSearchProvider.notifier).state = v,
            ),
          ),
          Expanded(child: isSearching ? _SearchResults() : _TreeView()),
        ],
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(filteredKnowledgeProvider);

    return filtered.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (pages) {
        if (pages.isEmpty) {
          return const Center(child: Text('No pages found'));
        }
        return ListView.builder(
          itemCount: pages.length,
          itemBuilder: (context, index) {
            final page = pages[index];
            return ListTile(
              leading: const Icon(Icons.article),
              title: Text(page.title),
              subtitle: page.tags.isNotEmpty
                  ? Text(page.tags.join(', '))
                  : null,
              onTap: () => context.push('/knowledge/${page.id}'),
            );
          },
        );
      },
    );
  }
}

class _TreeView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rootPages = ref.watch(rootKnowledgePagesProvider);

    return rootPages.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (pages) {
        if (pages.isEmpty) {
          return const Center(
            child: Text('No pages yet.\nTap + to create your first page.'),
          );
        }
        return ListView.builder(
          itemCount: pages.length,
          itemBuilder: (context, index) {
            return _PageTreeTile(page: pages[index], depth: 0);
          },
        );
      },
    );
  }
}

class _PageTreeTile extends ConsumerStatefulWidget {
  final KnowledgePage page;
  final int depth;
  const _PageTreeTile({required this.page, required this.depth});

  @override
  ConsumerState<_PageTreeTile> createState() => _PageTreeTileState();
}

class _PageTreeTileState extends ConsumerState<_PageTreeTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childKnowledgePagesProvider(widget.page.id));
    final hasChildren =
        children.whenOrNull(data: (list) => list.isNotEmpty) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => context.push('/knowledge/${widget.page.id}'),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16.0 + widget.depth * 24.0,
              right: 16,
              top: 8,
              bottom: 8,
            ),
            child: Row(
              children: [
                if (hasChildren)
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Icon(
                      _expanded ? Icons.expand_more : Icons.chevron_right,
                      size: 20,
                    ),
                  )
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                const Icon(Icons.article_outlined, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.page.title,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                if (widget.page.tags.isNotEmpty)
                  Icon(
                    Icons.label_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
              ],
            ),
          ),
        ),
        if (_expanded && hasChildren)
          children.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (childPages) => Column(
              children: childPages
                  .map(
                    (child) =>
                        _PageTreeTile(page: child, depth: widget.depth + 1),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
