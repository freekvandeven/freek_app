import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/file_entry.dart';
import 'file_service.dart';

class FirestoreFileService implements FileService {
  final FirebaseFirestore _firestore;
  final String _userId;

  FirestoreFileService(this._userId, {FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_userId).collection('files');

  @override
  Future<List<FileEntry>> getEntries() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map((doc) => FileEntry.fromMap(doc.data())).toList();
  }

  @override
  Stream<List<FileEntry>> watchEntries() {
    return _collection.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => FileEntry.fromMap(doc.data())).toList(),
    );
  }

  @override
  Future<FileEntry?> getEntry(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return FileEntry.fromMap(doc.data()!);
  }

  @override
  Future<void> addEntry(FileEntry entry) async {
    await _collection.doc(entry.id).set(entry.toMap());
  }

  @override
  Future<void> updateEntry(FileEntry entry) async {
    await _collection.doc(entry.id).set(entry.toMap());
  }

  @override
  Future<void> deleteEntry(String id) async {
    await _collection.doc(id).delete();
  }
}
