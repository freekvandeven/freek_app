import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/knowledge_page.dart';

abstract class KnowledgeService {
  Future<List<KnowledgePage>> getPages();
  Future<KnowledgePage?> getPage(String id);
  Future<void> addPage(KnowledgePage page);
  Future<void> updatePage(KnowledgePage page);
  Future<void> deletePage(String id);
}

class MockKnowledgeService implements KnowledgeService {
  static const _key = 'knowledge_pages';

  @override
  Future<List<KnowledgePage>> getPages() async {
    final prefs = await SharedPreferencesAsync().getStringList(_key);
    if (prefs == null) return [];
    return prefs.map((e) {
      return KnowledgePage.fromMap(jsonDecode(e) as Map<String, dynamic>);
    }).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<KnowledgePage?> getPage(String id) async {
    final pages = await getPages();
    return pages.where((p) => p.id == id).firstOrNull;
  }

  @override
  Future<void> addPage(KnowledgePage page) async {
    final pages = await getPages();
    pages.add(page);
    await _save(pages);
  }

  @override
  Future<void> updatePage(KnowledgePage page) async {
    final pages = await getPages();
    final idx = pages.indexWhere((p) => p.id == page.id);
    if (idx != -1) {
      pages[idx] = page;
      await _save(pages);
    }
  }

  @override
  Future<void> deletePage(String id) async {
    final pages = await getPages();
    // Reparent children to root
    final children = pages.where((p) => p.parentId == id).toList();
    for (final child in children) {
      final idx = pages.indexWhere((p) => p.id == child.id);
      if (idx != -1) {
        pages[idx] = child.copyWith(parentId: () => null);
      }
    }
    pages.removeWhere((p) => p.id == id);
    await _save(pages);
  }

  Future<void> _save(List<KnowledgePage> pages) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setStringList(
      _key,
      pages.map((p) => jsonEncode(p.toMap())).toList(),
    );
  }
}
