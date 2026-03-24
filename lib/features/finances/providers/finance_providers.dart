import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';
import '../services/firestore_finance_service.dart';

final financeServiceProvider = Provider<FinanceService>((ref) {
  if (AppConfig.useFirebase) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return FirestoreFinanceService(userId);
  }
  return MockFinanceService();
});

// === Transactions ===

class TransactionListNotifier
    extends AsyncNotifier<List<FinancialTransaction>> {
  @override
  Future<List<FinancialTransaction>> build() async {
    return ref.watch(financeServiceProvider).getTransactions();
  }

  Future<void> addTransaction(FinancialTransaction transaction) async {
    await ref.read(financeServiceProvider).addTransaction(transaction);
    ref.invalidateSelf();
  }

  Future<void> updateTransaction(FinancialTransaction transaction) async {
    await ref.read(financeServiceProvider).updateTransaction(transaction);
    ref.invalidateSelf();
  }

  Future<void> deleteTransaction(String id) async {
    await ref.read(financeServiceProvider).deleteTransaction(id);
    ref.invalidateSelf();
  }
}

final transactionListProvider =
    AsyncNotifierProvider<TransactionListNotifier, List<FinancialTransaction>>(
      TransactionListNotifier.new,
    );

enum TransactionTypeFilter { all, income, expense }

final transactionTypeFilterProvider = StateProvider<TransactionTypeFilter>(
  (_) => TransactionTypeFilter.all,
);

final transactionCategoryFilterProvider = StateProvider<String?>((_) => null);

final transactionDateRangeProvider = StateProvider<DateRange?>((_) => null);

class DateRange {
  final DateTime start;
  final DateTime end;
  DateRange(this.start, this.end);
}

final filteredTransactionsProvider =
    Provider<AsyncValue<List<FinancialTransaction>>>((ref) {
      final transactions = ref.watch(transactionListProvider);
      final typeFilter = ref.watch(transactionTypeFilterProvider);
      final categoryFilter = ref.watch(transactionCategoryFilterProvider);
      final dateRange = ref.watch(transactionDateRangeProvider);

      return transactions.whenData((list) {
        var filtered = list;

        if (typeFilter != TransactionTypeFilter.all) {
          final type = typeFilter == TransactionTypeFilter.income
              ? TransactionType.income
              : TransactionType.expense;
          filtered = filtered.where((t) => t.type == type).toList();
        }

        if (categoryFilter != null) {
          filtered = filtered
              .where((t) => t.categoryId == categoryFilter)
              .toList();
        }

        if (dateRange != null) {
          filtered = filtered
              .where(
                (t) =>
                    !t.date.isBefore(dateRange.start) &&
                    !t.date.isAfter(dateRange.end),
              )
              .toList();
        }

        return filtered;
      });
    });

// Monthly summary
final monthlySummaryProvider = Provider<AsyncValue<MonthlySummary>>((ref) {
  final transactions = ref.watch(transactionListProvider);
  return transactions.whenData((list) {
    final now = DateTime.now();
    final thisMonth = list.where(
      (t) => t.date.year == now.year && t.date.month == now.month,
    );

    double totalIncome = 0;
    double totalExpense = 0;
    for (final t in thisMonth) {
      if (t.type == TransactionType.income) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }

    return MonthlySummary(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netSavings: totalIncome - totalExpense,
    );
  });
});

class MonthlySummary {
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  MonthlySummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
  });
}

// Expense by category
final expenseByCategoryProvider = Provider<AsyncValue<Map<String, double>>>((
  ref,
) {
  final transactions = ref.watch(transactionListProvider);
  final categories = ref.watch(categoryListProvider);

  return transactions.whenData((list) {
    final catList = categories.valueOrNull ?? [];
    final now = DateTime.now();
    final thisMonth = list.where(
      (t) =>
          t.type == TransactionType.expense &&
          t.date.year == now.year &&
          t.date.month == now.month,
    );

    final Map<String, double> result = {};
    for (final t in thisMonth) {
      final catName =
          catList
              .where((c) => c.id == t.categoryId)
              .map((c) => c.name)
              .firstOrNull ??
          'Uncategorized';
      result[catName] = (result[catName] ?? 0) + t.amount;
    }
    return result;
  });
});

// === Categories ===

class CategoryListNotifier extends AsyncNotifier<List<FinancialCategory>> {
  @override
  Future<List<FinancialCategory>> build() async {
    return ref.watch(financeServiceProvider).getCategories();
  }

  Future<void> addCategory(FinancialCategory category) async {
    await ref.read(financeServiceProvider).addCategory(category);
    ref.invalidateSelf();
  }

  Future<void> updateCategory(FinancialCategory category) async {
    await ref.read(financeServiceProvider).updateCategory(category);
    ref.invalidateSelf();
  }

  Future<void> deleteCategory(String id) async {
    await ref.read(financeServiceProvider).deleteCategory(id);
    ref.invalidateSelf();
  }
}

final categoryListProvider =
    AsyncNotifierProvider<CategoryListNotifier, List<FinancialCategory>>(
      CategoryListNotifier.new,
    );

// === Assets ===

class AssetListNotifier extends AsyncNotifier<List<FinancialAsset>> {
  @override
  Future<List<FinancialAsset>> build() async {
    return ref.watch(financeServiceProvider).getAssets();
  }

  Future<void> addAsset(FinancialAsset asset) async {
    await ref.read(financeServiceProvider).addAsset(asset);
    ref.invalidateSelf();
  }

  Future<void> updateAsset(FinancialAsset asset) async {
    await ref.read(financeServiceProvider).updateAsset(asset);
    ref.invalidateSelf();
  }

  Future<void> deleteAsset(String id) async {
    await ref.read(financeServiceProvider).deleteAsset(id);
    ref.invalidateSelf();
  }
}

final assetListProvider =
    AsyncNotifierProvider<AssetListNotifier, List<FinancialAsset>>(
      AssetListNotifier.new,
    );

final totalAssetsValueProvider = Provider<AsyncValue<double>>((ref) {
  return ref
      .watch(assetListProvider)
      .whenData(
        (assets) => assets.fold<double>(0, (sum, a) => sum + a.currentValue),
      );
});
