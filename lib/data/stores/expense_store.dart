import 'package:flutter/material.dart';

import '../../core/utils/date_x.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import 'persistence.dart';

class CategorySpend {
  CategorySpend(this.category, this.amount, this.share);
  final BudgetCategory category;
  final double amount;
  final double share; // 0..1 of total spend
}

class MerchantSpend {
  MerchantSpend(this.name, this.amount, this.count);
  final String name;
  final double amount;
  final int count;
}

/// Owns transactions and budgets (PRD 4.x).
class ExpenseStore extends ChangeNotifier {
  ExpenseStore() {
    if (!_load()) _seed();
  }

  static const String _key = 'expenses';

  final List<ExpenseTransaction> _txns = <ExpenseTransaction>[];
  final List<BudgetCategory> _categories = <BudgetCategory>[];

  bool _load() {
    final Map<String, dynamic>? j = Persistence.load(_key);
    if (j == null) return false;
    _txns.addAll((j['txns'] as List<dynamic>).map((dynamic t) =>
        ExpenseTransaction.fromJson(t as Map<String, dynamic>)));
    _categories.addAll((j['categories'] as List<dynamic>)
        .map((dynamic c) => BudgetCategory.fromJson(c as Map<String, dynamic>)));
    return true;
  }

  void _save() {
    Persistence.save(_key, <String, dynamic>{
      'txns': _txns.map((ExpenseTransaction t) => t.toJson()).toList(),
      'categories': _categories.map((BudgetCategory c) => c.toJson()).toList(),
    });
  }

  @override
  void notifyListeners() {
    _save();
    super.notifyListeners();
  }

  /// PRD 4.1 FR5 — one shared month context across all four tabs.
  DateTime _selectedMonth = startOfMonth(DateTime.now());
  DateTime get selectedMonth => _selectedMonth;

  void setMonth(DateTime m) {
    _selectedMonth = startOfMonth(m);
    notifyListeners();
  }

  void shiftMonth(int delta) {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    notifyListeners();
  }

  List<BudgetCategory> get categories =>
      List<BudgetCategory>.unmodifiable(_categories);

  BudgetCategory categoryById(String id) => _categories.firstWhere(
        (BudgetCategory c) => c.id == id,
        orElse: () => _categories.last,
      );

  List<ExpenseTransaction> get allTransactions =>
      List<ExpenseTransaction>.unmodifiable(_txns);

  List<ExpenseTransaction> transactionsIn(DateTime month) {
    final List<ExpenseTransaction> list = _txns
        .where((ExpenseTransaction t) =>
            t.date.year == month.year && t.date.month == month.month)
        .toList();
    list.sort((ExpenseTransaction a, ExpenseTransaction b) =>
        b.date.compareTo(a.date));
    return list;
  }

  List<ExpenseTransaction> get monthTransactions =>
      transactionsIn(_selectedMonth);

  List<ExpenseTransaction> transactionsOn(DateTime day) => _txns
      .where((ExpenseTransaction t) => isSameDay(t.date, day))
      .toList();

  // ---- totals ----------------------------------------------------------

  /// Spend counts only the user's own share of split transactions (PRD 4.4).
  double spendIn(DateTime month) => transactionsIn(month)
      .where((ExpenseTransaction t) => t.countsAsSpend)
      .fold<double>(0, (double s, ExpenseTransaction t) => s + t.ownShare);

  double incomeIn(DateTime month) => transactionsIn(month)
      .where((ExpenseTransaction t) => t.countsAsIncome)
      .fold<double>(0, (double s, ExpenseTransaction t) => s + t.amount);

  double get monthSpend => spendIn(_selectedMonth);
  double get monthIncome => incomeIn(_selectedMonth);

  /// PRD 4.1 AC2 — savings may legitimately be negative.
  double get monthSavings => monthIncome - monthSpend;

  double spendOn(DateTime day) => transactionsOn(day)
      .where((ExpenseTransaction t) => t.countsAsSpend)
      .fold<double>(0, (double s, ExpenseTransaction t) => s + t.ownShare);

  int transactionCountOn(DateTime day) => transactionsOn(day).length;

  double get totalBudget => _categories.fold<double>(
      0, (double s, BudgetCategory c) => s + (c.limit ?? 0));

  double spentInCategory(String categoryId, DateTime month) =>
      transactionsIn(month)
          .where((ExpenseTransaction t) =>
              t.countsAsSpend && t.categoryId == categoryId)
          .fold<double>(0, (double s, ExpenseTransaction t) => s + t.ownShare);

  /// Category breakdown sorted by spend desc (PRD 4.1 FR2 / AC1).
  List<CategorySpend> categoryBreakdown(DateTime month) {
    final double total = spendIn(month);
    final List<CategorySpend> list = _categories
        .map((BudgetCategory c) {
          final double amt = spentInCategory(c.id, month);
          return CategorySpend(c, amt, total == 0 ? 0 : amt / total);
        })
        .where((CategorySpend cs) => cs.amount > 0)
        .toList();
    list.sort((CategorySpend a, CategorySpend b) => b.amount.compareTo(a.amount));
    return list;
  }

