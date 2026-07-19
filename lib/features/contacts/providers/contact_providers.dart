import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/contact.dart';
import '../services/contact_service.dart';
import '../services/firestore_contact_service.dart';

final contactServiceProvider = Provider<ContactService>((ref) {
  if (AppConfig.useFirebase) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return FirestoreContactService(userId);
  }
  final service = MockContactService();
  ref.onDispose(service.dispose);
  return service;
});

final contactListProvider =
    StreamNotifierProvider<ContactListNotifier, List<Contact>>(
      ContactListNotifier.new,
    );

class ContactListNotifier extends StreamNotifier<List<Contact>> {
  @override
  Stream<List<Contact>> build() {
    return ref.watch(contactServiceProvider).watchContacts();
  }

  Future<void> addContact(Contact contact) async {
    await ref.read(contactServiceProvider).addContact(contact);
  }

  Future<void> updateContact(Contact contact) async {
    await ref.read(contactServiceProvider).updateContact(contact);
  }

  Future<void> deleteContact(String id) async {
    await ref.read(contactServiceProvider).deleteContact(id);
  }
}

final contactSearchProvider = StateProvider<String>((_) => '');

/// Contacts filtered by the current search term, sorted by name.
final filteredContactsProvider = Provider<AsyncValue<List<Contact>>>((ref) {
  final listAsync = ref.watch(contactListProvider);
  final search = ref.watch(contactSearchProvider).toLowerCase();
  return listAsync.whenData((contacts) {
    var filtered = contacts;
    if (search.isNotEmpty) {
      filtered = filtered.where((c) {
        return c.name.toLowerCase().contains(search) ||
            (c.email?.toLowerCase().contains(search) ?? false) ||
            (c.phone?.toLowerCase().contains(search) ?? false) ||
            c.notes.toLowerCase().contains(search);
      }).toList();
    }
    filtered.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return filtered;
  });
});

/// Single-contact lookup by id — convenience for surfaces that store
/// only the id and need to render a name/email/etc.
final contactByIdProvider = Provider.family<Contact?, String>((ref, id) {
  final listAsync = ref.watch(contactListProvider);
  return listAsync.valueOrNull?.where((c) => c.id == id).firstOrNull;
});
