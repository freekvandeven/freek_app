import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shopping_item.dart';
import 'shopping_service.dart';

class FirestoreShoppingService implements ShoppingService {
  final FirebaseFirestore _firestore;
  final String _userId;

  FirestoreShoppingService(this._userId, {FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_userId).collection('shopping');

  @override
  Future<List<ShoppingItem>> getItems() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map((doc) => ShoppingItem.fromMap(doc.data())).toList()
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return a.createdAt.compareTo(b.createdAt);
      });
  }

  @override
  Future<ShoppingItem?> getItem(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return ShoppingItem.fromMap(doc.data()!);
  }

  @override
  Future<void> addItem(ShoppingItem item) async {
    await _collection.doc(item.id).set(item.toMap());
  }

  @override
  Future<void> updateItem(ShoppingItem item) async {
    await _collection.doc(item.id).set(item.toMap());
  }

  @override
  Future<void> deleteItem(String id) async {
    await _collection.doc(id).delete();
  }
}
