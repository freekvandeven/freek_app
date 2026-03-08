import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/password_entry.dart';
import '../services/vault_crypto.dart';
import '../services/vault_service.dart';

final vaultServiceProvider = Provider<VaultService>((_) => MockVaultService());

final vaultSetupProvider = FutureProvider<bool>((ref) {
  return ref.read(vaultServiceProvider).isVaultSetup();
});

/// Holds the derived encryption key in memory while the vault is unlocked.
/// Set to null when locked (or when navigating away).
final vaultKeyProvider = StateProvider<Uint8List?>((_) => null);

final vaultLockedProvider = Provider<bool>((ref) {
  return ref.watch(vaultKeyProvider) == null;
});

class VaultEntriesNotifier extends AsyncNotifier<List<DecryptedPasswordEntry>> {
  @override
  Future<List<DecryptedPasswordEntry>> build() async {
    final key = ref.watch(vaultKeyProvider);
    if (key == null) return [];

    final entries = await ref.read(vaultServiceProvider).getEntries();
    return entries.map((entry) {
      try {
        final password = VaultCrypto.decryptField(entry.encryptedPassword, key);
        final notes = entry.encryptedNotes != null
            ? VaultCrypto.decryptField(entry.encryptedNotes!, key)
            : null;
        return DecryptedPasswordEntry(
          entry: entry,
          password: password,
          notes: notes,
        );
      } catch (_) {
        return DecryptedPasswordEntry(
          entry: entry,
          password: '*** decryption failed ***',
        );
      }
    }).toList();
  }

  Future<void> addEntry({
    required String title,
    String? username,
    required String password,
    String? url,
    String? notes,
    String? category,
  }) async {
    final key = ref.read(vaultKeyProvider);
    if (key == null) return;

    final encryptedPassword = VaultCrypto.encryptField(password, key);
    final encryptedNotes = notes != null && notes.isNotEmpty
        ? VaultCrypto.encryptField(notes, key)
        : null;

    final entry = PasswordEntry(
      title: title,
      username: username,
      encryptedPassword: encryptedPassword,
      url: url,
      encryptedNotes: encryptedNotes,
      category: category,
    );

    await ref.read(vaultServiceProvider).addEntry(entry);
    ref.invalidateSelf();
  }

  Future<void> updateEntry({
    required String id,
    required String title,
    String? username,
    required String password,
    String? url,
    String? notes,
    String? category,
  }) async {
    final key = ref.read(vaultKeyProvider);
    if (key == null) return;

    final encryptedPassword = VaultCrypto.encryptField(password, key);
    final encryptedNotes = notes != null && notes.isNotEmpty
        ? VaultCrypto.encryptField(notes, key)
        : null;

    final entry = PasswordEntry(
      id: id,
      title: title,
      username: username,
      encryptedPassword: encryptedPassword,
      url: url,
      encryptedNotes: encryptedNotes,
      category: category,
    );

    await ref.read(vaultServiceProvider).updateEntry(entry);
    ref.invalidateSelf();
  }

  Future<void> deleteEntry(String id) async {
    await ref.read(vaultServiceProvider).deleteEntry(id);
    ref.invalidateSelf();
  }
}

final vaultEntriesProvider =
    AsyncNotifierProvider<VaultEntriesNotifier, List<DecryptedPasswordEntry>>(
      VaultEntriesNotifier.new,
    );

final vaultSearchProvider = StateProvider<String>((_) => '');
final vaultCategoryFilterProvider = StateProvider<String?>((_) => null);

final filteredVaultEntriesProvider =
    Provider<AsyncValue<List<DecryptedPasswordEntry>>>((ref) {
      final entries = ref.watch(vaultEntriesProvider);
      final search = ref.watch(vaultSearchProvider).toLowerCase();
      final category = ref.watch(vaultCategoryFilterProvider);

      return entries.whenData((list) {
        var filtered = list;
        if (search.isNotEmpty) {
          filtered = filtered
              .where(
                (e) =>
                    e.title.toLowerCase().contains(search) ||
                    (e.username?.toLowerCase().contains(search) ?? false) ||
                    (e.url?.toLowerCase().contains(search) ?? false),
              )
              .toList();
        }
        if (category != null) {
          filtered = filtered.where((e) => e.category == category).toList();
        }
        return filtered;
      });
    });

final vaultCategoriesProvider = Provider<AsyncValue<List<String>>>((ref) {
  return ref.watch(vaultEntriesProvider).whenData((entries) {
    final cats =
        entries.map((e) => e.category).whereType<String>().toSet().toList()
          ..sort();
    return cats;
  });
});
