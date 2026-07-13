import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/inventory_item.dart';

abstract class InventoryService {
  Future<List<InventoryItem>> getItems();

  /// Emits the full item list on listen and again after every change,
  /// so consumers never need to re-fetch after a mutation.
  Stream<List<InventoryItem>> watchItems();
  Future<InventoryItem?> getItem(String id);
  Future<void> addItem(InventoryItem item);
  Future<void> updateItem(InventoryItem item);
  Future<void> deleteItem(String id);
}

class MockInventoryService implements InventoryService {
  static const _itemsKey = 'inventory_items';
  final _prefs = SharedPreferencesAsync();
  final _changes = StreamController<List<InventoryItem>>.broadcast();

  @override
  Future<List<InventoryItem>> getItems() async {
    final data = await _prefs.getString(_itemsKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list
        .map((e) => InventoryItem.fromMap(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Stream<List<InventoryItem>> watchItems() async* {
    yield await getItems();
    yield* _changes.stream;
  }

  @override
  Future<InventoryItem?> getItem(String id) async {
    final items = await getItems();
    try {
      return items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addItem(InventoryItem item) async {
    final items = await getItems();
    items.add(item);
    await _saveItems(items);
  }

  @override
  Future<void> updateItem(InventoryItem item) async {
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

  Future<void> _saveItems(List<InventoryItem> items) async {
    await _prefs.setString(
      _itemsKey,
      jsonEncode(items.map((i) => i.toMap()).toList()),
    );
    _changes.add(List.of(items)..sort((a, b) => a.name.compareTo(b.name)));
  }

  void dispose() {
    _changes.close();
  }
}
