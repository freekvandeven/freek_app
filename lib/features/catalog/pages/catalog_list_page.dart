import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';
import 'package:personal_app/presentation/widgets/star_rating.dart';

import '../../../presentation/hooks/use_synced_search_controller.dart';
import '../../../presentation/widgets/pullable_center.dart';
import '../../settings/providers/currency_providers.dart';
import '../providers/catalog_providers.dart';

class CatalogListPage extends HookConsumerWidget {
  const CatalogListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final converter = ref.watch(currencyConverterProvider);
    final items = ref.watch(filteredCatalogProvider);
    final search = ref.watch(catalogSearchProvider);
    final searchController = useSyncedSearchController(search);
    final theme = Theme.of(context);

    // Catalog isn't part of the bottom-nav shell, so a normal push/pop
    // disposes this page when the user leaves for a different feature —
    // reset the search then (but not on the way back from a detail/edit
    // push within Catalog itself, since that doesn't dispose this page)
    // (BUG-0047).
    useEffect(() {
      if (ref.read(catalogSearchProvider).isNotEmpty) {
        ref.read(catalogSearchProvider.notifier).state = '';
      }
      return null;
    }, const []);

    return Scaffold(
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Item Catalog')),
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: searchController,
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
                              ref.read(catalogSearchProvider.notifier).state =
                                  '',
                        )
                      : null,
                ),
                onChanged: (v) =>
                    ref.read(catalogSearchProvider.notifier).state = v,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(catalogListProvider.future),
                child: items.when(
                  data: (list) {
                    if (list.isEmpty) {
                      return const PullableCenter(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_stories,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text('No catalog items yet'),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
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
                                      memCacheWidth: 120,
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
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  [
                                    if (item.description != null &&
                                        item.description!.isNotEmpty)
                                      item.description!,
                                    if (item.price != null)
                                      converter.format(item.price!),
                                  ].join(' \u2022 '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (item.rating != null)
                                  StarRating(
                                    value: item.rating,
                                    size: 14,
                                    showNumeric: false,
                                  ),
                              ],
                            ),
                            trailing: item.price != null
                                ? Text(
                                    converter.format(item.price!),
                                    style: theme.textTheme.bodySmall,
                                  )
                                : null,
                            onTap: () => context.push('/catalog/${item.id}'),
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const PullableCenter(child: CircularProgressIndicator()),
                  error: (e, _) => PullableCenter(child: Text('Error: $e')),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/catalog/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