  BudgetCategory? largestCategory(DateTime month) {
    final List<CategorySpend> b = categoryBreakdown(month);
    return b.isEmpty ? null : b.first.category;
  }

  bool isOverBudget(BudgetCategory c, DateTime month) {
    final double? lim = c.limit;
    if (lim == null || lim <= 0) return false;
    return spentInCategory(c.id, month) > lim;
  }

  List<BudgetCategory> overBudgetCategories(DateTime month) => _categories
      .where((BudgetCategory c) => isOverBudget(c, month))
      .toList();

  /// PRD 1.3 — budget adherence for the wellness composite.
  double budgetAdherence(DateTime month) {
    final List<BudgetCategory> budgeted = _categories
        .where((BudgetCategory c) => (c.limit ?? 0) > 0)
        .toList();
    if (budgeted.isEmpty) return 1;
    final int over = budgeted
        .where((BudgetCategory c) => isOverBudget(c, month))
        .length;
    return 1 - (over / budgeted.length);
  }

  // ---- analytics -------------------------------------------------------

  /// Trailing [months] monthly spend totals, oldest first (PRD 4.3).
  List<MapEntry<DateTime, double>> monthlyTrend({int months = 6}) {
    final List<MapEntry<DateTime, double>> out = <MapEntry<DateTime, double>>[];
    for (int i = months - 1; i >= 0; i--) {
      final DateTime m =
          DateTime(_selectedMonth.year, _selectedMonth.month - i, 1);
      out.add(MapEntry<DateTime, double>(m, spendIn(m)));
    }
    return out;
  }

  double averageMonthlySpend({int months = 6}) {
    final List<MapEntry<DateTime, double>> t = monthlyTrend(months: months);
    if (t.isEmpty) return 0;
    return t.fold<double>(0, (double s, MapEntry<DateTime, double> e) => s + e.value) /
        t.length;
  }

  /// PRD 4.3 AC2 — signed deviation vs. the trailing average.
  double deviationFromAverage() {
    final double avg = averageMonthlySpend();
    if (avg == 0) return 0;
    return (monthSpend - avg) / avg;
  }

  List<MerchantSpend> topMerchants(DateTime month, {int limit = 5}) {
    final Map<String, List<ExpenseTransaction>> byName =
        <String, List<ExpenseTransaction>>{};
    for (final ExpenseTransaction t in transactionsIn(month)) {
      if (!t.countsAsSpend) continue;
      byName.putIfAbsent(t.description, () => <ExpenseTransaction>[]).add(t);
    }
    final List<MerchantSpend> list = byName.entries
        .map((MapEntry<String, List<ExpenseTransaction>> e) => MerchantSpend(
              e.key,
              e.value.fold<double>(
                  0, (double s, ExpenseTransaction t) => s + t.ownShare),
              e.value.length,
            ))
        .toList();
    list.sort((MerchantSpend a, MerchantSpend b) => b.amount.compareTo(a.amount));
    return list.take(limit).toList();
  }

  /// Payment-method split; shares sum to 1 (PRD 4.3 AC3).
  Map<PaymentMethod, double> paymentMethodSplit(DateTime month) {
    final Map<PaymentMethod, double> out = <PaymentMethod, double>{};
    for (final ExpenseTransaction t in transactionsIn(month)) {
      if (!t.countsAsSpend) continue;
      out[t.method] = (out[t.method] ?? 0) + t.ownShare;
    }
    return out;
  }

  /// PRD 4.3 AC4 — export covers every transaction in the period, not top-N.
  String exportCsv(DateTime month) {
    final StringBuffer b = StringBuffer()
      ..writeln('Date,Type,Description,Category,Method,Amount,Split ways,Own share,Note');
    for (final ExpenseTransaction t in transactionsIn(month)) {
      final String cat = categoryById(t.categoryId).name;
      b.writeln('${t.date.toIso8601String()},${t.type.label},'
          '"${t.description}",$cat,${t.method.label},'
          '${t.amount.toStringAsFixed(2)},${t.splitWays},'
          '${t.ownShare.toStringAsFixed(2)},"${t.note}"');
    }
    return b.toString();
  }

  // ---- mutations -------------------------------------------------------

  void add(ExpenseTransaction t) {
    _txns.add(t);
    notifyListeners();
  }

  void update(ExpenseTransaction t) {
    final int i = _txns.indexWhere((ExpenseTransaction x) => x.id == t.id);
    if (i >= 0) _txns[i] = t;
    notifyListeners();
  }

  void delete(String id) {
    _txns.removeWhere((ExpenseTransaction t) => t.id == id);
    notifyListeners();
  }

