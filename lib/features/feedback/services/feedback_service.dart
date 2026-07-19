import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/feedback_entry.dart';

abstract class FeedbackService {
  Future<List<FeedbackEntry>> getEntries();

  /// Emits the full entry list on listen and again after every change
  /// (IMPR-0018).
  Stream<List<FeedbackEntry>> watchEntries();
  Future<FeedbackEntry?> getEntry(String id);
  Future<void> addEntry(FeedbackEntry entry);
  Future<void> updateEntry(FeedbackEntry entry);
  Future<void> deleteEntry(String id);
}

class MockFeedbackService implements FeedbackService {
  static const _key = 'feedback_entries';
  final _changes = StreamController<List<FeedbackEntry>>.broadcast();

  @override
  Stream<List<FeedbackEntry>> watchEntries() async* {
    yield await getEntries();
    yield* _changes.stream;
  }

  @override
  Future<List<FeedbackEntry>> getEntries() async {
    final prefs = await SharedPreferencesAsync().getStringList(_key);
    if (prefs == null) return [];
    return prefs.map((e) {
      return FeedbackEntry.fromMap(jsonDecode(e) as Map<String, dynamic>);
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<FeedbackEntry?> getEntry(String id) async {
    final entries = await getEntries();
    return entries.where((e) => e.id == id).firstOrNull;
  }

  @override
  Future<void> addEntry(FeedbackEntry entry) async {
    final entries = await getEntries();
    entries.add(entry);
    await _save(entries);
  }

  @override
  Future<void> updateEntry(FeedbackEntry entry) async {
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

  Future<void> _save(List<FeedbackEntry> entries) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setStringList(
      _key,
      entries.map((e) => jsonEncode(e.toMap())).toList(),
    );
    _changes.add(
      List.of(entries)..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  void dispose() {
    _changes.close();
  }
}
