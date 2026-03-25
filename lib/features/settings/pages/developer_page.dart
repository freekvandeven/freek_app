import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../services/log_service.dart';
import 'test_data_page.dart';

class DeveloperPage extends ConsumerStatefulWidget {
  const DeveloperPage({super.key});

  @override
  ConsumerState<DeveloperPage> createState() => _DeveloperPageState();
}

class _DeveloperPageState extends ConsumerState<DeveloperPage> {
  Timer? _refreshTimer;
  String _levelFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    // Refresh log view periodically for live output.
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logService = ref.read(logServiceProvider);
    final allEntries = logService.entries;
    final entries = _levelFilter == 'ALL'
        ? allEntries
        : allEntries.where((e) => e.level == _levelFilter).toList();
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Copy logs',
            onPressed: entries.isEmpty
                ? null
                : () {
                    final text = entries.map((e) => e.formatted).join('\n');
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied ${entries.length} log entries'),
                      ),
                    );
                  },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear logs',
            onPressed: () {
              logService.clear();
              setState(() {});
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- App Info ---
          const _SectionHeader('App Info'),
          _InfoRow('App Name', AppConfig.appName),
          _InfoRow(
            'Storage Backend',
            AppConfig.useFirebase ? 'Firebase' : 'Local',
          ),
          _InfoRow('Emulators', AppConfig.useEmulators ? 'Yes' : 'No'),
          _InfoRow('Platform', defaultTargetPlatform.name),
          _InfoRow('kDebugMode', kDebugMode.toString()),

          const Divider(height: 32),

          // --- Firebase Info ---
          const _SectionHeader('Firebase'),
          _InfoRow('Project ID', AppConfig.firebaseProjectId),
          _InfoRow('Auth UID', user?.uid ?? 'Not signed in'),
          _InfoRow('Email', user?.email ?? '-'),
          _InfoRow('Email Verified', user?.emailVerified.toString() ?? '-'),
          if (user != null)
            FutureBuilder<IdTokenResult>(
              future: user.getIdTokenResult(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const _InfoRow('Custom Claims', 'Loading...');
                }
                final claims = snap.data!.claims ?? {};
                final display = claims.entries
                    .where(
                      (e) =>
                          e.key != 'iss' &&
                          e.key != 'aud' &&
                          e.key != 'auth_time' &&
                          e.key != 'user_id' &&
                          e.key != 'sub' &&
                          e.key != 'iat' &&
                          e.key != 'exp' &&
                          e.key != 'email' &&
                          e.key != 'email_verified' &&
                          e.key != 'firebase',
                    )
                    .map((e) => '${e.key}: ${e.value}')
                    .join(', ');
                return _InfoRow(
                  'Custom Claims',
                  display.isEmpty ? '(none)' : display,
                );
              },
            ),

          const Divider(height: 32),

          // --- Actions ---
          const _SectionHeader('Actions'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Force Token Refresh'),
                onPressed: () async {
                  await user?.getIdToken(true);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Token refreshed')),
                  );
                  setState(() {});
                },
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.cached, size: 18),
                label: const Text('Clear Image Cache'),
                onPressed: () {
                  PaintingBinding.instance.imageCache.clear();
                  PaintingBinding.instance.imageCache.clearLiveImages();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Image cache cleared')),
                  );
                },
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.science, size: 18),
                label: const Text('Generate Test Data'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TestDataPage()),
                  );
                },
              ),
            ],
          ),

          const Divider(height: 32),

          // --- Live Logs ---
          Row(
            children: [
              const Expanded(child: _SectionHeader('Logs')),
              DropdownButton<String>(
                value: _levelFilter,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All')),
                  DropdownMenuItem(value: 'INFO', child: Text('Info')),
                  DropdownMenuItem(value: 'WARN', child: Text('Warn')),
                  DropdownMenuItem(value: 'ERROR', child: Text('Error')),
                  DropdownMenuItem(value: 'STACK', child: Text('Stack')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _levelFilter = v);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No log entries yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                reverse: true,
                padding: const EdgeInsets.all(8),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[entries.length - 1 - index];
                  return Text(
                    entry.formatted,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: _logColor(entry.level),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Color _logColor(String level) {
    return switch (level) {
      'ERROR' || 'PLATFORM_ERROR' => Colors.red,
      'WARN' => Colors.orange,
      'STACK' => Colors.red.shade300,
      _ => Theme.of(context).colorScheme.onSurface,
    };
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
