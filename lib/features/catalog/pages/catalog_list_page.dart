import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';

import '../providers/catalog_providers.dart';

class CatalogListPage extends ConsumerWidget {
  const CatalogListPage({super.key});

  static final _currencyFormat = NumberFormat.currency(
    symbol: '\u20AC',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(filteredCatalogProvider);
    final search = ref.watch(catalogSearchProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Item Catalog')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search catalog...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () =>
                            ref.read(catalogSearchProvider.notifier).state = '',
                      )
                    : null,
              ),
              onChanged: (v) =>
                  ref.read(catalogSearchProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: items.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_stories, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No catalog items yet'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return Dismissible(
                      key: Key(item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) => showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Catalog Item'),
                          content: Text('Delete "${item.title}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                      onDismissed: (_) => ref
                          .read(catalogListProvider.notifier)
                          .deleteItem(item.id),
                      child: ListTile(
                        leading: item.imageUrls.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: CachedNetworkImage(
                                  imageUrl: item.imageUrls.first,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => CircleAvatar(
                                    child: Text(
                                      item.title.isNotEmpty
                                          ? item.title[0].toUpperCase()
                                          : '?',
                                    ),
                                  ),
                                ),
                              )
                            : CircleAvatar(
                                child: Text(
                                  item.title.isNotEmpty
                                      ? item.title[0].toUpperCase()
                                      : '?',
                                ),
                              ),
                        title: Text(item.title),
                        subtitle: Text(
                          [
                            if (item.description != null &&
                                item.description!.isNotEmpty)
                              item.description!,
                            if (item.price != null)
                              _currencyFormat.format(item.price),
                          ].join(' \u2022 '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: item.price != null
                            ? Text(
                                _currencyFormat.format(item.price),
                                style: theme.textTheme.bodySmall,
                              )
                            : null,
                        onTap: () => context.push('/catalog/${item.id}'),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/catalog/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