  void addCategory(BudgetCategory c) {
    _categories.add(c);
    notifyListeners();
  }

  void updateCategory(BudgetCategory c) {
    final int i = _categories.indexWhere((BudgetCategory x) => x.id == c.id);
    if (i >= 0) _categories[i] = c;
    notifyListeners();
  }

  void setCategoryLimit(String id, int? limitPaise) {
    final int i = _categories.indexWhere((BudgetCategory c) => c.id == id);
    if (i >= 0) _categories[i].limitPaise = limitPaise;
    notifyListeners();
  }

  // ---- seed ------------------------------------------------------------

  void _seed() {
    _categories.addAll(<BudgetCategory>[
      BudgetCategory(
          id: 'cat_housing',
          name: 'Housing',
          colorValue: 0xFF0F6E56,
          iconCodePoint: Icons.home_outlined.codePoint,
          limitPaise: 900000),
      BudgetCategory(
          id: 'cat_food',
          name: 'Food & dining',
          colorValue: 0xFF854F0B,
          iconCodePoint: Icons.restaurant_outlined.codePoint,
          limitPaise: 500000),
      BudgetCategory(
          id: 'cat_health',
          name: 'Health',
          colorValue: 0xFF534AB7,
          iconCodePoint: Icons.medical_services_outlined.codePoint,
          limitPaise: 200000),
      BudgetCategory(
          id: 'cat_transport',
          name: 'Transport',
          colorValue: 0xFF185FA5,
          iconCodePoint: Icons.directions_car_outlined.codePoint,
          limitPaise: 500000),
      BudgetCategory(
          id: 'cat_income',
          name: 'Income',
          colorValue: 0xFF3B6D11,
          iconCodePoint: Icons.account_balance_outlined.codePoint),
      BudgetCategory(
          id: 'cat_other',
          name: 'Others',
          colorValue: 0xFF888780,
          iconCodePoint: Icons.more_horiz.codePoint,
          limitPaise: 200000),
    ]);

    final DateTime now = DateTime.now();
    final DateTime m = startOfMonth(now);

    void tx(String id, TransactionType type, int paise, String desc, String cat,
        int dayOfMonth, PaymentMethod pm,
        {int split = 1, int monthOffset = 0}) {
      final DateTime base = DateTime(m.year, m.month + monthOffset, 1);
      final int maxDay = DateTime(base.year, base.month + 1, 0).day;
      _txns.add(ExpenseTransaction(
        id: id,
        type: type,
        amountPaise: paise,
        description: desc,
        categoryId: cat,
        date: DateTime(base.year, base.month,
            dayOfMonth > maxDay ? maxDay : dayOfMonth, 9, 14),
        method: pm,
        splitWays: split,
      ));
    }

    // Current month
    tx('t1', TransactionType.income, 6500000, 'Salary credit', 'cat_income', 1,
        PaymentMethod.netBanking);
    tx('t2', TransactionType.expense, 900000, 'Rent', 'cat_housing', 2,
        PaymentMethod.netBanking);
    tx('t3', TransactionType.expense, 38000, 'Starbucks', 'cat_food',
        now.day, PaymentMethod.card);
    tx('t4', TransactionType.expense, 22000, 'Ola cab', 'cat_transport',
        now.day > 1 ? now.day - 1 : 1, PaymentMethod.upi);
    tx('t5', TransactionType.expense, 80000, 'Dr. Mehta consultation',
        'cat_health', 3, PaymentMethod.upi);
    tx('t6', TransactionType.expense, 160000, 'Dr. Mehta', 'cat_health', 8,
        PaymentMethod.upi);
    tx('t7', TransactionType.expense, 220000, 'Big Basket', 'cat_food', 5,
        PaymentMethod.card);
    tx('t8', TransactionType.expense, 160000, 'Transport top-up',
        'cat_transport', 6, PaymentMethod.upi);
    tx('t9', TransactionType.expense, 110000, 'Household items', 'cat_other', 7,
        PaymentMethod.cash);
    tx('t10', TransactionType.expense, 240000, 'Team dinner (split 4)',
        'cat_food', 9, PaymentMethod.card, split: 4);

    // Prior months for the 6-month trend
    for (int i = 1; i <= 5; i++) {
      final int base = 1400000 + (i * 90000);
      tx('p${i}a', TransactionType.expense, 900000, 'Rent', 'cat_housing', 2,
          PaymentMethod.netBanking, monthOffset: -i);
      tx('p${i}b', TransactionType.expense, base ~/ 3, 'Groceries', 'cat_food',
          10, PaymentMethod.card, monthOffset: -i);
      tx('p${i}c', TransactionType.expense, base ~/ 6, 'Fuel', 'cat_transport',
          15, PaymentMethod.upi, monthOffset: -i);
      tx('p${i}d', TransactionType.income, 6500000, 'Salary credit',
          'cat_income', 1, PaymentMethod.netBanking, monthOffset: -i);
    }
  }
}
