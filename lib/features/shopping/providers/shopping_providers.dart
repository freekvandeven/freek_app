import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../services/log_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/shopping_item.dart';
import '../services/firestore_shopping_service.dart';
import '../services/shopping_service.dart';

final shoppingServiceProvider = Provider<ShoppingService>((ref) {
  if (AppConfig.useFirebase) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return FirestoreShoppingService(userId);
  }
  final service = MockShoppingService();
  ref.onDispose(service.dispose);
  return service;
});

class ShoppingListNotifier extends StreamNotifier<List<ShoppingItem>> {
  @override
  Stream<List<ShoppingItem>> build() {
    return ref.watch(shoppingServiceProvider).watchItems();
  }

  Future<void> addItem(ShoppingItem item) async {
    await ref.read(shoppingServiceProvider).addItem(item);
    LogService.instance.info('Shopping item added: ${item.title}');
  }

  Future<void> updateItem(ShoppingItem item) async {
    await ref.read(shoppingServiceProvider).updateItem(item);
  }

  Future<void> deleteItem(String id) async {
    await ref.read(shoppingServiceProvider).deleteItem(id);
    LogService.instance.info('Shopping item deleted: $id');
  }

  Future<void> toggleItem(String id) async {
    final service = ref.read(shoppingServiceProvider);
    final item = await service.getItem(id);
    if (item != null) {
      await service.updateItem(item.copyWith(isCompleted: !item.isCompleted));
    }
  }

  Future<void> clearCompleted() async {
    final items = await ref.read(shoppingServiceProvider).getItems();
    for (final item in items.where((i) => i.isCompleted)) {
      await ref.read(shoppingServiceProvider).deleteItem(item.id);
    }
  }
}

final shoppingListProvider =
    StreamNotifierProvider<ShoppingListNotifier, List<ShoppingItem>>(
      ShoppingListNotifier.new,
    );

final shoppingSearchProvider = StateProvider<String>((_) => '');
final shoppingWipOnlyProvider = StateProvider<bool>((_) => false);

final filteredShoppingProvider = Provider<AsyncValue<List<ShoppingItem>>>((
  ref,
) {
  final items = ref.watch(shoppingListProvider);
  final search = ref.watch(shoppingSearchProvider).toLowerCase();
  final wipOnly = ref.watch(shoppingWipOnlyProvider);

  return items.whenData((list) {
    var filtered = list;
    if (search.isNotEmpty) {
      filtered = filtered
          .where(
            (i) =>
                i.title.toLowerCase().contains(search) ||
                (i.description?.toLowerCase().contains(search) ?? false),
          )
          .toList();
    }
    if (wipOnly) {
      filtered = filtered.where((i) => i.isWip).toList();
    }
    return filtered;
  });
});
