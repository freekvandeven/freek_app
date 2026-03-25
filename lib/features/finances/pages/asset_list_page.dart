import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';

import '../models/finance_models.dart';
import '../providers/finance_providers.dart';

class AssetListPage extends ConsumerWidget {
  const AssetListPage({super.key});

  static final _currencyFormat = NumberFormat.currency(
    symbol: '\u20AC',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(assetListProvider);
    final totalValue = ref.watch(totalAssetsValueProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const QuickActionsTitle(child: Text('Assets'))),
      body: Column(
        children: [
          // Total value header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: theme.colorScheme.primaryContainer,
            child: Column(
              children: [
                Text('Total Value', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                totalValue.when(
                  data: (v) => Text(
                    _currencyFormat.format(v),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (_, _) => const Text('--'),
                ),
              ],
            ),
          ),

          // Asset list
          Expanded(
            child: assets.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text('No assets yet'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final asset = list[index];
                    return Dismissible(
                      key: Key(asset.id),
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
                          title: const Text('Delete Asset'),
                          content: Text('Delete "${asset.name}"?'),
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
                          .read(assetListProvider.notifier)
                          .deleteAsset(asset.id),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(_assetTypeIcon(asset.type)),
                        ),
                        title: Text(asset.name),
                        subtitle: Text(
                          asset.type.name[0].toUpperCase() +
                              asset.type.name.substring(1),
                        ),
                        trailing: Text(
                          _currencyFormat.format(asset.currentValue),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: () =>
                            context.push('/finance/assets/${asset.id}'),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/finance/assets/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  IconData _assetTypeIcon(AssetType type) {
    return switch (type) {
      AssetType.bankAccount => Icons.account_balance,
      AssetType.investment => Icons.trending_up,
      AssetType.cash => Icons.money,
      AssetType.crypto => Icons.currency_bitcoin,
      AssetType.other => Icons.account_balance_wallet,
    };
  }
}
