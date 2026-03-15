import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/conversation_topic.dart';
import 'conversation_service.dart';

class FirestoreConversationService implements ConversationService {
  final FirebaseFirestore _firestore;
  final String _userId;

  FirestoreConversationService(this._userId, {FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_userId).collection('conversations');

  @override
  Future<List<ConversationTopic>> getTopics() async {
    final snapshot = await _collection.get();
    final topics = snapshot.docs
        .map((d) => ConversationTopic.fromMap(d.data()))
        .toList();
    topics.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return topics;
  }

  @override
  Future<ConversationTopic?> getTopic(String id) async {
    final doc = await _collection.doc(id).get();
    if (doc.exists && doc.data() != null) {
      return ConversationTopic.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Future<void> addTopic(ConversationTopic topic) async {
    await _collection.doc(topic.id).set(topic.toMap());
  }

  @override
  Future<void> updateTopic(ConversationTopic topic) async {
    await _collection.doc(topic.id).set(topic.toMap());
  }

  @override
  Future<void> deleteTopic(String id) async {
    await _collection.doc(id).delete();
  }
}
