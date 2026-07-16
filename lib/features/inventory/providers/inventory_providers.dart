import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../services/image_upload_service.dart';
import '../../../services/log_service.dart';
import '../../../utils/search_aliases.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/inventory_item.dart';
import '../services/firestore_inventory_service.dart';
import '../services/inventory_service.dart';
import '../utils/inventory_sort.dart';
import '../utils/quantity_transfer.dart';

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  if (AppConfig.useFirebase) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return FirestoreInventoryService(userId);
  }
  final service = MockInventoryService();
  ref.onDispose(service.dispose);
  return service;
});

class InventoryListNotifier extends StreamNotifier<List<InventoryItem>> {
  @override
  Stream<List<InventoryItem>> build() {
    return ref.watch(inventoryServiceProvider).watchItems();
  }

  Future<void> addItem(InventoryItem item) async {
    await ref.read(inventoryServiceProvider).addItem(item);
    LogService.instance.info('Inventory item added: ${item.name}');
  }

  Future<void> updateItem(InventoryItem item) async {
    await ref.read(inventoryServiceProvider).updateItem(item);
    LogService.instance.info('Inventory item updated: ${item.id}');
  }

  Future<void> deleteItem(String id) async {
    // Delete associated images from Storage
    final item = await ref.read(inventoryServiceProvider).getItem(id);
    if (item != null && item.imageUrls.isNotEmpty) {
      final uploader = ref.read(imageUploadServiceProvider);
      for (final url in item.imageUrls) {
        await uploader.deleteImage(url);
      }
    }
    await ref.read(inventoryServiceProvider).deleteItem(id);
    LogService.instance.info('Inventory item deleted: $id');
  }

  /// Move [amount] units of quantity from one item to another
  /// (WISH-0083). A negative [amount] reverses the direction. Throws
  /// [ArgumentError] with a user-readable message when the transfer
  /// would push either quantity below zero (also pre-checked by the
  /// dialog; this is the authoritative re-check against fresh data).
  Future<void> transferQuantity({
    required String fromId,
    required String toId,
    required int amount,
  }) async {
    if (fromId == toId) {
      throw ArgumentError('Cannot transfer an item to itself');
    }
    final service = ref.read(inventoryServiceProvider);
    final from = await service.getItem(fromId);
    final to = await service.getItem(toId);
    if (from == null || to == null) {
      throw ArgumentError('One of the items no longer exists');
    }
    final outcome = applyTransfer(
      fromQuantity: from.quantity,
      toQuantity: to.quantity,
      amount: amount,
    );
    await service.updateItem(from.copyWith(quantity: outcome.fromNewQuantity));
    await service.updateItem(to.copyWith(quantity: outcome.toNewQuantity));
    LogService.instance.info(
      'Inventory transfer: $amount from "${from.name}" to "${to.name}" '
      '(${from.quantity}→${outcome.fromNewQuantity}, '
      '${to.quantity}→${outcome.toNewQuantity})',
    );
  }

  /// Split [amount] units off the source item into a brand new item at
  /// [location] (WISH-0088). The new item copies the source's data —
  /// name, description, category, price, dates, barcode, catalog link,
  /// fill percentage, nicknames — but NOT its images: deleting an item
  /// cascade-deletes its Storage images, so two items sharing image
  /// URLs would break each other on delete. Throws [ArgumentError]
  /// with a user-readable message on invalid input.
  Future<void> transferToNewItem({
    required String fromId,
    required String location,
    required int amount,
  }) async {
    final trimmedLocation = location.trim();
    if (trimmedLocation.isEmpty) {
      throw ArgumentError('Enter a location for the new item');
    }
    final service = ref.read(inventoryServiceProvider);
    final from = await service.getItem(fromId);
    if (from == null) {
      throw ArgumentError('The source item no longer exists');
    }
    final error = validateTransferToNew(
      fromQuantity: from.quantity,
      amount: amount,
    );
    if (error != null) throw ArgumentError(error);

    final newItem = InventoryItem(
      name: from.name,
      description: from.description,
      category: from.category,
      location: trimmedLocation,
      quantity: amount,
      purchasePrice: from.purchasePrice,
      purchaseDate: from.purchaseDate,
      expiryDate: from.expiryDate,
      barcode: from.barcode,
      catalogItemId: from.catalogItemId,
      customFields: Map.of(from.customFields),
      fillPercent: from.fillPercent,
      searchAliases: from.searchAliases,
    );
    await service.addItem(newItem);
    await service.updateItem(from.copyWith(quantity: from.quantity - amount));
    LogService.instance.info(
      'Inventory split: $amount of "${from.name}" to new item at '
      '"$trimmedLocation" (${from.quantity}→${from.quantity - amount})',
    );
  }
}

final inventoryListProvider =
    StreamNotifierProvider<InventoryListNotifier, List<InventoryItem>>(
      InventoryListNotifier.new,
    );

final inventorySearchProvider = StateProvider<String>((_) => '');
final inventoryCategoryFilterProvider = StateProvider<String?>((_) => null);
final inventoryLocationFilterProvider = StateProvider<String?>((_) => null);
final inventorySortProvider = StateProvider<InventorySort>(
  (_) => InventorySort.name,
);

final filteredInventoryProvider = Provider<AsyncValue<List<InventoryItem>>>((
  ref,
) {
  final items = ref.watch(inventoryListProvider);
  final search = ref.watch(inventorySearchProvider).toLowerCase();
  final category = ref.watch(inventoryCategoryFilterProvider);
  final location = ref.watch(inventoryLocationFilterProvider);
  final sort = ref.watch(inventorySortProvider);

  return items.whenData((list) {
    var filtered = list;
    if (search.isNotEmpty) {
      filtered = filtered
          .where(
            (i) =>
                i.name.toLowerCase().contains(search) ||
                (i.description?.toLowerCase().contains(search) ?? false) ||
                (i.barcode?.toLowerCase().contains(search) ?? false) ||
                matchesSearchAliases(i.searchAliases, search),
          )
          .toList();
    }
    if (category != null) {
      filtered = filtered.where((i) => i.category == category).toList();
    }
    if (location != null) {
      filtered = filtered.where((i) => i.location == location).toList();
    }
    return sortInventoryItems(filtered, sort);
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
