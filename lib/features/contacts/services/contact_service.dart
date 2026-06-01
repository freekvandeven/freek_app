import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/contact.dart';

abstract class ContactService {
  Future<List<Contact>> getContacts();
  Future<Contact?> getContact(String id);
  Future<void> addContact(Contact contact);
  Future<void> updateContact(Contact contact);
  Future<void> deleteContact(String id);
}

class MockContactService implements ContactService {
  static const _key = 'contacts';

  @override
  Future<List<Contact>> getContacts() async {
    final prefs = await SharedPreferencesAsync().getStringList(_key);
    if (prefs == null) return [];
    return prefs
        .map((e) => Contact.fromMap(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Contact?> getContact(String id) async {
    final contacts = await getContacts();
    return contacts.where((c) => c.id == id).firstOrNull;
  }

  @override
  Future<void> addContact(Contact contact) async {
    final contacts = await getContacts();
    contacts.add(contact);
    await _save(contacts);
  }

  @override
  Future<void> updateContact(Contact contact) async {
    final contacts = await getContacts();
    final idx = contacts.indexWhere((c) => c.id == contact.id);
    if (idx != -1) {
      contacts[idx] = contact;
      await _save(contacts);
    }
  }

  @override
  Future<void> deleteContact(String id) async {
    final contacts = await getContacts();
    contacts.removeWhere((c) => c.id == id);
    await _save(contacts);
  }

  Future<void> _save(List<Contact> contacts) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setStringList(
      _key,
      contacts.map((c) => jsonEncode(c.toMap())).toList(),
    );
  }
}
