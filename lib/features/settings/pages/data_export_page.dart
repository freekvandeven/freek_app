import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:share_plus/share_plus.dart';

import '../../calendar/providers/calendar_providers.dart';
import '../../feedback/providers/feedback_providers.dart';
import '../../finances/providers/finance_providers.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../knowledge/providers/knowledge_providers.dart';
import '../../recipes/providers/recipe_providers.dart';
import '../../tasks/providers/task_providers.dart';

class DataExportPage extends ConsumerStatefulWidget {
  const DataExportPage({super.key});

  @override
  ConsumerState<DataExportPage> createState() => _DataExportPageState();
}

class _DataExportPageState extends ConsumerState<DataExportPage> {
  final _selected = <String, bool>{
    'tasks': true,
    'recipes': true,
    'transactions': true,
    'categories': true,
    'assets': true,
    'calendar': true,
    'inventory': true,
    'feedback': true,
    'knowledge': true,
  };
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Export Data')),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Select which data to export as CSV files:'),
                ),
                for (final entry in _selected.entries)
                  CheckboxListTile(
                    title: Text(
                      entry.key[0].toUpperCase() + entry.key.substring(1),
                    ),
                    value: entry.value,
                    onChanged: (v) {
                      setState(() => _selected[entry.key] = v ?? false);
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _exporting ? null : _export,
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(_exporting ? 'Exporting...' : 'Export'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    setState(() => _exporting = true);

    try {
      final files = <XFile>[];

      if (_selected['tasks'] == true) {
        final data = ref.read(taskListProvider).valueOrNull ?? [];
        final rows = [
          [
            'id',
            'title',
            'description',
            'completed',
            'priority',
            'dueDate',
            'createdAt',
          ],
          for (final t in data)
            [
              t.id,
              t.title,
              t.description ?? '',
              t.isCompleted.toString(),
              t.priority.name,
              t.dueDate?.toIso8601String() ?? '',
              t.createdAt.toIso8601String(),
            ],
        ];
        files.add(_writeCsv('tasks.csv', rows));
      }

      if (_selected['recipes'] == true) {
        final data = ref.read(recipeListProvider).valueOrNull ?? [];
        final rows = [
          [
            'id',
            'title',
            'description',
            'servings',
            'prepTimeMinutes',
            'cookTimeMinutes',
            'tags',
            'createdAt',
          ],
          for (final r in data)
            [
              r.id,
              r.title,
              r.description ?? '',
              r.servings.toString(),
              r.prepTimeMinutes?.toString() ?? '',
              r.cookTimeMinutes?.toString() ?? '',
              r.tags.join('; '),
              r.createdAt.toIso8601String(),
            ],
        ];
        files.add(_writeCsv('recipes.csv', rows));
      }

      if (_selected['transactions'] == true) {
        final data = ref.read(transactionListProvider).valueOrNull ?? [];
        final rows = [
          [
            'id',
            'type',
            'amount',
            'description',
            'categoryId',
            'date',
            'isRecurring',
          ],
          for (final t in data)
            [
              t.id,
              t.type.name,
              t.amount.toString(),
              t.description,
              t.categoryId ?? '',
              t.date.toIso8601String(),
              t.isRecurring.toString(),
            ],
        ];
        files.add(_writeCsv('transactions.csv', rows));
      }

      if (_selected['categories'] == true) {
        final data = ref.read(categoryListProvider).valueOrNull ?? [];
        final rows = [
          ['id', 'name', 'type', 'icon'],
          for (final c in data) [c.id, c.name, c.type.name, c.icon ?? ''],
        ];
        files.add(_writeCsv('categories.csv', rows));
      }

      if (_selected['assets'] == true) {
        final data = ref.read(assetListProvider).valueOrNull ?? [];
        final rows = [
          ['id', 'name', 'type', 'currentValue', 'currency'],
          for (final a in data)
            [a.id, a.name, a.type.name, a.currentValue.toString(), a.currency],
        ];
        files.add(_writeCsv('assets.csv', rows));
      }

      if (_selected['calendar'] == true) {
        final data = ref.read(calendarEventsProvider).valueOrNull ?? [];
        final rows = [
          ['id', 'title', 'description', 'type', 'date'],
          for (final e in data)
            [
              e.id,
              e.title,
              e.description ?? '',
              e.type.name,
              e.date.toIso8601String(),
            ],
        ];
        files.add(_writeCsv('calendar_events.csv', rows));
      }

      if (_selected['inventory'] == true) {
        final data = ref.read(inventoryListProvider).valueOrNull ?? [];
        final rows = [
          [
            'id',
            'name',
            'description',
            'category',
            'location',
            'quantity',
            'purchasePrice',
            'purchaseDate',
          ],
          for (final i in data)
            [
              i.id,
              i.name,
              i.description ?? '',
              i.category ?? '',
              i.location ?? '',
              i.quantity.toString(),
              i.purchasePrice?.toString() ?? '',
              i.purchaseDate?.toIso8601String() ?? '',
            ],
        ];
        files.add(_writeCsv('inventory.csv', rows));
      }

      if (_selected['feedback'] == true) {
        final data = ref.read(feedbackListProvider).valueOrNull ?? [];
        final rows = [
          ['id', 'type', 'title', 'description', 'status', 'createdAt'],
          for (final f in data)
            [
              f.id,
              f.type.name,
              f.title,
              f.description,
              f.status.name,
              f.createdAt.toIso8601String(),
            ],
        ];
        files.add(_writeCsv('feedback.csv', rows));
      }

      if (_selected['knowledge'] == true) {
        final data = ref.read(knowledgeListProvider).valueOrNull ?? [];
        final rows = [
          ['id', 'title', 'content', 'tags', 'parentId', 'createdAt'],
          for (final k in data)
            [
              k.id,
              k.title,
              k.content,
              k.tags.join('; '),
              k.parentId ?? '',
              k.createdAt.toIso8601String(),
            ],
        ];
        files.add(_writeCsv('knowledge_pages.csv', rows));
      }

      if (files.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No collections selected')),
          );
        }
        return;
      }

      await Share.shareXFiles(files, subject: 'Personal App Data Export');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  XFile _writeCsv(String filename, List<List<dynamic>> rows) {
    final csv = const ListToCsvConverter().convert(rows);
    // UTF-8 BOM for Excel compatibility
    final bytes = utf8.encode('\uFEFF$csv');
    return XFile.fromData(
      Uint8List.fromList(bytes),
      name: filename,
      mimeType: 'text/csv',
    );
  }
}
