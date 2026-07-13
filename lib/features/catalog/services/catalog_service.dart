import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/catalog_item.dart';

abstract class CatalogService {
  Future<List<CatalogItem>> getItems();

  /// Emits the full item list on listen and again after every change,
  /// so consumers never need to re-fetch after a mutation.
  Stream<List<CatalogItem>> watchItems();
  Future<CatalogItem?> getItem(String id);
  Future<void> addItem(CatalogItem item);
  Future<void> updateItem(CatalogItem item);
  Future<void> deleteItem(String id);
}

class MockCatalogService implements CatalogService {
  static const _itemsKey = 'catalog_items';
  final _prefs = SharedPreferencesAsync();
  final _changes = StreamController<List<CatalogItem>>.broadcast();

  @override
  Stream<List<CatalogItem>> watchItems() async* {
    yield await getItems();
    yield* _changes.stream;
  }

  @override
  Future<List<CatalogItem>> getItems() async {
    final data = await _prefs.getString(_itemsKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list
        .map((e) => CatalogItem.fromMap(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  @override
  Future<CatalogItem?> getItem(String id) async {
    final items = await getItems();
    try {
      return items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addItem(CatalogItem item) async {
    final items = await getItems();
    items.add(item);
    await _saveItems(items);
  }

  @override
  Future<void> updateItem(CatalogItem item) async {
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

  Future<void> _saveItems(List<CatalogItem> items) async {
    await _prefs.setString(
      _itemsKey,
      jsonEncode(items.map((e) => e.toMap()).toList()),
    );
    _changes.add(List.of(items)..sort((a, b) => a.title.compareTo(b.title)));
  }

  void dispose() {
    _changes.close();
  }
}
