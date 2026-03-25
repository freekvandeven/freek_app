import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/auth/services/biometric_service.dart';

class LockScreen extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final VoidCallback? onSignOut;

  const LockScreen({
    super.key,
    required this.child,
    required this.enabled,
    this.onSignOut,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with WidgetsBindingObserver {
  bool _locked = true;
  bool _authenticating = false;
  // Prevents the resume handler from re-triggering the biometric dialog
  // immediately after the user dismissed it.
  bool _dismissed = false;

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
    if (state == AppLifecycleState.paused && widget.enabled) {
      setState(() => _locked = true);
      _dismissed = false; // Real background → allow auto-auth on resume
    }
    if (state == AppLifecycleState.resumed && widget.enabled && _locked) {
      if (!_dismissed) _authenticate();
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
    _authenticating = false;
    if (mounted) setState(() => _locked = !success);
    if (!success) _dismissed = true;
  }

  Future<void> _manualUnlock() async {
    _dismissed = false;
    // Cancel any lingering biometric session before re-prompting.
    // On Android, calling authenticate() immediately after dismissal may
    // silently fail; stopAuthentication() ensures a clean state.
    await BiometricService.stopAuthentication();
    _authenticating = false;
    unawaited(_authenticate());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // Keep child mounted so form state is preserved across lock/unlock
        widget.child,
        if (_locked)
          Positioned.fill(
            child: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 72,
                        color: colorScheme.primary,
                      ),
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
                        onPressed: _manualUnlock,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Unlock'),
                      ),
                      if (widget.onSignOut != null) ...[
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: widget.onSignOut,
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
