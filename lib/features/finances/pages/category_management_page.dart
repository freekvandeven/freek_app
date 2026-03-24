import 'package:flutter/material.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/finance_models.dart';
import '../providers/finance_providers.dart';

class CategoryManagementPage extends ConsumerWidget {
  const CategoryManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryListProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const QuickActionsTitle(child: Text('Categories')),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Expense'),
              Tab(text: 'Income'),
            ],
          ),
        ),
        body: categories.when(
          data: (cats) {
            final expense = cats
                .where((c) => c.type == TransactionType.expense)
                .toList();
            final income = cats
                .where((c) => c.type == TransactionType.income)
                .toList();

            return TabBarView(
              children: [
                _CategoryList(
                  categories: expense,
                  type: TransactionType.expense,
                ),
                _CategoryList(categories: income, type: TransactionType.income),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddDialog(context, ref),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    var selectedType = TransactionType.expense;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Expense'),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Income'),
                  ),
                ],
                selected: {selectedType},
                onSelectionChanged: (selection) {
                  setDialogState(() => selectedType = selection.first);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  ref
                      .read(categoryListProvider.notifier)
                      .addCategory(
                        FinancialCategory(
                          name: nameController.text.trim(),
                          type: selectedType,
                        ),
                      );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  final List<FinancialCategory> categories;
  final TransactionType type;

  const _CategoryList({required this.categories, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (categories.isEmpty) {
      return const Center(child: Text('No categories'));
    }

    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return Dismissible(
          key: Key(cat.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) => showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Category'),
              content: Text('Delete "${cat.name}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ),
          onDismissed: (_) =>
              ref.read(categoryListProvider.notifier).deleteCategory(cat.id),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.label)),
            title: Text(cat.name),
            onTap: () => _showEditDialog(context, ref, cat),
          ),
        );
      },
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    FinancialCategory cat,
  ) {
    final nameController = TextEditingController(text: cat.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                ref
                    .read(categoryListProvider.notifier)
                    .updateCategory(
                      cat.copyWith(name: nameController.text.trim()),
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
