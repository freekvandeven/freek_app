import 'package:uuid/uuid.dart';

class FinancialTransaction {
  final String id;
  final String title;
  final String? description;
  final double amount;
  final TransactionType type;
  final String? categoryId;
  final DateTime date;
  final bool isRecurring;
  final String? recurringType;
  final int? recurringInterval;
  final DateTime? recurringEndDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  FinancialTransaction({
    String? id,
    required this.title,
    this.description,
    required this.amount,
    required this.type,
    this.categoryId,
    required this.date,
    this.isRecurring = false,
    this.recurringType,
    this.recurringInterval,
    this.recurringEndDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  FinancialTransaction copyWith({
    String? title,
    String? description,
    double? amount,
    TransactionType? type,
    String? categoryId,
    DateTime? date,
    bool? isRecurring,
    String? recurringType,
    int? recurringInterval,
    DateTime? recurringEndDate,
    bool clearDescription = false,
    bool clearCategoryId = false,
    bool clearRecurringType = false,
    bool clearRecurringEndDate = false,
  }) {
    return FinancialTransaction(
      id: id,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      date: date ?? this.date,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringType: clearRecurringType
          ? null
          : (recurringType ?? this.recurringType),
      recurringInterval: recurringInterval ?? this.recurringInterval,
      recurringEndDate: clearRecurringEndDate
          ? null
          : (recurringEndDate ?? this.recurringEndDate),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'amount': amount,
    'type': type.name,
    'categoryId': categoryId,
    'date': date.toIso8601String(),
    'isRecurring': isRecurring,
    'recurringType': recurringType,
    'recurringInterval': recurringInterval,
    'recurringEndDate': recurringEndDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory FinancialTransaction.fromMap(Map<String, dynamic> map) {
    return FinancialTransaction(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      amount: (map['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.name == (map['type'] as String),
      ),
      categoryId: map['categoryId'] as String?,
      date: DateTime.parse(map['date'] as String),
      isRecurring: map['isRecurring'] as bool? ?? false,
      recurringType: map['recurringType'] as String?,
      recurringInterval: map['recurringInterval'] as int?,
      recurringEndDate: map['recurringEndDate'] != null
          ? DateTime.parse(map['recurringEndDate'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

enum TransactionType { income, expense }

class FinancialCategory {
  final String id;
  final String name;
  final TransactionType type;
  final String? icon;
  final String? color;
  final DateTime createdAt;

  FinancialCategory({
    String? id,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  FinancialCategory copyWith({
    String? name,
    TransactionType? type,
    String? icon,
    String? color,
  }) {
    return FinancialCategory(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type.name,
    'icon': icon,
    'color': color,
    'createdAt': createdAt.toIso8601String(),
  };

  factory FinancialCategory.fromMap(Map<String, dynamic> map) {
    return FinancialCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      type: TransactionType.values.firstWhere(
        (e) => e.name == (map['type'] as String),
      ),
      icon: map['icon'] as String?,
      color: map['color'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

enum AssetType { bankAccount, investment, cash, crypto, other }

class FinancialAsset {
  final String id;
  final String name;
  final AssetType type;
  final double currentValue;
  final String currency;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  FinancialAsset({
    String? id,
    required this.name,
    required this.type,
    required this.currentValue,
    this.currency = 'EUR',
    this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  FinancialAsset copyWith({
    String? name,
    AssetType? type,
    double? currentValue,
    String? currency,
    String? description,
    bool clearDescription = false,
  }) {
    return FinancialAsset(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      currentValue: currentValue ?? this.currentValue,
      currency: currency ?? this.currency,
      description: clearDescription ? null : (description ?? this.description),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type.name,
    'currentValue': currentValue,
    'currency': currency,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory FinancialAsset.fromMap(Map<String, dynamic> map) {
    return FinancialAsset(
      id: map['id'] as String,
      name: map['name'] as String,
      type: AssetType.values.firstWhere(
        (e) => e.name == (map['type'] as String),
      ),
      currentValue: (map['currentValue'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'EUR',
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

final defaultExpenseCategories = [
  FinancialCategory(
    name: 'Groceries',
    type: TransactionType.expense,
    icon: 'shopping_cart',
  ),
  FinancialCategory(name: 'Rent', type: TransactionType.expense, icon: 'home'),
  FinancialCategory(
    name: 'Transport',
    type: TransactionType.expense,
    icon: 'directions_car',
  ),
  FinancialCategory(
    name: 'Entertainment',
    type: TransactionType.expense,
    icon: 'movie',
  ),
  FinancialCategory(
    name: 'Dining',
    type: TransactionType.expense,
    icon: 'restaurant',
  ),
  FinancialCategory(
    name: 'Health',
    type: TransactionType.expense,
    icon: 'local_hospital',
  ),
  FinancialCategory(
    name: 'Utilities',
    type: TransactionType.expense,
    icon: 'bolt',
  ),
  FinancialCategory(
    name: 'Shopping',
    type: TransactionType.expense,
    icon: 'shopping_bag',
  ),
  FinancialCategory(
    name: 'Other',
    type: TransactionType.expense,
    icon: 'more_horiz',
  ),
];

final defaultIncomeCategories = [
  FinancialCategory(name: 'Salary', type: TransactionType.income, icon: 'work'),
  FinancialCategory(
    name: 'Freelance',
    type: TransactionType.income,
    icon: 'laptop',
  ),
  FinancialCategory(
    name: 'Investment',
    type: TransactionType.income,
    icon: 'trending_up',
  ),
  FinancialCategory(
    name: 'Other',
    type: TransactionType.income,
    icon: 'more_horiz',
  ),
];
