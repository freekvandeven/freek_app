import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/knowledge_page.dart';
import '../services/firestore_knowledge_service.dart';
import '../services/knowledge_service.dart';

final knowledgeServiceProvider = Provider<KnowledgeService>((ref) {
  if (AppConfig.useFirebase) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return FirestoreKnowledgeService(userId);
  }
  return MockKnowledgeService();
});

final knowledgeListProvider =
    AsyncNotifierProvider<KnowledgeListNotifier, List<KnowledgePage>>(
      KnowledgeListNotifier.new,
    );

class KnowledgeListNotifier extends AsyncNotifier<List<KnowledgePage>> {
  @override
  FutureOr<List<KnowledgePage>> build() {
    return ref.watch(knowledgeServiceProvider).getPages();
  }

  Future<void> addPage(KnowledgePage page) async {
    await ref.read(knowledgeServiceProvider).addPage(page);
    ref.invalidateSelf();
  }

  Future<void> updatePage(KnowledgePage page) async {
    await ref.read(knowledgeServiceProvider).updatePage(page);
    ref.invalidateSelf();
  }

  Future<void> deletePage(String id) async {
    await ref.read(knowledgeServiceProvider).deletePage(id);
    ref.invalidateSelf();
  }
}

final knowledgeSearchProvider = StateProvider<String>((_) => '');
final knowledgeWipOnlyProvider = StateProvider<bool>((_) => false);

final filteredKnowledgeProvider = Provider<AsyncValue<List<KnowledgePage>>>((
  ref,
) {
  final listAsync = ref.watch(knowledgeListProvider);
  final search = ref.watch(knowledgeSearchProvider).toLowerCase();
  final wipOnly = ref.watch(knowledgeWipOnlyProvider);

  return listAsync.whenData((pages) {
    var filtered = pages;
    if (search.isNotEmpty) {
      filtered = filtered.where((p) {
        return p.title.toLowerCase().contains(search) ||
            p.tags.any((t) => t.toLowerCase().contains(search));
      }).toList();
    }
    if (wipOnly) {
      filtered = filtered.where((p) => p.isWip).toList();
    }
    return filtered;
  });
});

/// Returns root pages (no parent), optionally filtered to WIP only.
final rootKnowledgePagesProvider = Provider<AsyncValue<List<KnowledgePage>>>((
  ref,
) {
  final listAsync = ref.watch(knowledgeListProvider);
  final wipOnly = ref.watch(knowledgeWipOnlyProvider);
  return listAsync.whenData((pages) {
    var roots = pages.where((p) => p.parentId == null).toList();
    if (wipOnly) roots = roots.where((p) => p.isWip).toList();
    return roots;
  });
});

/// Returns child pages of a given parent
final childKnowledgePagesProvider =
    Provider.family<AsyncValue<List<KnowledgePage>>, String>((ref, parentId) {
      final listAsync = ref.watch(knowledgeListProvider);
      return listAsync.whenData(
        (pages) => pages.where((p) => p.parentId == parentId).toList(),
      );
    });

/// Builds breadcrumb path for a page
final breadcrumbProvider =
    Provider.family<AsyncValue<List<KnowledgePage>>, String>((ref, pageId) {
      final listAsync = ref.watch(knowledgeListProvider);
      return listAsync.whenData((pages) {
        final pageMap = {for (final p in pages) p.id: p};
        final crumbs = <KnowledgePage>[];
        String? current = pageId;
        while (current != null && pageMap.containsKey(current)) {
          crumbs.insert(0, pageMap[current]!);
          current = pageMap[current]!.parentId;
        }
        return crumbs;
      });
    });
