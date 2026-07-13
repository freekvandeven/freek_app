import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/catalog_item.dart';
import 'catalog_service.dart';

class FirestoreCatalogService implements CatalogService {
  final FirebaseFirestore _firestore;
  final String _userId;

  FirestoreCatalogService(this._userId, {FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_userId).collection('catalog');

  @override
  Future<List<CatalogItem>> getItems() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map((doc) => CatalogItem.fromMap(doc.data())).toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  @override
  Stream<List<CatalogItem>> watchItems() {
    return _collection.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => CatalogItem.fromMap(doc.data())).toList()
            ..sort((a, b) => a.title.compareTo(b.title)),
    );
  }

  @override
  Future<CatalogItem?> getItem(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return CatalogItem.fromMap(doc.data()!);
  }

  @override
  Future<void> addItem(CatalogItem item) async {
    await _collection.doc(item.id).set(item.toMap());
  }

  @override
  Future<void> updateItem(CatalogItem item) async {
    await _collection.doc(item.id).set(item.toMap());
  }

  @override
  Future<void> deleteItem(String id) async {
    await _collection.doc(id).delete();
  }
}
