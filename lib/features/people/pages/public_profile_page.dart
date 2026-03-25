import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../presentation/widgets/quick_actions_title.dart';
import '../../admin/providers/admin_providers.dart';

class PublicProfilePage extends ConsumerStatefulWidget {
  final String userId;

  const PublicProfilePage({super.key, required this.userId});

  @override
  ConsumerState<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends ConsumerState<PublicProfilePage> {
  Future<DocumentSnapshot<Map<String, dynamic>>>? _profileFuture;
  int? _currentLimitBytes;

  @override
  void initState() {
    super.initState();
    _profileFuture = FirebaseFirestore.instance
        .collection('publicProfiles')
        .doc(widget.userId)
        .get();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _showUpdateStorageLimitDialog(int currentLimitBytes) async {
    final currentMB = currentLimitBytes / (1024 * 1024);
    final controller = TextEditingController(
      text: currentMB.round().toString(),
    );

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Storage Limit'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Storage limit (MB)',
            suffixText: 'MB',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final mb = int.tryParse(controller.text.trim());
              if (mb != null && mb >= 0) {
                Navigator.pop(context, mb * 1024 * 1024);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        final adminService = ref.read(adminServiceProvider);
        await adminService.updateStorageLimit(
          targetUserId: widget.userId,
          storageLimitBytes: result,
        );
        setState(() {
          _currentLimitBytes = result;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Storage limit updated to ${_formatBytes(result)}'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _showGrantAdminDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Grant Admin'),
        content: const Text(
          'Are you sure you want to make this user an admin? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Grant Admin'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final adminService = ref.read(adminServiceProvider);
        await adminService.setAdminClaim(targetUid: widget.userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Admin privileges granted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const QuickActionsTitle(child: Text('Profile'))),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data();
          if (data == null) {
            return const Center(child: Text('Profile not found'));
          }

          final displayName = data['displayName'] as String? ?? 'Anonymous';
          final bio = data['bio'] as String?;
          final photoUrl = data['photoUrl'] as String?;
          final createdAtStr = data['createdAt'] as String?;
          final createdAt = createdAtStr != null
              ? DateTime.tryParse(createdAtStr)
              : null;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: photoUrl != null
                      ? CachedNetworkImageProvider(photoUrl)
                      : null,
                  child: photoUrl == null
                      ? Text(
                          _initials(displayName),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: colorScheme.onPrimaryContainer),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  displayName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (bio != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    bio,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (createdAt != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Member since ${DateFormat.yMMMM().format(createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              if (isAdmin) _buildAdminSection(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAdminSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return const SizedBox.shrink();
        }

        final userData = snapshot.data!.data()!;
        final storageUsedBytes = userData['storageUsedBytes'] as int? ?? 0;
        final storageLimitBytes =
            _currentLimitBytes ??
            (userData['storageLimitBytes'] as int? ?? 100 * 1024 * 1024);
        final usage = storageLimitBytes > 0
            ? (storageUsedBytes / storageLimitBytes).clamp(0.0, 1.0)
            : 0.0;

        return Column(
          children: [
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Admin',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: colorScheme.primary),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.storage_rounded, color: colorScheme.primary),
              title: const Text('Storage Limit'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: usage,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatBytes(storageUsedBytes)} / ${_formatBytes(storageLimitBytes)}',
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_rounded),
                onPressed: () =>
                    _showUpdateStorageLimitDialog(storageLimitBytes),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.admin_panel_settings,
                color: colorScheme.primary,
              ),
              title: const Text('Grant Admin'),
              subtitle: const Text('Make this user an admin'),
              trailing: IconButton(
                icon: const Icon(Icons.shield_rounded),
                onPressed: () => _showGrantAdminDialog(),
              ),
            ),
          ],
        );
      },
    );
  }

  String _initials(String name) {
    final parts = name.split(RegExp(r'[\s@]+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
