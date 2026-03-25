import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/admin_providers.dart';
import '../services/admin_service.dart';

class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});

  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  List<InviteCode> _codes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCodes();
  }

  Future<void> _loadCodes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final codes = await ref.read(adminServiceProvider).listInviteCodes();
      if (!mounted) return;
      setState(() {
        _codes = codes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createCode() async {
    final customCode = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Create Invite Code'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Custom code (leave empty to auto-generate)',
              hintText: 'e.g. WELCOME2024',
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (customCode == null) return;

    try {
      final code = await ref
          .read(adminServiceProvider)
          .createInviteCode(code: customCode.isEmpty ? null : customCode);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Created invite code: $code')));
      await _loadCodes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create code: $e')));
    }
  }

  Future<void> _deleteCode(String code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invite Code'),
        content: Text('Delete invite code "$code"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(adminServiceProvider).deleteInviteCode(code);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invite code deleted')));
      await _loadCodes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete code: $e')));
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Code copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createCode,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _loadCodes,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCodes,
      child: ListView(
        children: [
          _buildSectionHeader('Invite Codes', _codes.length),
          if (_codes.isEmpty)
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('No invite codes available'),
              subtitle: Text('Tap + to create one'),
            )
          else
            ..._codes.map(_buildCodeTile),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 8),
          Chip(label: Text('$count')),
        ],
      ),
    );
  }

  Widget _buildCodeTile(InviteCode invite) {
    final dateFormat = DateFormat.yMMMd();
    String? subtitle;
    if (invite.createdAt != null) {
      final date = DateTime.tryParse(invite.createdAt!);
      if (date != null) {
        subtitle = 'Created ${dateFormat.format(date)}';
      }
    }

    return ListTile(
      leading: const Icon(Icons.vpn_key_rounded),
      title: Text(
        invite.code,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy code',
            onPressed: () => _copyCode(invite.code),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete code',
            onPressed: () => _deleteCode(invite.code),
          ),
        ],
      ),
    );
  }
}
