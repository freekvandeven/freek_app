import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../services/log_service.dart';

/// A page that shows app logs and lets the user select lines to attach to feedback.
class LogSelectionPage extends HookConsumerWidget {
  const LogSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Snapshot the log list once when the page opens. New entries that
    // arrive while the user is picking aren't shown — same behaviour as
    // the previous StatefulWidget that read `entries` in `initState`.
    final logs = useMemoized<List<LogEntry>>(
      () => ref.read(logServiceProvider).entries.reversed.toList(),
      const [],
    );
    final selected = useState<List<bool>>(
      List<bool>.filled(logs.length, false),
    );
    final theme = Theme.of(context);
    final selectedCount = selected.value.where((s) => s).length;

    void setAt(int i, bool value) {
      selected.value = [...selected.value]..[i] = value;
    }

    void setAll(bool value) {
      selected.value = List<bool>.filled(logs.length, value);
    }

    void selectErrors() {
      selected.value = [
        for (final log in logs)
          log.level == 'ERROR' ||
              log.level == 'PLATFORM_ERROR' ||
              log.level == 'STACK',
      ];
    }

    void confirm() {
      final selectedLogs = <LogEntry>[];
      for (var i = 0; i < logs.length; i++) {
        if (selected.value[i]) selectedLogs.add(logs[i]);
      }
      Navigator.pop(
        context,
        selectedLogs.reversed.map((e) => e.formatted).join('\n'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Logs'),
        actions: [
          TextButton(
            onPressed: selectedCount > 0 ? confirm : null,
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
                TextButton(
                  onPressed: () => setAll(true),
                  child: const Text('All'),
                ),
                TextButton(
                  onPressed: () => setAll(false),
                  child: const Text('None'),
                ),
                TextButton(
                  onPressed: selectErrors,
                  child: const Text('Errors only'),
                ),
                const Spacer(),
                Text(
                  '${logs.length} entries',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: logs.isEmpty
                ? const Center(child: Text('No logs captured yet'))
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final isError =
                          log.level == 'ERROR' || log.level == 'PLATFORM_ERROR';
                      return CheckboxListTile(
                        dense: true,
                        value: selected.value[index],
                        onChanged: (v) => setAt(index, v ?? false),
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
