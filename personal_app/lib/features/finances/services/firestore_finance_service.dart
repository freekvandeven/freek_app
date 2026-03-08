import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/finance_models.dart';
import 'finance_service.dart';

class FirestoreFinanceService implements FinanceService {
  final FirebaseFirestore _firestore;
  final String _userId;

  FirestoreFinanceService(this._userId, {FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _firestore.collection('users').doc(_userId).collection('transactions');

  CollectionReference<Map<String, dynamic>> get _categories =>
      _firestore.collection('users').doc(_userId).collection('categories');

  CollectionReference<Map<String, dynamic>> get _assets =>
      _firestore.collection('users').doc(_userId).collection('assets');

  // === Transactions ===

  @override
  Future<List<FinancialTransaction>> getTransactions() async {
    final snapshot = await _transactions.get();
    return snapshot.docs
        .map((doc) => FinancialTransaction.fromMap(doc.data()))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<FinancialTransaction?> getTransaction(String id) async {
    final doc = await _transactions.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return FinancialTransaction.fromMap(doc.data()!);
  }

  @override
  Future<void> addTransaction(FinancialTransaction transaction) async {
    await _transactions.doc(transaction.id).set(transaction.toMap());
  }

  @override
  Future<void> updateTransaction(FinancialTransaction transaction) async {
    await _transactions.doc(transaction.id).set(transaction.toMap());
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _transactions.doc(id).delete();
  }

  // === Categories ===

  @override
  Future<List<FinancialCategory>> getCategories() async {
    final snapshot = await _categories.get();
    if (snapshot.docs.isEmpty) {
      final defaults = [
        ...defaultExpenseCategories,
        ...defaultIncomeCategories,
      ];
      for (final cat in defaults) {
        await _categories.doc(cat.id).set(cat.toMap());
      }
      return defaults;
    }
    return snapshot.docs
        .map((doc) => FinancialCategory.fromMap(doc.data()))
        .toList();
  }

  @override
  Future<void> addCategory(FinancialCategory category) async {
    await _categories.doc(category.id).set(category.toMap());
  }

  @override
  Future<void> updateCategory(FinancialCategory category) async {
    await _categories.doc(category.id).set(category.toMap());
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _categories.doc(id).delete();
  }

  // === Assets ===

  @override
  Future<List<FinancialAsset>> getAssets() async {
    final snapshot = await _assets.get();
    return snapshot.docs
        .map((doc) => FinancialAsset.fromMap(doc.data()))
        .toList();
  }

  @override
  Future<FinancialAsset?> getAsset(String id) async {
    final doc = await _assets.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return FinancialAsset.fromMap(doc.data()!);
  }

  @override
  Future<void> addAsset(FinancialAsset asset) async {
    await _assets.doc(asset.id).set(asset.toMap());
  }

  @override
  Future<void> updateAsset(FinancialAsset asset) async {
    await _assets.doc(asset.id).set(asset.toMap());
  }

  @override
  Future<void> deleteAsset(String id) async {
    await _assets.doc(id).delete();
  }
}
