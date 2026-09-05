import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';

import '../../../presentation/widgets/image_attachment_picker.dart';
import '../../../presentation/widgets/image_attachment_strip.dart';
import '../../../services/image_attachment_controller.dart';
import '../../../services/image_upload_service.dart';
import '../../passwords/models/password_entry.dart';
import '../../passwords/providers/vault_providers.dart';
import '../models/streaming_platform.dart';
import '../providers/streaming_platform_providers.dart';

class StreamingPlatformEditPage extends ConsumerStatefulWidget {
  final String? platformId;
  const StreamingPlatformEditPage({super.key, this.platformId});

  @override
  ConsumerState<StreamingPlatformEditPage> createState() =>
      _StreamingPlatformEditPageState();
}

class _StreamingPlatformEditPageState
    extends ConsumerState<StreamingPlatformEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _qualityController = TextEditingController();

  final _icon = ImageAttachmentController(folder: 'streaming_platforms');
  String? _vaultEntryId;
  DateTime? _startedAt;
  DateTime? _endedAt;
  bool _isSaving = false;
  bool _isLoading = true;
  StreamingPlatform? _existing;

  @override
  void initState() {
    super.initState();
    _icon.addListener(_onIconChanged);
    if (widget.platformId != null) {
      _load();
    } else {
      _isLoading = false;
    }
  }

  void _onIconChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final platform = await ref
        .read(streamingPlatformServiceProvider)
        .getPlatform(widget.platformId!);
    if (!mounted) return;
    setState(() {
      if (platform != null) {
        _existing = platform;
        _nameController.text = platform.name;
        _urlController.text = platform.url ?? '';
        _qualityController.text = platform.quality ?? '';
        _vaultEntryId = platform.vaultEntryId;
        _startedAt = platform.subscriptionStartedAt;
        _endedAt = platform.subscriptionEndedAt;
        if (platform.iconUrl != null) _icon.seed([platform.iconUrl!]);
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _icon.removeListener(_onIconChanged);
    _icon.dispose();
    _nameController.dispose();
    _urlController.dispose();
    _qualityController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.platformId != null;

  String? _trimmedOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  /// The icon is a single image, so picking a new one replaces whatever is
  /// there — the controller still handles deleting the old file from
  /// Storage when the change is saved.
  Future<void> _pickIcon() async {
    if (_icon.isNotEmpty) _icon.removeAt(0);
    await pickImageInto(
      context,
      ref.read(imageUploadServiceProvider),
      _icon,
      includeCamera: false,
    );
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = (start ? _startedAt : _endedAt) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startedAt = picked;
      } else {
        _endedAt = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final uploader = ref.read(imageUploadServiceProvider);
      await _icon.uploadPending(uploader);
      await _icon.deleteRemoved(uploader);

      final platform = StreamingPlatform(
        id: widget.platformId,
        name: _nameController.text.trim(),
        url: _trimmedOrNull(_urlController),
        vaultEntryId: _vaultEntryId,
        quality: _trimmedOrNull(_qualityController),
        iconUrl: _icon.savedUrls.isNotEmpty ? _icon.savedUrls.first : null,
        subscriptionStartedAt: _startedAt,
        subscriptionEndedAt: _endedAt,
        createdAt: _existing?.createdAt,
      );

      final notifier = ref.read(streamingPlatformsProvider.notifier);
      if (_isEditing) {
        await notifier.updatePlatform(platform);
      } else {
        await notifier.addPlatform(platform);
      }

      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final dateFormat = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        title: QuickActionsTitle(
          child: Text(_isEditing ? 'Edit Platform' : 'New Platform'),
        ),
      ),
      body: ResponsiveCenter(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _qualityController,
                decoration: const InputDecoration(
                  labelText: 'Streaming quality',
                  hintText: '4K HDR, 1080p, Basic with ads…',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.high_quality_outlined),
                ),
              ),
              const SizedBox(height: 24),

              Text('Account', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _VaultEntryPicker(
                selectedId: _vaultEntryId,
                onChanged: (id) => setState(() => _vaultEntryId = id),
              ),
              const SizedBox(height: 24),

              Text(
                'Subscription',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_circle_outline),
                title: const Text('Started'),
                subtitle: Text(
                  _startedAt == null
                      ? 'Not set'
                      : dateFormat.format(_startedAt!),
                ),
                trailing: _startedAt == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _startedAt = null),
                      ),
                onTap: () => _pickDate(start: true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.stop_circle_outlined),
                title: const Text('Ended'),
                subtitle: Text(
                  _endedAt == null
                      ? 'Still subscribed'
                      : dateFormat.format(_endedAt!),
                ),
                trailing: _endedAt == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _endedAt = null),
                      ),
                onTap: () => _pickDate(start: false),
              ),
              const SizedBox(height: 24),

              Text('Icon', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_icon.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No icon set',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ImageAttachmentStrip(controller: _icon),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickIcon,
                icon: const Icon(Icons.add_a_photo),
                label: Text(_icon.isEmpty ? 'Add Icon' : 'Replace Icon'),
              ),

              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Update' : 'Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Links the platform to a password-vault entry rather than storing the
/// credentials here (WISH-0099). The vault has to be unlocked to browse
/// entries, so this degrades to a prompt when it is locked — an already
/// linked entry stays linked either way.
class _VaultEntryPicker extends ConsumerWidget {
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _VaultEntryPicker({required this.selectedId, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(vaultLockedProvider);

    if (locked) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.lock_outline),
        title: Text(
          selectedId == null ? 'No account linked' : 'Account linked',
        ),
        subtitle: const Text('Unlock the vault to choose an entry'),
        trailing: TextButton(
          onPressed: () => context.push('/passwords'),
          child: const Text('Unlock'),
        ),
      );
    }

    final entries =
        ref.watch(vaultEntriesProvider).valueOrNull ??
        const <DecryptedPasswordEntry>[];
    // A previously linked entry can be gone (deleted from the vault) —
    // fall back to "none" so the dropdown never holds a dangling value.
    final validSelection = entries.any((e) => e.id == selectedId)
        ? selectedId
        : null;

    return DropdownButtonFormField<String?>(
      initialValue: validSelection,
      decoration: const InputDecoration(
        labelText: 'Vault entry',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.key_outlined),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('None')),
        for (final entry in entries)
          DropdownMenuItem(
            value: entry.id,
            child: Text(
              entry.username == null
                  ? entry.title
                  : '${entry.title} (${entry.username})',
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
