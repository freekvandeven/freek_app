import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/password_entry.dart';
import 'vault_crypto.dart';
import 'vault_service.dart';

class FirestoreVaultService implements VaultService {
  final FirebaseFirestore _firestore;
  final String _userId;

  FirestoreVaultService(this._userId, {FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _vaultDoc =>
      _firestore.collection('users').doc(_userId).collection('vault').doc('config');

  CollectionReference<Map<String, dynamic>> get _entries =>
      _firestore.collection('users').doc(_userId).collection('vault_entries');

  @override
  Future<bool> isVaultSetup() async {
    final doc = await _vaultDoc.get();
    return doc.exists && doc.data()?['salt'] != null;
  }

  @override
  Future<void> setupVault(String masterPassword) async {
    final salt = VaultCrypto.generateSalt();
    final verificationHash = VaultCrypto.createVerificationHash(
      masterPassword,
      salt,
    );
    await _vaultDoc.set({
      'salt': salt,
      'verificationHash': verificationHash,
    });
  }

  @override
  Future<Uint8List?> unlockVault(String masterPassword) async {
    final doc = await _vaultDoc.get();
    if (!doc.exists || doc.data() == null) return null;

    final salt = doc.data()!['salt'] as String?;
    final storedHash = doc.data()!['verificationHash'] as String?;
    if (salt == null || storedHash == null) return null;

    if (!VaultCrypto.verifyMasterPassword(masterPassword, salt, storedHash)) {
      return null;
    }

    return VaultCrypto.deriveKey(masterPassword, salt);
  }

  @override
  Future<List<PasswordEntry>> getEntries() async {
    final snapshot = await _entries.get();
    return snapshot.docs
        .map((doc) => PasswordEntry.fromMap(doc.data()))
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  @override
  Future<void> addEntry(PasswordEntry entry) async {
    await _entries.doc(entry.id).set(entry.toMap());
  }

  @override
  Future<void> updateEntry(PasswordEntry entry) async {
    await _entries.doc(entry.id).set(entry.toMap());
  }

  @override
  Future<void> deleteEntry(String id) async {
    await _entries.doc(id).delete();
  }
}
