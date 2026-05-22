import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../services/image_upload_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/file_entry.dart';
import '../services/file_service.dart';
import '../services/firestore_file_service.dart';

final fileServiceProvider = Provider<FileService>((ref) {
  if (AppConfig.useFirebase) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return FirestoreFileService(userId);
  }
  return MockFileService();
});

final fileListProvider =
    AsyncNotifierProvider<FileListNotifier, List<FileEntry>>(
      FileListNotifier.new,
    );

class FileListNotifier extends AsyncNotifier<List<FileEntry>> {
  @override
  FutureOr<List<FileEntry>> build() {
    return ref.watch(fileServiceProvider).getEntries();
  }

  Future<void> addEntry(FileEntry entry) async {
    await ref.read(fileServiceProvider).addEntry(entry);
    ref.invalidateSelf();
  }

  Future<void> updateEntry(FileEntry entry) async {
    await ref.read(fileServiceProvider).updateEntry(entry);
    ref.invalidateSelf();
  }

  /// Delete a single entry — for files, also removes the Storage blob so
  /// the user's storageUsedBytes is reclaimed automatically by the
  /// onFileDeleted trigger. For directories use [deleteRecursive].
  Future<void> deleteEntry(String id) async {
    final service = ref.read(fileServiceProvider);
    final entry = await service.getEntry(id);
    if (entry != null && !entry.isDirectory && entry.url != null) {
      await ref.read(imageUploadServiceProvider).deleteFile(entry.url!);
    }
    await service.deleteEntry(id);
    ref.invalidateSelf();
  }

  /// Recursively delete a directory and everything beneath it.
  /// Walks the in-memory tree once to avoid N Firestore round-trips per
  /// child during the descent. Storage deletes are still per-file because
  /// each download URL has to be torn down individually.
  Future<void> deleteRecursive(String id) async {
    final service = ref.read(fileServiceProvider);
    final uploader = ref.read(imageUploadServiceProvider);
    final all = await service.getEntries();
    final byParent = <String?, List<FileEntry>>{};
    for (final e in all) {
      byParent.putIfAbsent(e.parentId, () => []).add(e);
    }

    final toDelete = <FileEntry>[];
    void collect(String entryId) {
      final entry = all.where((e) => e.id == entryId).firstOrNull;
      if (entry == null) return;
      toDelete.add(entry);
      for (final child in byParent[entryId] ?? const <FileEntry>[]) {
        collect(child.id);
      }
    }

    collect(id);

    for (final entry in toDelete) {
      if (!entry.isDirectory && entry.url != null) {
        await uploader.deleteFile(entry.url!);
      }
      await service.deleteEntry(entry.id);
    }
    ref.invalidateSelf();
  }
}

/// Current directory the user is browsing. `null` = root.
final currentDirectoryProvider = StateProvider<String?>((_) => null);

final fileSortProvider = StateProvider<FileSort>((_) => FileSort.name);

/// Children of the directory currently being browsed, sorted by the
/// user's chosen sort. Directories sort before files within the same
/// sort key so folders always cluster at the top of the listing.
final entriesInCurrentDirProvider = Provider<AsyncValue<List<FileEntry>>>((
  ref,
) {
  final listAsync = ref.watch(fileListProvider);
  final dir = ref.watch(currentDirectoryProvider);
  final sort = ref.watch(fileSortProvider);

  return listAsync.whenData((entries) {
    final children = entries.where((e) => e.parentId == dir).toList();
    children.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      switch (sort) {
        case FileSort.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case FileSort.updatedAt:
          return b.updatedAt.compareTo(a.updatedAt);
      }
    });
    return children;
  });
});

/// Breadcrumb trail from root to the given directory (inclusive).
/// Empty list when at root.
final fileBreadcrumbProvider =
    Provider.family<AsyncValue<List<FileEntry>>, String?>((ref, dirId) {
      final listAsync = ref.watch(fileListProvider);
      return listAsync.whenData((entries) {
        if (dirId == null) return const <FileEntry>[];
        final byId = {for (final e in entries) e.id: e};
        final crumbs = <FileEntry>[];
        String? current = dirId;
        while (current != null && byId.containsKey(current)) {
          crumbs.insert(0, byId[current]!);
          current = byId[current]!.parentId;
        }
        return crumbs;
      });
    });
