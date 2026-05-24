import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';

import '../../../presentation/widgets/image_upload_preview_dialog.dart';
import '../../../services/image_upload_service.dart';
import '../../auth/providers/auth_providers.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loaded = false;
  bool _uploadingPhoto = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _loadProfile() {
    if (_loaded) return;
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _nameController.text = user.displayName ?? '';
      _bioController.text = user.bio ?? '';
      _phoneController.text = user.phone ?? '';
      _loaded = true;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();
    final phone = _phoneController.text.trim();

    final updated = user.copyWith(
      displayName: name.isEmpty ? user.displayName : name,
      bio: bio.isEmpty ? null : bio,
      clearBio: bio.isEmpty,
      phone: phone.isEmpty ? null : phone,
      clearPhone: phone.isEmpty,
    );

    await ref.read(authServiceProvider).updateProfile(updated);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      context.pop();
    }
  }

  Future<void> _changePhoto() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final uploadService = ref.read(imageUploadServiceProvider);
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            const PasteFromClipboardTile(),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await resolveImageSource(context, source, uploadService);
    if (picked == null || !mounted) return;

    final result = await showImageUploadPreviewDialog(
      context: context,
      originalBytes: picked.bytes,
      fileName: picked.fileName,
      sourcePath: picked.sourcePath,
    );
    if (result == null || !mounted) return;
    await result.maybeRemoveSourceFromDevice();

    setState(() => _uploadingPhoto = true);
    try {
      // Delete old profile photo from Storage
      final oldPhotoUrl = user.photoUrl;
      if (oldPhotoUrl != null && oldPhotoUrl.isNotEmpty) {
        await uploadService.deleteImage(oldPhotoUrl);
      }

      final url = await uploadService.uploadImageBytes(
        result.bytes,
        fileName: result.fileName,
        folder: 'profile',
      );
      if (mounted) {
        final updated = user.copyWith(photoUrl: url);
        await ref.read(authServiceProvider).updateProfile(updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Photo upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    _loadProfile();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Profile')),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _uploadingPhoto ? null : _changePhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: colorScheme.primaryContainer,
                      backgroundImage: user.photoUrl != null
                          ? CachedNetworkImageProvider(user.photoUrl!)
                          : null,
                      child: user.photoUrl == null
                          ? Text(
                              _initials(user.displayName ?? user.email),
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: colorScheme.primary,
                        child: _uploadingPhoto
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: colorScheme.onPrimary,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                user.email,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'About me',
                prefixIcon: Icon(Icons.info_outline),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Info',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _infoRow(
                      'Member since',
                      user.createdAt.toIso8601String().substring(0, 10),
                    ),
                    _infoRow(
                      'Last updated',
                      user.updatedAt.toIso8601String().substring(0, 10),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
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
