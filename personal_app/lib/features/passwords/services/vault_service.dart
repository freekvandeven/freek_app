import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/password_entry.dart';
import 'vault_crypto.dart';

abstract class VaultService {
  Future<bool> isVaultSetup();
  Future<void> setupVault(String masterPassword);
  Future<Uint8List?> unlockVault(String masterPassword);
  Future<List<PasswordEntry>> getEntries();
  Future<void> addEntry(PasswordEntry entry);
  Future<void> updateEntry(PasswordEntry entry);
  Future<void> deleteEntry(String id);
}

class MockVaultService implements VaultService {
  static const _saltKey = 'vault_salt';
  static const _verificationKey = 'vault_verification_hash';
  static const _entriesKey = 'vault_entries';

  final _prefs = SharedPreferencesAsync();

  @override
  Future<bool> isVaultSetup() async {
    final salt = await _prefs.getString(_saltKey);
    return salt != null;
  }

  @override
  Future<void> setupVault(String masterPassword) async {
    final salt = VaultCrypto.generateSalt();
    final verificationHash = VaultCrypto.createVerificationHash(
      masterPassword,
      salt,
    );
    await _prefs.setString(_saltKey, salt);
    await _prefs.setString(_verificationKey, verificationHash);
  }

  @override
  Future<Uint8List?> unlockVault(String masterPassword) async {
    final salt = await _prefs.getString(_saltKey);
    final storedHash = await _prefs.getString(_verificationKey);
    if (salt == null || storedHash == null) return null;

    if (!VaultCrypto.verifyMasterPassword(masterPassword, salt, storedHash)) {
      return null;
    }

    return VaultCrypto.deriveKey(masterPassword, salt);
  }

  @override
  Future<List<PasswordEntry>> getEntries() async {
    final data = await _prefs.getString(_entriesKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list
        .map((e) => PasswordEntry.fromMap(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  @override
  Future<void> addEntry(PasswordEntry entry) async {
    final entries = await getEntries();
    entries.add(entry);
    await _saveEntries(entries);
  }

  @override
  Future<void> updateEntry(PasswordEntry entry) async {
    final entries = await getEntries();
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      entries[index] = entry;
      await _saveEntries(entries);
    }
  }

  @override
  Future<void> deleteEntry(String id) async {
    final entries = await getEntries();
    entries.removeWhere((e) => e.id == id);
    await _saveEntries(entries);
  }

  Future<void> _saveEntries(List<PasswordEntry> entries) async {
    await _prefs.setString(
      _entriesKey,
      jsonEncode(entries.map((e) => e.toMap()).toList()),
    );
  }
}
