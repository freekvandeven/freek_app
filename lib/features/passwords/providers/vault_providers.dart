import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/password_entry.dart';
import '../services/firestore_vault_service.dart';
import '../services/vault_crypto.dart';
import '../services/vault_service.dart';

final vaultServiceProvider = Provider<VaultService>((ref) {
  if (AppConfig.useFirebase) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return FirestoreVaultService(userId);
  }
  final service = MockVaultService();
  ref.onDispose(service.dispose);
  return service;
});

final vaultSetupProvider = FutureProvider<bool>((ref) {
  return ref.watch(vaultServiceProvider).isVaultSetup();
});

/// Holds the derived encryption key in memory while the vault is unlocked.
/// Set to null when locked (or when navigating away).
final vaultKeyProvider = StateProvider<Uint8List?>((_) => null);

final vaultLockedProvider = Provider<bool>((ref) {
  return ref.watch(vaultKeyProvider) == null;
});

class VaultEntriesNotifier
    extends StreamNotifier<List<DecryptedPasswordEntry>> {
  @override
  Stream<List<DecryptedPasswordEntry>> build() {
    final key = ref.watch(vaultKeyProvider);
    // While locked there is nothing to decrypt and the entry stream is never
    // subscribed. Locking rebuilds this provider (key -> null), which cancels
    // the subscription and replaces the decrypted state with an empty list,
    // so plaintext never outlives the unlock session.
    if (key == null) return Stream.value(const []);

    return ref
        .watch(vaultServiceProvider)
        .watchEntries()
        .map(
          (entries) => entries.map((entry) {
            try {
              final password = VaultCrypto.decryptField(
                entry.encryptedPassword,
                key,
              );
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
          }).toList(),
        );
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
  }

  Future<void> deleteEntry(String id) async {
    await ref.read(vaultServiceProvider).deleteEntry(id);
  }
}

final vaultEntriesProvider =
    StreamNotifierProvider<VaultEntriesNotifier, List<DecryptedPasswordEntry>>(
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
