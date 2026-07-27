import 'package:flutter/material.dart';
import 'enums.dart';

/// A single money movement (PRD 4.4).
class ExpenseTransaction {
  ExpenseTransaction({
    required this.id,
    required this.type,
    required this.amountPaise,
    required this.description,
    required this.categoryId,
    required this.date,
    this.method = PaymentMethod.upi,
    this.tags = const <String>[],
    this.note = '',
    this.receiptPath,
    this.splitWays = 1,
    this.transferToAccount,
    this.recurringCycle,
  });

  final String id;
  TransactionType type;

  /// Stored in paise (integer) to avoid floating-point currency errors.
  int amountPaise;
  String description;
  String categoryId;
  DateTime date;
  PaymentMethod method;
  List<String> tags;
  String note;
  String? receiptPath;

  /// PRD 4.4 — with a split, only the user's own share counts toward budgets.
  int splitWays;

  /// Only for TransactionType.transfer (closes PRD Gap 7).
  String? transferToAccount;

  /// Only for TransactionType.recurring (closes PRD Gap 7).
  BillingCycle? recurringCycle;

  double get amount => amountPaise / 100.0;

  /// The portion attributable to this user's own budget.
  double get ownShare => amount / (splitWays <= 0 ? 1 : splitWays);
  int get ownSharePaise => (amountPaise / (splitWays <= 0 ? 1 : splitWays)).round();

  bool get isSplit => splitWays > 1;

  /// Transfers move money between the user's own accounts, so they must never
  /// count as spending or income in totals.
  bool get countsAsSpend =>
      type == TransactionType.expense || type == TransactionType.recurring;
  bool get countsAsIncome => type == TransactionType.income;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.index,
        'amountPaise': amountPaise,
        'description': description,
        'categoryId': categoryId,
        'date': date.toIso8601String(),
        'method': method.index,
        'tags': tags,
        'note': note,
        'receiptPath': receiptPath,
        'splitWays': splitWays,
        'transferToAccount': transferToAccount,
        'recurringCycle': recurringCycle?.index,
      };

  factory ExpenseTransaction.fromJson(Map<String, dynamic> j) =>
      ExpenseTransaction(
        id: j['id'] as String,
        type: TransactionType.values[j['type'] as int],
        amountPaise: j['amountPaise'] as int,
        description: j['description'] as String,
        categoryId: j['categoryId'] as String,
        date: DateTime.parse(j['date'] as String),
        method: PaymentMethod.values[j['method'] as int? ?? 0],
        tags: (j['tags'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
        note: j['note'] as String? ?? '',
        receiptPath: j['receiptPath'] as String?,
        splitWays: j['splitWays'] as int? ?? 1,
        transferToAccount: j['transferToAccount'] as String?,
        recurringCycle: j['recurringCycle'] == null
            ? null
            : BillingCycle.values[j['recurringCycle'] as int],
      );
}

/// A spending category with an optional monthly budget limit (PRD 4.2).
class BudgetCategory {
  BudgetCategory({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconCodePoint,
    this.limitPaise,
  });

  final String id;
  String name;
  int colorValue;
  int iconCodePoint;

  /// Null means "tracked but not budgeted".
  int? limitPaise;

  Color get color => Color(colorValue);
  // ignore: non_const_argument_for_const_parameter
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  double? get limit => limitPaise == null ? null : limitPaise! / 100.0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'iconCodePoint': iconCodePoint,
        'limitPaise': limitPaise,
      };

  factory BudgetCategory.fromJson(Map<String, dynamic> j) => BudgetCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        colorValue: j['colorValue'] as int,
        iconCodePoint: j['iconCodePoint'] as int,
        limitPaise: j['limitPaise'] as int?,
      );
}
