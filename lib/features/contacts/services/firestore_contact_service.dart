import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/contact.dart';
import 'contact_service.dart';

class FirestoreContactService implements ContactService {
  final FirebaseFirestore _firestore;
  final String _userId;

  FirestoreContactService(this._userId, {FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_userId).collection('contacts');

  @override
  Future<List<Contact>> getContacts() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map((doc) => Contact.fromMap(doc.data())).toList();
  }

  @override
  Future<Contact?> getContact(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Contact.fromMap(doc.data()!);
  }

  @override
  Future<void> addContact(Contact contact) async {
    await _collection.doc(contact.id).set(contact.toMap());
  }

  @override
  Future<void> updateContact(Contact contact) async {
    await _collection.doc(contact.id).set(contact.toMap());
  }

  @override
  Future<void> deleteContact(String id) async {
    await _collection.doc(id).delete();
  }
}
