import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/watch_item.dart';
import 'watchlist_service.dart';

class FirestoreWatchlistService implements WatchlistService {
  final FirebaseFirestore _firestore;
  final String _userId;

  FirestoreWatchlistService(this._userId, {FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_userId).collection('watchlist');

  @override
  Future<List<WatchItem>> getItems() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map((doc) => WatchItem.fromMap(doc.data())).toList()
      ..sort(compareByPriority);
  }

  @override
  Stream<List<WatchItem>> watchItems() {
    return _collection.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => WatchItem.fromMap(doc.data())).toList()
            ..sort(compareByPriority),
    );
  }

  @override
  Future<WatchItem?> getItem(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return WatchItem.fromMap(doc.data()!);
  }

  @override
  Future<void> addItem(WatchItem item) async {
    await _collection.doc(item.id).set(item.toMap());
  }

  @override
  Future<void> updateItem(WatchItem item) async {
    await _collection.doc(item.id).set(item.toMap());
  }

  @override
  Future<void> deleteItem(String id) async {
    await _collection.doc(id).delete();
  }
}
