import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../services/image_upload_service.dart';
import '../../../utils/search_aliases.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/knowledge_page.dart';
import '../services/firestore_knowledge_service.dart';
import '../services/knowledge_service.dart';

final knowledgeServiceProvider = Provider<KnowledgeService>((ref) {
  if (AppConfig.useFirebase) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return FirestoreKnowledgeService(userId);
  }
  final service = MockKnowledgeService();
  ref.onDispose(service.dispose);
  return service;
});

final knowledgeListProvider =
    StreamNotifierProvider<KnowledgeListNotifier, List<KnowledgePage>>(
      KnowledgeListNotifier.new,
    );

class KnowledgeListNotifier extends StreamNotifier<List<KnowledgePage>> {
  @override
  Stream<List<KnowledgePage>> build() {
    return ref.watch(knowledgeServiceProvider).watchPages();
  }

  Future<void> addPage(KnowledgePage page) async {
    await ref.read(knowledgeServiceProvider).addPage(page);
  }

  Future<void> updatePage(KnowledgePage page) async {
    await ref.read(knowledgeServiceProvider).updatePage(page);
  }

  Future<void> deletePage(String id) async {
    // Cascade-delete any attached files from Storage so the user's
    // storageUsedBytes doesn't drift (WISH-0068). The Storage triggers
    // (onFileDeleted) handle the bookkeeping automatically; we just
    // have to issue the deletes.
    final service = ref.read(knowledgeServiceProvider);
    final page = await service.getPage(id);
    if (page != null && page.attachments.isNotEmpty) {
      final uploader = ref.read(imageUploadServiceProvider);
      for (final att in page.attachments) {
        await uploader.deleteFile(att.url);
      }
    }
    await service.deletePage(id);
  }
}

final knowledgeSearchProvider = StateProvider<String>((_) => '');
final knowledgeWipOnlyProvider = StateProvider<bool>((_) => false);

/// Returns the set of page IDs visible when WIP filter is active:
/// every WIP page plus all its ancestors up the tree.
Set<String> _wipVisibleIds(List<KnowledgePage> pages) {
  final pageMap = {for (final p in pages) p.id: p};
  final visible = <String>{};
  for (final p in pages) {
    if (!p.isWip) continue;
    String? id = p.id;
    while (id != null && pageMap.containsKey(id)) {
      if (!visible.add(id)) break;
      id = pageMap[id]!.parentId;
    }
  }
  return visible;
}

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
            p.tags.any((t) => t.toLowerCase().contains(search)) ||
            matchesSearchAliases(p.searchAliases, search);
      }).toList();
    }
    if (wipOnly) {
      filtered = filtered.where((p) => p.isWip).toList();
    }
    return filtered;
  });
});

/// Returns root pages (no parent), respecting WIP filter.
/// When WIP filter is on, includes roots that are WIP or have WIP descendants.
final rootKnowledgePagesProvider = Provider<AsyncValue<List<KnowledgePage>>>((
  ref,
) {
  final listAsync = ref.watch(knowledgeListProvider);
  final wipOnly = ref.watch(knowledgeWipOnlyProvider);
  return listAsync.whenData((pages) {
    var roots = pages.where((p) => p.parentId == null).toList();
    if (wipOnly) {
      final visibleIds = _wipVisibleIds(pages);
      roots = roots.where((p) => visibleIds.contains(p.id)).toList();
    }
    return roots;
  });
});

/// Returns child pages of a given parent (unfiltered — used on view pages).
final childKnowledgePagesProvider =
    Provider.family<AsyncValue<List<KnowledgePage>>, String>((ref, parentId) {
      final listAsync = ref.watch(knowledgeListProvider);
      return listAsync.whenData(
        (pages) => pages.where((p) => p.parentId == parentId).toList(),
      );
    });

/// Returns child pages for the tree view, respecting WIP filter.
/// When WIP filter is on, only shows children that are WIP or have WIP descendants.
final treeChildKnowledgePagesProvider =
    Provider.family<AsyncValue<List<KnowledgePage>>, String>((ref, parentId) {
      final listAsync = ref.watch(knowledgeListProvider);
      final wipOnly = ref.watch(knowledgeWipOnlyProvider);
      return listAsync.whenData((pages) {
        var children = pages.where((p) => p.parentId == parentId).toList();
        if (wipOnly) {
          final visibleIds = _wipVisibleIds(pages);
          children = children.where((p) => visibleIds.contains(p.id)).toList();
        }
        return children;
      });
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
