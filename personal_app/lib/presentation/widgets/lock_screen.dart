import 'package:flutter/material.dart';

import '../../features/auth/services/biometric_service.dart';

class LockScreen extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const LockScreen({super.key, required this.child, required this.enabled});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with WidgetsBindingObserver {
  bool _locked = true;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.enabled) {
      _authenticate();
    } else {
      _locked = false;
    }
  }

  @override
  void didUpdateWidget(covariant LockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _locked) {
      setState(() => _locked = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.enabled && _locked) {
      _authenticate();
    }
    if (state == AppLifecycleState.paused && widget.enabled) {
      setState(() => _locked = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    _authenticating = true;

    final available = await BiometricService.isAvailable;
    if (!available) {
      if (mounted) setState(() => _locked = false);
      _authenticating = false;
      return;
    }

    final success = await BiometricService.authenticate();
    if (mounted) setState(() => _locked = !success);
    _authenticating = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 72, color: colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'Freek App',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Authenticate to unlock',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
