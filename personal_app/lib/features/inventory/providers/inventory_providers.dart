import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/inventory_item.dart';
import '../services/firestore_inventory_service.dart';
import '../services/inventory_service.dart';

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  if (AppConfig.useFirebase) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return FirestoreInventoryService(userId);
  }
  return MockInventoryService();
});

class InventoryListNotifier extends AsyncNotifier<List<InventoryItem>> {
  @override
  Future<List<InventoryItem>> build() async {
    return ref.read(inventoryServiceProvider).getItems();
  }

  Future<void> addItem(InventoryItem item) async {
    await ref.read(inventoryServiceProvider).addItem(item);
    ref.invalidateSelf();
  }

  Future<void> updateItem(InventoryItem item) async {
    await ref.read(inventoryServiceProvider).updateItem(item);
    ref.invalidateSelf();
  }

  Future<void> deleteItem(String id) async {
    await ref.read(inventoryServiceProvider).deleteItem(id);
    ref.invalidateSelf();
  }
}

final inventoryListProvider =
    AsyncNotifierProvider<InventoryListNotifier, List<InventoryItem>>(
      InventoryListNotifier.new,
    );

final inventorySearchProvider = StateProvider<String>((_) => '');
final inventoryCategoryFilterProvider = StateProvider<String?>((_) => null);
final inventoryLocationFilterProvider = StateProvider<String?>((_) => null);

final filteredInventoryProvider = Provider<AsyncValue<List<InventoryItem>>>((
  ref,
) {
  final items = ref.watch(inventoryListProvider);
  final search = ref.watch(inventorySearchProvider).toLowerCase();
  final category = ref.watch(inventoryCategoryFilterProvider);
  final location = ref.watch(inventoryLocationFilterProvider);

  return items.whenData((list) {
    var filtered = list;
    if (search.isNotEmpty) {
      filtered = filtered
          .where(
            (i) =>
                i.name.toLowerCase().contains(search) ||
                (i.description?.toLowerCase().contains(search) ?? false) ||
                (i.barcode?.toLowerCase().contains(search) ?? false),
          )
          .toList();
    }
    if (category != null) {
      filtered = filtered.where((i) => i.category == category).toList();
    }
    if (location != null) {
      filtered = filtered.where((i) => i.location == location).toList();
    }
    return filtered;
  });
});

final inventoryCategoriesProvider = Provider<AsyncValue<List<String>>>((ref) {
  return ref.watch(inventoryListProvider).whenData((items) {
    return items.map((i) => i.category).whereType<String>().toSet().toList()
      ..sort();
  });
});

final inventoryLocationsProvider = Provider<AsyncValue<List<String>>>((ref) {
  return ref.watch(inventoryListProvider).whenData((items) {
    return items.map((i) => i.location).whereType<String>().toSet().toList()
      ..sort();
  });
});

final inventoryTotalValueProvider = Provider<AsyncValue<double>>((ref) {
  return ref.watch(inventoryListProvider).whenData((items) {
    return items.fold<double>(
      0,
      (sum, i) => sum + (i.purchasePrice ?? 0) * i.quantity,
    );
  });
});
