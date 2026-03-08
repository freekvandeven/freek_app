import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/vault_providers.dart';

/// Page shown when the vault needs to be set up or unlocked.
class VaultUnlockPage extends ConsumerStatefulWidget {
  const VaultUnlockPage({super.key});

  @override
  ConsumerState<VaultUnlockPage> createState() => _VaultUnlockPageState();
}

class _VaultUnlockPageState extends ConsumerState<VaultUnlockPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  String? _error;
  bool _isUnlocking = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSetup = ref.watch(vaultSetupProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Password Vault')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: isSetup.when(
            data: (setup) => setup ? _buildUnlockForm() : _buildSetupForm(),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),
        ),
      ),
    );
  }

  Widget _buildSetupForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock, size: 64, color: Colors.grey),
        const SizedBox(height: 24),
        Text(
          'Set Up Your Vault',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose a master password. This password encrypts all your '
          'vault entries. If you forget it, your data cannot be recovered.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _passwordController,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'Master Password',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmController,
          obscureText: _obscure,
          decoration: const InputDecoration(
            labelText: 'Confirm Master Password',
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isUnlocking ? null : _setupVault,
            child: _isUnlocking
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create Vault'),
          ),
        ),
      ],
    );
  }

  Widget _buildUnlockForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock, size: 64, color: Colors.grey),
        const SizedBox(height: 24),
        Text('Unlock Vault', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Enter your master password to access your passwords.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _passwordController,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'Master Password',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          onSubmitted: (_) => _unlockVault(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isUnlocking ? null : _unlockVault,
            child: _isUnlocking
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Unlock'),
          ),
        ),
      ],
    );
  }

  Future<void> _setupVault() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 8) {
      setState(() => _error = 'Master password must be at least 8 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isUnlocking = true;
      _error = null;
    });

    try {
      await ref.read(vaultServiceProvider).setupVault(password);
      ref.invalidate(vaultSetupProvider);
      final key = await ref.read(vaultServiceProvider).unlockVault(password);
      if (key != null && mounted) {
        ref.read(vaultKeyProvider.notifier).state = key;
        context.go('/passwords/list');
      }
    } finally {
      if (mounted) setState(() => _isUnlocking = false);
    }
  }

  Future<void> _unlockVault() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = 'Enter your master password.');
      return;
    }

    setState(() {
      _isUnlocking = true;
      _error = null;
    });

    try {
      final key = await ref.read(vaultServiceProvider).unlockVault(password);
      if (key != null && mounted) {
        ref.read(vaultKeyProvider.notifier).state = key;
        context.go('/passwords/list');
      } else {
        setState(() => _error = 'Incorrect master password.');
      }
    } finally {
      if (mounted) setState(() => _isUnlocking = false);
    }
  }
}
