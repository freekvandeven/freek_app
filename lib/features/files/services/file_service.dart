import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/file_entry.dart';

abstract class FileService {
  Future<List<FileEntry>> getEntries();
  Future<FileEntry?> getEntry(String id);
  Future<void> addEntry(FileEntry entry);
  Future<void> updateEntry(FileEntry entry);
  Future<void> deleteEntry(String id);
}

class MockFileService implements FileService {
  static const _key = 'file_entries';

  @override
  Future<List<FileEntry>> getEntries() async {
    final prefs = await SharedPreferencesAsync().getStringList(_key);
    if (prefs == null) return [];
    return prefs
        .map((e) => FileEntry.fromMap(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<FileEntry?> getEntry(String id) async {
    final entries = await getEntries();
    return entries.where((e) => e.id == id).firstOrNull;
  }

  @override
  Future<void> addEntry(FileEntry entry) async {
    final entries = await getEntries();
    entries.add(entry);
    await _save(entries);
  }

  @override
  Future<void> updateEntry(FileEntry entry) async {
    final entries = await getEntries();
    final idx = entries.indexWhere((e) => e.id == entry.id);
    if (idx != -1) {
      entries[idx] = entry;
      await _save(entries);
    }
  }

  @override
  Future<void> deleteEntry(String id) async {
    final entries = await getEntries();
    entries.removeWhere((e) => e.id == id);
    await _save(entries);
  }

  Future<void> _save(List<FileEntry> entries) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setStringList(
      _key,
      entries.map((e) => jsonEncode(e.toMap())).toList(),
    );
  }
}
