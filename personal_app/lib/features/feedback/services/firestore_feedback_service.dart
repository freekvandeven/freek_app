import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/feedback_entry.dart';
import 'feedback_service.dart';

class FirestoreFeedbackService implements FeedbackService {
  final FirebaseFirestore _firestore;
  final String _userId;

  FirestoreFeedbackService(this._userId, {FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('feedback');

  @override
  Future<List<FeedbackEntry>> getEntries() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => FeedbackEntry.fromMap(doc.data()))
        .where((e) => !e.isPrivate || e.userId == _userId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<FeedbackEntry?> getEntry(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    final entry = FeedbackEntry.fromMap(doc.data()!);
    if (entry.isPrivate && entry.userId != _userId) return null;
    return entry;
  }

  @override
  Future<void> addEntry(FeedbackEntry entry) async {
    await _collection.doc(entry.id).set(entry.toMap());
  }

  @override
  Future<void> updateEntry(FeedbackEntry entry) async {
    await _collection.doc(entry.id).set(entry.toMap());
  }

  @override
  Future<void> deleteEntry(String id) async {
    await _collection.doc(id).delete();
  }
}
