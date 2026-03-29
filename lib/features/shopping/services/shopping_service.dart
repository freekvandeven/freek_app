import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/shopping_item.dart';

abstract class ShoppingService {
  Future<List<ShoppingItem>> getItems();
  Future<ShoppingItem?> getItem(String id);
  Future<void> addItem(ShoppingItem item);
  Future<void> updateItem(ShoppingItem item);
  Future<void> deleteItem(String id);
}

class MockShoppingService implements ShoppingService {
  static const _itemsKey = 'shopping_items';
  final _prefs = SharedPreferencesAsync();

  @override
  Future<List<ShoppingItem>> getItems() async {
    final data = await _prefs.getString(_itemsKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list
        .map((e) => ShoppingItem.fromMap(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return a.createdAt.compareTo(b.createdAt);
      });
  }

  @override
  Future<ShoppingItem?> getItem(String id) async {
    final items = await getItems();
    try {
      return items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addItem(ShoppingItem item) async {
    final items = await getItems();
    items.add(item);
    await _saveItems(items);
  }

  @override
  Future<void> updateItem(ShoppingItem item) async {
    final items = await getItems();
    final index = items.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      items[index] = item;
      await _saveItems(items);
    }
  }

  @override
  Future<void> deleteItem(String id) async {
    final items = await getItems();
    items.removeWhere((i) => i.id == id);
    await _saveItems(items);
  }

  Future<void> _saveItems(List<ShoppingItem> items) async {
    await _prefs.setString(
      _itemsKey,
      jsonEncode(items.map((e) => e.toMap()).toList()),
    );
  }
}
