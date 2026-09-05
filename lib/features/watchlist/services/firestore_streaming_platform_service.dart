import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/streaming_platform.dart';
import 'streaming_platform_service.dart';

class FirestoreStreamingPlatformService implements StreamingPlatformService {
  final FirebaseFirestore _firestore;
  final String _userId;

  FirestoreStreamingPlatformService(
    this._userId, {
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('users')
      .doc(_userId)
      .collection('streamingPlatforms');

  @override
  Future<List<StreamingPlatform>> getPlatforms() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => StreamingPlatform.fromMap(doc.data()))
        .toList()
      ..sort(compareByName);
  }

  @override
  Stream<List<StreamingPlatform>> watchPlatforms() {
    return _collection.snapshots().map(
      (snapshot) =>
          snapshot.docs
              .map((doc) => StreamingPlatform.fromMap(doc.data()))
              .toList()
            ..sort(compareByName),
    );
  }

  @override
  Future<StreamingPlatform?> getPlatform(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return StreamingPlatform.fromMap(doc.data()!);
  }

  @override
  Future<void> addPlatform(StreamingPlatform platform) async {
    await _collection.doc(platform.id).set(platform.toMap());
  }

  @override
  Future<void> updatePlatform(StreamingPlatform platform) async {
    await _collection.doc(platform.id).set(platform.toMap());
  }

  @override
  Future<void> deletePlatform(String id) async {
    await _collection.doc(id).delete();
  }
}
