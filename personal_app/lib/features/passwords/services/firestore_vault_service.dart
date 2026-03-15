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

  @override
  Future<Uint8List?> reEncryptVault(String oldPassword, String newPassword) async {
    final oldKey = await unlockVault(oldPassword);
    if (oldKey == null) return null;

    // Generate new salt & verification hash
    final newSalt = VaultCrypto.generateSalt();
    final newVerificationHash = VaultCrypto.createVerificationHash(newPassword, newSalt);
    final newKey = VaultCrypto.deriveKey(newPassword, newSalt);

    // Re-encrypt all entries
    final entries = await getEntries();
    final batch = _firestore.batch();

    for (final entry in entries) {
      final plainPassword = VaultCrypto.decryptField(entry.encryptedPassword, oldKey);
      final newEncPassword = VaultCrypto.encryptField(plainPassword, newKey);
      String? newEncNotes;
      if (entry.encryptedNotes != null) {
        final plainNotes = VaultCrypto.decryptField(entry.encryptedNotes!, oldKey);
        newEncNotes = VaultCrypto.encryptField(plainNotes, newKey);
      }
      final reEncrypted = PasswordEntry(
        id: entry.id,
        title: entry.title,
        username: entry.username,
        encryptedPassword: newEncPassword,
        url: entry.url,
        encryptedNotes: newEncNotes,
        category: entry.category,
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
      );
      batch.set(_entries.doc(entry.id), reEncrypted.toMap());
    }

    // Update vault config
    batch.set(_vaultDoc, {
      'salt': newSalt,
      'verificationHash': newVerificationHash,
    });

    await batch.commit();
    return newKey;
  }
}
