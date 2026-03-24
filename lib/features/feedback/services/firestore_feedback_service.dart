import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/feedback_entry.dart';
import 'feedback_service.dart';

class FirestoreFeedbackService implements FeedbackService {
  final FirebaseFirestore _firestore;
  final String _userId;

  FirestoreFeedbackService(this._userId, {FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Public feedback shared across all users.
  CollectionReference<Map<String, dynamic>> get _publicCollection =>
      _firestore.collection('feedback');

  /// Private feedback scoped to the current user.
  CollectionReference<Map<String, dynamic>> get _privateCollection =>
      _firestore.collection('users').doc(_userId).collection('feedback');

  CollectionReference<Map<String, dynamic>> _collectionFor(
    FeedbackEntry entry,
  ) => entry.isPrivate ? _privateCollection : _publicCollection;

  @override
  Future<List<FeedbackEntry>> getEntries() async {
    final results = await Future.wait([
      _publicCollection.get(),
      _privateCollection.get(),
    ]);
    final entries = [
      ...results[0].docs.map((d) => FeedbackEntry.fromMap(d.data())),
      ...results[1].docs.map((d) => FeedbackEntry.fromMap(d.data())),
    ];
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  @override
  Future<FeedbackEntry?> getEntry(String id) async {
    // Try public first, then private.
    var doc = await _publicCollection.doc(id).get();
    if (doc.exists && doc.data() != null) {
      return FeedbackEntry.fromMap(doc.data()!);
    }
    doc = await _privateCollection.doc(id).get();
    if (doc.exists && doc.data() != null) {
      return FeedbackEntry.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Future<void> addEntry(FeedbackEntry entry) async {
    await _collectionFor(entry).doc(entry.id).set(entry.toMap());
  }

  @override
  Future<void> updateEntry(FeedbackEntry entry) async {
    final target = _collectionFor(entry);
    final opposite = entry.isPrivate ? _publicCollection : _privateCollection;
    await Future.wait([
      target.doc(entry.id).set(entry.toMap()),
      opposite.doc(entry.id).delete(),
    ]);
  }

  @override
  Future<void> deleteEntry(String id) async {
    // Delete from whichever collection it exists in.
    await Future.wait([
      _publicCollection.doc(id).delete(),
      _privateCollection.doc(id).delete(),
    ]);
  }
}
