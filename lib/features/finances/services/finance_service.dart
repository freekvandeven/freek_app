import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/finance_models.dart';

abstract class FinanceService {
  Future<List<FinancialTransaction>> getTransactions();

  /// Emits the full transaction list on listen and again after every change
  /// (IMPR-0018). Same contract for [watchCategories] and [watchAssets].
  Stream<List<FinancialTransaction>> watchTransactions();
  Future<FinancialTransaction?> getTransaction(String id);
  Future<void> addTransaction(FinancialTransaction transaction);
  Future<void> updateTransaction(FinancialTransaction transaction);
  Future<void> deleteTransaction(String id);

  Future<List<FinancialCategory>> getCategories();
  Stream<List<FinancialCategory>> watchCategories();
  Future<void> addCategory(FinancialCategory category);
  Future<void> updateCategory(FinancialCategory category);
  Future<void> deleteCategory(String id);

  Future<List<FinancialAsset>> getAssets();
  Stream<List<FinancialAsset>> watchAssets();
  Future<FinancialAsset?> getAsset(String id);
  Future<void> addAsset(FinancialAsset asset);
  Future<void> updateAsset(FinancialAsset asset);
  Future<void> deleteAsset(String id);
}

class MockFinanceService implements FinanceService {
  static const _transactionsKey = 'finance_transactions';
  static const _categoriesKey = 'finance_categories';
  static const _assetsKey = 'finance_assets';

  final _prefs = SharedPreferencesAsync();
  final _transactionChanges =
      StreamController<List<FinancialTransaction>>.broadcast();
  final _categoryChanges =
      StreamController<List<FinancialCategory>>.broadcast();
  final _assetChanges = StreamController<List<FinancialAsset>>.broadcast();

  @override
  Stream<List<FinancialTransaction>> watchTransactions() async* {
    yield await getTransactions();
    yield* _transactionChanges.stream;
  }

  @override
  Stream<List<FinancialCategory>> watchCategories() async* {
    yield await getCategories();
    yield* _categoryChanges.stream;
  }

  @override
  Stream<List<FinancialAsset>> watchAssets() async* {
    yield await getAssets();
    yield* _assetChanges.stream;
  }

  @override
  Future<List<FinancialTransaction>> getTransactions() async {
    final data = await _prefs.getString(_transactionsKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list
        .map((e) => FinancialTransaction.fromMap(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<FinancialTransaction?> getTransaction(String id) async {
    final transactions = await getTransactions();
    try {
      return transactions.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addTransaction(FinancialTransaction transaction) async {
    final transactions = await getTransactions();
    transactions.add(transaction);
    await _saveTransactions(transactions);
  }

  @override
  Future<void> updateTransaction(FinancialTransaction transaction) async {
    final transactions = await getTransactions();
    final index = transactions.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      transactions[index] = transaction;
      await _saveTransactions(transactions);
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    final transactions = await getTransactions();
    transactions.removeWhere((t) => t.id == id);
    await _saveTransactions(transactions);
  }

  Future<void> _saveTransactions(
    List<FinancialTransaction> transactions,
  ) async {
    await _prefs.setString(
      _transactionsKey,
      jsonEncode(transactions.map((t) => t.toMap()).toList()),
    );
    _transactionChanges.add(
      List.of(transactions)..sort((a, b) => b.date.compareTo(a.date)),
    );
  }

  @override
  Future<List<FinancialCategory>> getCategories() async {
    final data = await _prefs.getString(_categoriesKey);
    if (data == null) {
      // Seed with defaults
      final defaults = [
        ...defaultExpenseCategories,
        ...defaultIncomeCategories,
      ];
      await _saveCategories(defaults);
      return defaults;
    }
    final list = jsonDecode(data) as List;
    return list
        .map((e) => FinancialCategory.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> addCategory(FinancialCategory category) async {
    final categories = await getCategories();
    categories.add(category);
    await _saveCategories(categories);
  }

  @override
  Future<void> updateCategory(FinancialCategory category) async {
    final categories = await getCategories();
    final index = categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      categories[index] = category;
      await _saveCategories(categories);
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    final categories = await getCategories();
    categories.removeWhere((c) => c.id == id);
    await _saveCategories(categories);
  }

  Future<void> _saveCategories(List<FinancialCategory> categories) async {
    await _prefs.setString(
      _categoriesKey,
      jsonEncode(categories.map((c) => c.toMap()).toList()),
    );
    _categoryChanges.add(List.of(categories));
  }

  @override
  Future<List<FinancialAsset>> getAssets() async {
    final data = await _prefs.getString(_assetsKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list
        .map((e) => FinancialAsset.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<FinancialAsset?> getAsset(String id) async {
    final assets = await getAssets();
    try {
      return assets.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addAsset(FinancialAsset asset) async {
    final assets = await getAssets();
    assets.add(asset);
    await _saveAssets(assets);
  }

  @override
  Future<void> updateAsset(FinancialAsset asset) async {
    final assets = await getAssets();
    final index = assets.indexWhere((a) => a.id == asset.id);
    if (index != -1) {
      assets[index] = asset;
      await _saveAssets(assets);
    }
  }

  @override
  Future<void> deleteAsset(String id) async {
    final assets = await getAssets();
    assets.removeWhere((a) => a.id == id);
    await _saveAssets(assets);
  }

  Future<void> _saveAssets(List<FinancialAsset> assets) async {
    await _prefs.setString(
      _assetsKey,
      jsonEncode(assets.map((a) => a.toMap()).toList()),
    );
    _assetChanges.add(List.of(assets));
  }

  void dispose() {
    _transactionChanges.close();
    _categoryChanges.close();
    _assetChanges.close();
  }
}
