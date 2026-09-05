import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/watch_item.dart';

/// Sorts by manual priority first, then title, so the order is stable
/// when several entries share a [WatchItem.sortOrder] (they all do until
/// the list has been reordered once).
int compareByPriority(WatchItem a, WatchItem b) {
  final byOrder = a.sortOrder.compareTo(b.sortOrder);
  return byOrder != 0 ? byOrder : a.title.compareTo(b.title);
}

abstract class WatchlistService {
  Future<List<WatchItem>> getItems();

  /// Emits the full item list on listen and again after every change,
  /// so consumers never need to re-fetch after a mutation.
  Stream<List<WatchItem>> watchItems();
  Future<WatchItem?> getItem(String id);
  Future<void> addItem(WatchItem item);
  Future<void> updateItem(WatchItem item);
  Future<void> deleteItem(String id);
}

class MockWatchlistService implements WatchlistService {
  static const _itemsKey = 'watchlist_items';
  final _prefs = SharedPreferencesAsync();
  final _changes = StreamController<List<WatchItem>>.broadcast();

  @override
  Stream<List<WatchItem>> watchItems() async* {
    yield await getItems();
    yield* _changes.stream;
  }

  @override
  Future<List<WatchItem>> getItems() async {
    final data = await _prefs.getString(_itemsKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list
        .map((e) => WatchItem.fromMap(e as Map<String, dynamic>))
        .toList()
      ..sort(compareByPriority);
  }

  @override
  Future<WatchItem?> getItem(String id) async {
    final items = await getItems();
    try {
      return items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addItem(WatchItem item) async {
    final items = await getItems();
    items.add(item);
    await _saveItems(items);
  }

  @override
  Future<void> updateItem(WatchItem item) async {
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

  Future<void> _saveItems(List<WatchItem> items) async {
    await _prefs.setString(
      _itemsKey,
      jsonEncode(items.map((e) => e.toMap()).toList()),
    );
    _changes.add(List.of(items)..sort(compareByPriority));
  }

  void dispose() {
    _changes.close();
  }
}
