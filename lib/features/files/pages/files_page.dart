import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../presentation/widgets/app_snackbar.dart';
import '../../../presentation/widgets/file_drop_target.dart';
import '../../../presentation/widgets/pullable_center.dart';
import '../../../presentation/widgets/quick_actions_title.dart';
import '../../../presentation/widgets/responsive_center.dart';
import '../../../services/image_upload_service.dart';
import '../models/file_entry.dart';
import '../providers/file_providers.dart';

class FilesPage extends HookConsumerWidget {
  const FilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentDir = ref.watch(currentDirectoryProvider);
    final entries = ref.watch(entriesInCurrentDirProvider);
    final sort = ref.watch(fileSortProvider);
    final isUploading = useState(false);
    final crumbs = ref.watch(fileBreadcrumbProvider(currentDir));

    return Scaffold(
      appBar: AppBar(
        leading: currentDir == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_upward),
                tooltip: 'Up',
                onPressed: () {
                  final parent = crumbs.valueOrNull?.length == 1
                      ? null
                      : crumbs.valueOrNull?[crumbs.valueOrNull!.length - 2].id;
                  ref.read(currentDirectoryProvider.notifier).state = parent;
                },
              ),
        title: const QuickActionsTitle(child: Text('Files')),
        actions: [
          PopupMenuButton<FileSort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: sort,
            onSelected: (s) => ref.read(fileSortProvider.notifier).state = s,
            itemBuilder: (_) => const [
              PopupMenuItem(value: FileSort.name, child: Text('Name')),
              PopupMenuItem(
                value: FileSort.updatedAt,
                child: Text('Last updated'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'New folder',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => _promptNewFolder(context, ref, currentDir),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isUploading.value
            ? null
            : () => _pickAndUpload(context, ref, currentDir, isUploading),
        child: isUploading.value
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload_file),
      ),
      body: FileDropTarget(
        onFiles: (files) =>
            _uploadDroppedFiles(context, ref, currentDir, files),
        child: ResponsiveCenter(
          child: Column(
            children: [
              _Breadcrumb(crumbs: crumbs),
              const Divider(height: 1),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.refresh(fileListProvider.future),
                  child: entries.when(
                    loading: () => const PullableCenter(
                      child: CircularProgressIndicator(),
                    ),
                    error: (e, _) => PullableCenter(child: Text('Error: $e')),
                    data: (list) {
                      if (list.isEmpty) {
                        return const PullableCenter(
                          child: Text(
                            'No files here yet.\nUse + to upload, '
                            'drag a file in, or create a folder.',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _EntryTile(entry: list[i]),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadDroppedFiles(
    BuildContext context,
    WidgetRef ref,
    String? parentId,
    List<DroppedFile> files,
  ) async {
    final uploader = ref.read(imageUploadServiceProvider);
    for (final dropped in files) {
      try {
        final upload = await uploader.uploadFileBytes(
          dropped.bytes,
          fileName: dropped.fileName,
          contentType: dropped.mimeType,
          folder: 'files',
        );
        await ref
            .read(fileListProvider.notifier)
            .addEntry(
              FileEntry(
                name: upload.fileName,
                parentId: parentId,
                isDirectory: false,
                url: upload.url,
                contentType: upload.contentType,
                sizeBytes: upload.sizeBytes,
              ),
            );
      } on StorageLimitExceededException catch (e) {
        if (context.mounted) {
          context.showErrorSnackbar(e.toString());
        }
        break;
      } catch (e) {
        if (context.mounted) {
          context.showErrorSnackbar('Upload failed: $e');
        }
      }
    }
  }

  Future<void> _promptNewFolder(
    BuildContext context,
    WidgetRef ref,
    String? parentId,
  ) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await ref
        .read(fileListProvider.notifier)
        .addEntry(FileEntry(name: name, parentId: parentId, isDirectory: true));
  }

  Future<void> _pickAndUpload(
    BuildContext context,
    WidgetRef ref,
    String? parentId,
    ValueNotifier<bool> isUploading,
  ) async {
    final uploader = ref.read(imageUploadServiceProvider);
    final picked = await uploader.pickAnyFile();
    if (picked == null || picked.bytes == null) return;

    isUploading.value = true;
    try {
      final upload = await uploader.uploadFileBytes(
        picked.bytes!,
        fileName: picked.name,
        folder: 'files',
      );
      await ref
          .read(fileListProvider.notifier)
          .addEntry(
            FileEntry(
              name: upload.fileName,
              parentId: parentId,
              isDirectory: false,
              url: upload.url,
              contentType: upload.contentType,
              sizeBytes: upload.sizeBytes,
            ),
          );
    } on StorageLimitExceededException catch (e) {
      if (context.mounted) {
        context.showErrorSnackbar(e.toString());
      }
    } catch (e) {
      if (context.mounted) {
        context.showErrorSnackbar('Upload failed: $e');
      }
    } finally {
      isUploading.value = false;
    }
  }
}

class _Breadcrumb extends ConsumerWidget {
  const _Breadcrumb({required this.crumbs});
  final AsyncValue<List<FileEntry>> crumbs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = crumbs.valueOrNull ?? const [];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _Crumb(
            label: 'Files',
            onTap: () =>
                ref.read(currentDirectoryProvider.notifier).state = null,
          ),
          for (final dir in list) ...[
            const Icon(Icons.chevron_right, size: 18),
            _Crumb(
              label: dir.name,
              onTap: () =>
                  ref.read(currentDirectoryProvider.notifier).state = dir.id,
            ),
          ],
        ],
      ),
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ),
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry});
  final FileEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = _subtitle(entry);
    return ListTile(
      leading: Icon(
        entry.isDirectory
            ? Icons.folder_rounded
            : Icons.insert_drive_file_outlined,
        color: entry.isDirectory ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(entry.name),
      subtitle: Text(subtitle),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          switch (v) {
            case 'rename':
              await _rename(context, ref, entry);
              break;
            case 'delete':
              await _confirmDelete(context, ref, entry);
              break;
            case 'open':
              if (entry.url != null) {
                await launchUrl(
                  Uri.parse(entry.url!),
                  mode: LaunchMode.externalApplication,
                );
              }
              break;
          }
        },
        itemBuilder: (_) => [
          if (!entry.isDirectory && entry.url != null)
            const PopupMenuItem(value: 'open', child: Text('Open')),
          const PopupMenuItem(value: 'rename', child: Text('Rename')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
      onTap: () async {
        if (entry.isDirectory) {
          ref.read(currentDirectoryProvider.notifier).state = entry.id;
        } else if (entry.url != null) {
          await launchUrl(
            Uri.parse(entry.url!),
            mode: LaunchMode.externalApplication,
          );
        }
      },
    );
  }

  String _subtitle(FileEntry entry) {
    final updated = DateFormat.yMMMd().add_jm().format(entry.updatedAt);
    if (entry.isDirectory) return 'Folder · $updated';
    return '${formatBytes(entry.sizeBytes)} · $updated';
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    FileEntry entry,
  ) async {
    final controller = TextEditingController(text: entry.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == entry.name) {
      return;
    }
    await ref
        .read(fileListProvider.notifier)
        .updateEntry(entry.copyWith(name: newName));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    FileEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(entry.isDirectory ? 'Delete folder?' : 'Delete file?'),
        content: Text(
          entry.isDirectory
              ? 'This folder and everything inside it will be permanently deleted.'
              : 'This file will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (entry.isDirectory) {
      await ref.read(fileListProvider.notifier).deleteRecursive(entry.id);
    } else {
      await ref.read(fileListProvider.notifier).deleteEntry(entry.id);
    }
  }
}
