import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../services/image_upload_service.dart';
import '../../../services/log_service.dart';
import '../../../utils/search_aliases.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/catalog_item.dart';
import '../services/catalog_service.dart';
import '../services/firestore_catalog_service.dart';

final catalogServiceProvider = Provider<CatalogService>((ref) {
  if (AppConfig.useFirebase) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return FirestoreCatalogService(userId);
  }
  return MockCatalogService();
});

class CatalogListNotifier extends AsyncNotifier<List<CatalogItem>> {
  @override
  Future<List<CatalogItem>> build() async {
    return ref.watch(catalogServiceProvider).getItems();
  }

  Future<void> addItem(CatalogItem item) async {
    await ref.read(catalogServiceProvider).addItem(item);
    LogService.instance.info('Catalog item added: ${item.title}');
    ref.invalidateSelf();
  }

  Future<void> updateItem(CatalogItem item) async {
    await ref.read(catalogServiceProvider).updateItem(item);
    LogService.instance.info('Catalog item updated: ${item.id}');
    ref.invalidateSelf();
  }

  Future<void> deleteItem(String id) async {
    final item = await ref.read(catalogServiceProvider).getItem(id);
    if (item != null && item.imageUrls.isNotEmpty) {
      final uploader = ref.read(imageUploadServiceProvider);
      for (final url in item.imageUrls) {
        await uploader.deleteImage(url);
      }
    }
    await ref.read(catalogServiceProvider).deleteItem(id);
    LogService.instance.info('Catalog item deleted: $id');
    ref.invalidateSelf();
  }
}

final catalogListProvider =
    AsyncNotifierProvider<CatalogListNotifier, List<CatalogItem>>(
      CatalogListNotifier.new,
    );

final catalogSearchProvider = StateProvider<String>((_) => '');

final filteredCatalogProvider = Provider<AsyncValue<List<CatalogItem>>>((ref) {
  final items = ref.watch(catalogListProvider);
  final search = ref.watch(catalogSearchProvider).toLowerCase();

  return items.whenData((list) {
    if (search.isEmpty) return list;
    return list
        .where(
          (i) =>
              i.title.toLowerCase().contains(search) ||
              (i.description?.toLowerCase().contains(search) ?? false) ||
              matchesSearchAliases(i.searchAliases, search),
        )
        .toList();
  });
});
