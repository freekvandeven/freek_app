import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';

import '../../../presentation/widgets/pullable_center.dart';
import '../../settings/providers/currency_providers.dart';
import '../models/finance_models.dart';
import '../providers/finance_providers.dart';

class TransactionListPage extends ConsumerWidget {
  const TransactionListPage({super.key});

  static final _dateFormat = DateFormat.yMMMd();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final converter = ref.watch(currencyConverterProvider);
    final transactions = ref.watch(filteredTransactionsProvider);
    final typeFilter = ref.watch(transactionTypeFilterProvider);
    final categories = ref.watch(categoryListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Transactions')),
        actions: [
          PopupMenuButton<TransactionTypeFilter>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) =>
                ref.read(transactionTypeFilterProvider.notifier).state = value,
            itemBuilder: (_) => TransactionTypeFilter.values
                .map(
                  (f) => PopupMenuItem(
                    value: f,
                    child: Row(
                      children: [
                        if (f == typeFilter) const Icon(Icons.check, size: 18),
                        if (f == typeFilter) const SizedBox(width: 8),
                        Text(f.name[0].toUpperCase() + f.name.substring(1)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(transactionListProvider.future),
        child: transactions.when(
          data: (list) {
            if (list.isEmpty) {
              return const PullableCenter(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No transactions yet'),
                  ],
                ),
              );
            }

            // Group by month
            final grouped = <String, List<FinancialTransaction>>{};
            for (final t in list) {
              final key = DateFormat.yMMMM().format(t.date);
              grouped.putIfAbsent(key, () => []).add(t);
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: grouped.length,
              itemBuilder: (context, groupIndex) {
                final month = grouped.keys.elementAt(groupIndex);
                final items = grouped[month]!;
                final monthTotal = items.fold<double>(
                  0,
                  (sum, t) =>
                      sum +
                      (t.type == TransactionType.income ? t.amount : -t.amount),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(month, style: theme.textTheme.titleSmall),
                          Text(
                            converter.format(monthTotal),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: monthTotal >= 0
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...items.map((t) {
                      final catName =
                          categories.valueOrNull
                              ?.where((c) => c.id == t.categoryId)
                              .map((c) => c.name)
                              .firstOrNull ??
                          '';
                      final isExpense = t.type == TransactionType.expense;

                      return Dismissible(
                        key: Key(t.id),
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
                            title: const Text('Delete Transaction'),
                            content: Text('Delete "${t.title}"?'),
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
                        onDismissed: (_) => ref
                            .read(transactionListProvider.notifier)
                            .deleteTransaction(t.id),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isExpense
                                ? Colors.red.shade50
                                : Colors.green.shade50,
                            child: Icon(
                              isExpense
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: isExpense ? Colors.red : Colors.green,
                            ),
                          ),
                          title: Text(t.title),
                          subtitle: Text(
                            [
                              catName,
                              _dateFormat.format(t.date),
                            ].where((s) => s.isNotEmpty).join(' \u2022 '),
                          ),
                          trailing: Text(
                            '${isExpense ? '-' : '+'}${converter.format(t.amount)}',
                            style: TextStyle(
                              color: isExpense ? Colors.red : Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () =>
                              context.push('/finance/transactions/${t.id}'),
                        ),
                      );
                    }),
                  ],
                );
              },
            );
          },
          loading: () =>
              const PullableCenter(child: CircularProgressIndicator()),
          error: (e, _) => PullableCenter(child: Text('Error: $e')),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/finance/transactions/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
