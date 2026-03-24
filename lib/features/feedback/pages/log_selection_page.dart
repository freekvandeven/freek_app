import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/log_service.dart';

/// A page that shows app logs and lets the user select lines to attach to feedback.
class LogSelectionPage extends ConsumerStatefulWidget {
  const LogSelectionPage({super.key});

  @override
  ConsumerState<LogSelectionPage> createState() => _LogSelectionPageState();
}

class _LogSelectionPageState extends ConsumerState<LogSelectionPage> {
  late List<LogEntry> _logs;
  late List<bool> _selected;

  @override
  void initState() {
    super.initState();
    _logs = ref.read(logServiceProvider).entries.reversed.toList();
    _selected = List.filled(_logs.length, false);
  }

  void _selectAll() => setState(() {
    for (var i = 0; i < _selected.length; i++) {
      _selected[i] = true;
    }
  });

  void _deselectAll() => setState(() {
    for (var i = 0; i < _selected.length; i++) {
      _selected[i] = false;
    }
  });

  void _selectErrors() => setState(() {
    for (var i = 0; i < _logs.length; i++) {
      _selected[i] =
          _logs[i].level == 'ERROR' ||
          _logs[i].level == 'PLATFORM_ERROR' ||
          _logs[i].level == 'STACK';
    }
  });

  void _confirm() {
    final selectedLogs = <LogEntry>[];
    for (var i = 0; i < _logs.length; i++) {
      if (_selected[i]) selectedLogs.add(_logs[i]);
    }
    // Return in chronological order
    Navigator.pop(
      context,
      selectedLogs.reversed.map((e) => e.formatted).join('\n'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = _selected.where((s) => s).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Logs'),
        actions: [
          TextButton(
            onPressed: selectedCount > 0 ? _confirm : null,
            child: Text('Attach ($selectedCount)'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                TextButton(onPressed: _selectAll, child: const Text('All')),
                TextButton(onPressed: _deselectAll, child: const Text('None')),
                TextButton(
                  onPressed: _selectErrors,
                  child: const Text('Errors only'),
                ),
                const Spacer(),
                Text(
                  '${_logs.length} entries',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _logs.isEmpty
                ? const Center(child: Text('No logs captured yet'))
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final isError =
                          log.level == 'ERROR' || log.level == 'PLATFORM_ERROR';
                      return CheckboxListTile(
                        dense: true,
                        value: _selected[index],
                        onChanged: (v) =>
                            setState(() => _selected[index] = v ?? false),
                        title: Text(
                          log.formatted,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: isError ? theme.colorScheme.error : null,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
