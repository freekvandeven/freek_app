import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/inventory_item.dart';
import 'inventory_service.dart';

class FirestoreInventoryService implements InventoryService {
  final FirebaseFirestore _firestore;
  final String _userId;

  FirestoreInventoryService(this._userId, {FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_userId).collection('inventory');

  @override
  Future<List<InventoryItem>> getItems() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => InventoryItem.fromMap(doc.data()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Stream<List<InventoryItem>> watchItems() {
    return _collection.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => InventoryItem.fromMap(doc.data())).toList()
            ..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  @override
  Future<InventoryItem?> getItem(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return InventoryItem.fromMap(doc.data()!);
  }

  @override
  Future<void> addItem(InventoryItem item) async {
    await _collection.doc(item.id).set(item.toMap());
  }

  @override
  Future<void> updateItem(InventoryItem item) async {
    await _collection.doc(item.id).set(item.toMap());
  }

  @override
  Future<void> deleteItem(String id) async {
    await _collection.doc(id).delete();
  }
}
