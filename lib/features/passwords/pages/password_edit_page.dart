import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';

import '../providers/vault_providers.dart';
import '../services/vault_crypto.dart';

class PasswordEditPage extends ConsumerStatefulWidget {
  final String? entryId;
  const PasswordEditPage({super.key, this.entryId});

  @override
  ConsumerState<PasswordEditPage> createState() => _PasswordEditPageState();
}

class _PasswordEditPageState extends ConsumerState<PasswordEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _urlController = TextEditingController();
  final _notesController = TextEditingController();
  final _categoryController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.entryId != null) {
      _loadEntry();
    } else {
      _isLoading = false;
    }
  }

  void _loadEntry() {
    final entries = ref.read(vaultEntriesProvider).valueOrNull ?? [];
    final entry = entries.where((e) => e.id == widget.entryId).firstOrNull;
    if (entry != null) {
      _titleController.text = entry.title;
      _usernameController.text = entry.username ?? '';
      _passwordController.text = entry.password;
      _urlController.text = entry.url ?? '';
      _notesController.text = entry.notes ?? '';
      _categoryController.text = entry.category ?? '';
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(vaultEntriesProvider.notifier);

    if (widget.entryId != null) {
      await notifier.updateEntry(
        id: widget.entryId!,
        title: _titleController.text.trim(),
        username: _usernameController.text.trim().isEmpty
            ? null
            : _usernameController.text.trim(),
        password: _passwordController.text,
        url: _urlController.text.trim().isEmpty
            ? null
            : _urlController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
      );
    } else {
      await notifier.addEntry(
        title: _titleController.text.trim(),
        username: _usernameController.text.trim().isEmpty
            ? null
            : _usernameController.text.trim(),
        password: _passwordController.text,
        url: _urlController.text.trim().isEmpty
            ? null
            : _urlController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
      );
    }

    if (mounted) context.pop();
  }

  void _generatePassword() {
    final password = VaultCrypto.generatePassword();
    setState(() {
      _passwordController.text = password;
      _obscurePassword = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entryId != null;
    final categories = ref.watch(vaultCategoriesProvider);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: QuickActionsTitle(
            child: Text(isEditing ? 'Edit Entry' : 'New Entry'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: QuickActionsTitle(
          child: Text(isEditing ? 'Edit Entry' : 'New Entry'),
        ),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Google, GitHub',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username / Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.auto_fix_high),
                        tooltip: 'Generate password',
                        onPressed: _generatePassword,
                      ),
                    ],
                  ),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),

              // Category with autocomplete from existing
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _categoryController.text),
                optionsBuilder: (textEditingValue) {
                  final cats = categories.valueOrNull ?? [];
                  if (textEditingValue.text.isEmpty) return cats;
                  return cats.where(
                    (c) => c.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    ),
                  );
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onSubmitted) {
                      // Sync with our controller
                      controller.addListener(() {
                        _categoryController.text = controller.text;
                      });
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          hintText: 'e.g. Social, Finance, Work',
                        ),
                      );
                    },
                onSelected: (value) => _categoryController.text = value,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                  hintText: 'Additional info (encrypted)',
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
