import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';

import '../../catalog/models/catalog_item.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../models/shopping_item.dart';
import '../providers/shopping_providers.dart';

class ShoppingListPage extends ConsumerWidget {
  const ShoppingListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(filteredShoppingProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Shopping List')),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                ref.read(shoppingListProvider.notifier).clearCompleted();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Text('Clear completed'),
              ),
            ],
          ),
        ],
      ),
      body: items.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Shopping list is empty'),
                ],
              ),
            );
          }

          final pending = list.where((i) => !i.isCompleted).toList();
          final completed = list.where((i) => i.isCompleted).toList();

          return ListView(
            children: [
              if (pending.isNotEmpty)
                ...pending.map((item) => _ShoppingTile(item: item)),
              if (completed.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Completed (${completed.length})',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ...completed.map((item) => _ShoppingTile(item: item)),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController();
    String? catalogItemId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Shopping Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Item name'),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    decoration: const InputDecoration(labelText: 'Qty'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: unitCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Unit (optional)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final catalogItems = await ref
                      .read(catalogServiceProvider)
                      .getItems();
                  if (!ctx.mounted || catalogItems.isEmpty) return;
                  final picked = await showModalBottomSheet<CatalogItem>(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (c) =>
                        _ShoppingCatalogPickerSheet(items: catalogItems),
                  );
                  if (picked != null) {
                    titleCtrl.text = picked.title;
                    catalogItemId = picked.id;
                  }
                },
                icon: const Icon(Icons.auto_stories, size: 18),
                label: const Text('Pick from catalog'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (titleCtrl.text.trim().isNotEmpty) {
                ref
                    .read(shoppingListProvider.notifier)
                    .addItem(
                      ShoppingItem(
                        title: titleCtrl.text.trim(),
                        quantity: int.tryParse(qtyCtrl.text) ?? 1,
                        unit: unitCtrl.text.trim().isEmpty
                            ? null
                            : unitCtrl.text.trim(),
                        catalogItemId: catalogItemId,
                      ),
                    );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _ShoppingTile extends ConsumerWidget {
  final ShoppingItem item;
  const _ShoppingTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subtitle = [
      if (item.quantity > 1) 'x${item.quantity}',
      if (item.unit != null) item.unit!,
    ].join(' ');

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) =>
          ref.read(shoppingListProvider.notifier).deleteItem(item.id),
      child: ListTile(
        leading: Checkbox(
          value: item.isCompleted,
          onChanged: (_) =>
              ref.read(shoppingListProvider.notifier).toggleItem(item.id),
        ),
        title: Text(
          item.title,
          style: item.isCompleted
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : null,
        ),
        subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      ),
    );
  }
}

class _ShoppingCatalogPickerSheet extends StatefulWidget {
  final List<CatalogItem> items;
  const _ShoppingCatalogPickerSheet({required this.items});

  @override
  State<_ShoppingCatalogPickerSheet> createState() =>
      _ShoppingCatalogPickerSheetState();
}

class _ShoppingCatalogPickerSheetState
    extends State<_ShoppingCatalogPickerSheet> {
  String _search = '';

  List<CatalogItem> get _filtered {
    if (_search.isEmpty) return widget.items;
    final q = _search.toLowerCase();
    return widget.items
        .where(
          (i) =>
              i.title.toLowerCase().contains(q) ||
              (i.description?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search catalog...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final item = _filtered[index];
                return ListTile(
                  leading: item.imageUrls.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: CachedNetworkImage(
                            imageUrl: item.imageUrls.first,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
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
                  subtitle: item.description != null
                      ? Text(
                          item.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
