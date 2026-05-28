import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:personal_app/presentation/widgets/fullscreen_image_viewer.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../settings/providers/currency_providers.dart';
import '../providers/catalog_providers.dart';

class CatalogDetailPage extends ConsumerWidget {
  final String itemId;
  const CatalogDetailPage({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final converter = ref.watch(currencyConverterProvider);
    final items = ref.watch(catalogListProvider);
    final theme = Theme.of(context);

    return items.when(
      data: (list) {
        final item = list.where((i) => i.id == itemId).firstOrNull;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Item not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(item.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => context.push('/catalog/${item.id}/edit'),
              ),
            ],
          ),
          body: ResponsiveCenter(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Image gallery
                if (item.imageUrls.isNotEmpty) ...[
                  SizedBox(
                    height: 250,
                    child: PageView.builder(
                      itemCount: item.imageUrls.length,
                      itemBuilder: (context, index) => GestureDetector(
                        onTap: () => showFullscreenNetworkImage(
                          context,
                          item.imageUrls[index],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: item.imageUrls[index],
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image, size: 64),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (item.imageUrls.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${item.imageUrls.length} images \u2022 swipe to browse',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 16),
                ],

                // Price
                if (item.price != null) ...[
                  Text(
                    converter.format(item.price!),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Description
                if (item.description != null &&
                    item.description!.isNotEmpty) ...[
                  Text(item.description!, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 16),
                ],

                // Link
                if (item.link != null && item.link!.isNotEmpty) ...[
                  InkWell(
                    onTap: () => _openLink(item.link!),
                    child: Row(
                      children: [
                        const Icon(Icons.link, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.link!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Metadata
                const Divider(),
                Text(
                  item.updatedAt.isAfter(
                        item.createdAt.add(const Duration(minutes: 1)),
                      )
                      ? 'Updated ${DateFormat.yMMMd().format(item.updatedAt)} · created ${DateFormat.yMMMd().format(item.createdAt)}'
                      : 'Created ${DateFormat.yMMMd().format(item.createdAt)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
