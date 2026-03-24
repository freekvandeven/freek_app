import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/knowledge_page.dart';
import 'knowledge_service.dart';

class FirestoreKnowledgeService implements KnowledgeService {
  final FirebaseFirestore _firestore;
  final String _userId;

  FirestoreKnowledgeService(this._userId, {FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_userId).collection('knowledge');

  @override
  Future<List<KnowledgePage>> getPages() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => KnowledgePage.fromMap(doc.data()))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<KnowledgePage?> getPage(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return KnowledgePage.fromMap(doc.data()!);
  }

  @override
  Future<void> addPage(KnowledgePage page) async {
    await _collection.doc(page.id).set(page.toMap());
  }

  @override
  Future<void> updatePage(KnowledgePage page) async {
    await _collection.doc(page.id).set(page.toMap());
  }

  @override
  Future<void> deletePage(String id) async {
    // Reparent children to root
    final snapshot = await _collection.where('parentId', isEqualTo: id).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'parentId': null});
    }
    batch.delete(_collection.doc(id));
    await batch.commit();
  }
}
