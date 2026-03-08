import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/finance_providers.dart';

class FinanceOverviewPage extends ConsumerWidget {
  const FinanceOverviewPage({super.key});

  static final _currencyFormat = NumberFormat.currency(
    symbol: '\u20AC',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthlySummaryProvider);
    final expenseByCategory = ref.watch(expenseByCategoryProvider);
    final totalAssets = ref.watch(totalAssetsValueProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance),
            tooltip: 'Assets',
            onPressed: () => context.push('/finance/assets'),
          ),
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: 'Categories',
            onPressed: () => context.push('/finance/categories'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Monthly summary cards
          summary.when(
            data: (s) => Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Income',
                        amount: s.totalIncome,
                        color: Colors.green,
                        icon: Icons.arrow_downward,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Expenses',
                        amount: s.totalExpense,
                        color: Colors.red,
                        icon: Icons.arrow_upward,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Net Savings',
                        amount: s.netSavings,
                        color: s.netSavings >= 0 ? Colors.green : Colors.red,
                        icon: Icons.savings,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: totalAssets.when(
                        data: (value) => _SummaryCard(
                          label: 'Total Assets',
                          amount: value,
                          color: theme.colorScheme.primary,
                          icon: Icons.account_balance_wallet,
                        ),
                        loading: () => const _SummaryCard(
                          label: 'Total Assets',
                          amount: 0,
                          color: Colors.grey,
                          icon: Icons.account_balance_wallet,
                        ),
                        error: (_, _) => const _SummaryCard(
                          label: 'Total Assets',
                          amount: 0,
                          color: Colors.grey,
                          icon: Icons.account_balance_wallet,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),

          const SizedBox(height: 24),

          // Expense breakdown pie chart
          Text('Expenses This Month', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          expenseByCategory.when(
            data: (data) {
              if (data.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No expenses this month')),
                  ),
                );
              }
              final total = data.values.fold<double>(0, (s, v) => s + v);
              final entries = data.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final colors = _chartColors;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sections: entries.asMap().entries.map((e) {
                              final i = e.key;
                              final entry = e.value;
                              return PieChartSectionData(
                                value: entry.value,
                                title:
                                    '${(entry.value / total * 100).toStringAsFixed(0)}%',
                                color: colors[i % colors.length],
                                radius: 60,
                                titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...entries.asMap().entries.map((e) {
                        final i = e.key;
                        final entry = e.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: colors[i % colors.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(entry.key)),
                              Text(_currencyFormat.format(entry.value)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),

          const SizedBox(height: 24),

          // Quick action buttons
          FilledButton.icon(
            onPressed: () => context.push('/finance/transactions'),
            icon: const Icon(Icons.list),
            label: const Text('All Transactions'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/finance/transactions/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  static const _chartColors = [
    Color(0xFF2196F3),
    Color(0xFFF44336),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFFF5722),
    Color(0xFF607D8B),
    Color(0xFFE91E63),
    Color(0xFF795548),
  ];
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              NumberFormat.currency(
                symbol: '\u20AC',
                decimalDigits: 2,
              ).format(amount),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
