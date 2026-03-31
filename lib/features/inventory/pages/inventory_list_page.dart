import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';

import '../../auth/providers/auth_providers.dart';
import '../providers/inventory_providers.dart';

class InventoryListPage extends ConsumerWidget {
  const InventoryListPage({super.key});

  static final _currencyFormat = NumberFormat.currency(
    symbol: '\u20AC',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(filteredInventoryProvider);
    final search = ref.watch(inventorySearchProvider);
    final totalValue = ref.watch(inventoryTotalValueProvider);
    final showImages =
        ref.watch(currentUserProvider)?.settings.showImagePreviews ?? true;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Inventory')),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context, ref),
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            // Search + summary
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              ref.read(inventorySearchProvider.notifier).state =
                                  '',
                        )
                      : null,
                ),
                onChanged: (v) =>
                    ref.read(inventorySearchProvider.notifier).state = v,
              ),
            ),

            // Total value bar
            totalValue.when(
              data: (value) => Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  'Total value: ${_currencyFormat.format(value)}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            // Item list
            Expanded(
              child: items.when(
                data: (list) {
                  if (list.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No items yet'),
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
                            title: const Text('Delete Item'),
                            content: Text('Delete "${item.name}"?'),
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
                            .read(inventoryListProvider.notifier)
                            .deleteItem(item.id),
                        child: ListTile(
                          leading: showImages && item.imageUrls.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: CachedNetworkImage(
                                    imageUrl: item.imageUrls.first,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => CircleAvatar(
                                      child: Text(
                                        item.name.isNotEmpty
                                            ? item.name[0].toUpperCase()
                                            : '?',
                                      ),
                                    ),
                                  ),
                                )
                              : CircleAvatar(
                                  child: Text(
                                    item.name.isNotEmpty
                                        ? item.name[0].toUpperCase()
                                        : '?',
                                  ),
                                ),
                          title: Text(item.name),
                          subtitle: Text(
                            [
                              if (item.category != null) item.category!,
                              if (item.location != null) item.location!,
                              if (item.quantity > 1) 'Qty: ${item.quantity}',
                              if (item.expiryDate != null)
                                item.expiryDate!.isBefore(DateTime.now())
                                    ? 'EXPIRED'
                                    : 'Exp: ${DateFormat.yMMMd().format(item.expiryDate!)}',
                            ].join(' \u2022 '),
                          ),
                          trailing: item.purchasePrice != null
                              ? Text(
                                  _currencyFormat.format(item.purchasePrice),
                                  style: theme.textTheme.bodySmall,
                                )
                              : null,
                          onTap: () => context.push('/inventory/${item.id}'),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/inventory/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    final categories = ref.read(inventoryCategoriesProvider).valueOrNull ?? [];
    final locations = ref.read(inventoryLocationsProvider).valueOrNull ?? [];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (categories.isNotEmpty) ...[
              const Text('Category'),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('All'),
                    onPressed: () {
                      ref.read(inventoryCategoryFilterProvider.notifier).state =
                          null;
                      Navigator.pop(ctx);
                    },
                  ),
                  ...categories.map(
                    (cat) => ActionChip(
                      label: Text(cat),
                      onPressed: () {
                        ref
                                .read(inventoryCategoryFilterProvider.notifier)
                                .state =
                            cat;
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (locations.isNotEmpty) ...[
              const Text('Location'),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('All'),
                    onPressed: () {
                      ref.read(inventoryLocationFilterProvider.notifier).state =
                          null;
                      Navigator.pop(ctx);
                    },
                  ),
                  ...locations.map(
                    (loc) => ActionChip(
                      label: Text(loc),
                      onPressed: () {
                        ref
                                .read(inventoryLocationFilterProvider.notifier)
                                .state =
                            loc;
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
