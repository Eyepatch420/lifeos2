import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/share_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_header.dart';
import '../../data/models/enums.dart';
import '../../data/models/expense.dart';
import '../../data/stores/expense_store.dart';
import 'add_transaction_sheet.dart';

/// PRD 4.1-4.3 — Expenses with Overview / Transactions / Budgets / Analytics,
/// all four sharing one selected-month context (4.1 FR5).
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  int _tab = 0;
  static const List<String> _tabs = <String>[
    'Overview',
    'Transactions',
    'Budgets',
    'Analytics'
  ];

  @override
  Widget build(BuildContext context) {
    final ExpenseStore store = context.watch<ExpenseStore>();
    final DateTime month = store.selectedMonth;

    return Scaffold(
      body: Column(
        children: <Widget>[
          ModuleHeader(
            color: AppColors.expenses,
            title: 'Expenses',
            actions: <Widget>[
              HeaderIconButton(
                icon: Icons.download_outlined,
                tooltip: 'Export CSV',
                onPressed: () => _export(store),
              ),
            ],
            hero: _hero(context, store, month),
            bottomPadding: 10,
          ),
          Container(
            color: AppColors.expenses,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: HeaderSegments(
              items: _tabs,
              selected: _tab,
              color: AppColors.expenses,
              onSelected: (int i) => setState(() => _tab = i),
            ),
          ),
          Expanded(
            child: switch (_tab) {
              1 => _transactionsTab(context, store, month),
              2 => _budgetsTab(context, store, month),
              3 => _analyticsTab(context, store, month),
              _ => _overviewTab(context, store, month),
            },
          ),
          _monthBar(context, store, month),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.expenses,
        tooltip: 'Add transaction',
        onPressed: () => AddTransactionSheet.show(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _hero(BuildContext context, ExpenseStore store, DateTime month) {
    final double spend = store.monthSpend;
    final double budget = store.totalBudget;
    final double income = store.monthIncome;
    final double savings = store.monthSavings;
    final BudgetCategory? largest = store.largestCategory(month);
    final DateTime now = DateTime.now();
    final bool isCurrentMonth =
        month.year == now.year && month.month == now.month;
    final int daysLeft = isCurrentMonth ? daysLeftInMonth(now) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${fmtMonthYear.format(month)} · spent so far',
          style: TextStyle(
              fontSize: 11.5, color: Colors.white.withValues(alpha: 0.65)),
        ),
        const SizedBox(height: 2),
        Text(
          formatRupees(spend),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          budget > 0
              ? 'of ${formatRupees(budget)} budget'
                  '${isCurrentMonth ? ' · $daysLeft days left' : ''}'
              : 'No budget set',
          style: TextStyle(
              fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: HeaderStat(
                  label: 'Income', value: formatRupeesCompact(income)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HeaderStat(
                label: 'Savings',
                value: formatRupeesCompact(savings),
                // PRD 4.1 AC4 — negative savings styled distinctly.
                valueColor:
                    savings < 0 ? const Color(0xFFF09595) : Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HeaderStat(label: 'Largest', value: largest?.name ?? '—'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _monthBar(BuildContext context, ExpenseStore store, DateTime month) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(top: BorderSide(color: context.hairline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous month',
              onPressed: () => store.shiftMonth(-1),
            ),
            Expanded(
              child: Center(
                child: Text(
                  fmtMonthYear.format(month),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.txtPrimary,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next month',
              onPressed: () => store.shiftMonth(1),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Overview (PRD 4.1) ------------------------------------------------

  Widget _overviewTab(
      BuildContext context, ExpenseStore store, DateTime month) {
    final List<CategorySpend> breakdown = store.categoryBreakdown(month);
    final List<ExpenseTransaction> recent =
        store.transactionsIn(month).take(6).toList();

    if (store.transactionsIn(month).isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions in ${fmtMonthYear.format(month)}',
        message: 'Add one with the + button, or switch months below.',
        actionLabel: 'Add transaction',
        onAction: () => AddTransactionSheet.show(context),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      children: <Widget>[
        SectionLabel('By category',
            trailing: 'See all', onTrailingTap: () => setState(() => _tab = 2)),
        AppCard(
          child: Column(
            children: <Widget>[
              for (int i = 0; i < breakdown.length; i++) ...<Widget>[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: breakdown[i].category.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              breakdown[i].category.name,
                              style: TextStyle(
                                  fontSize: 13, color: context.txtPrimary),
                            ),
                            Text(
                              '${(breakdown[i].share * 100).round()}% of spend',
                              style: TextStyle(
                                  fontSize: 11.5, color: context.txtSecondary),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        child: ThinProgressBar(
                          value: breakdown.first.amount == 0
                              ? 0
                              : breakdown[i].amount / breakdown.first.amount,
                          color: breakdown[i].category.color,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 62,
                        child: Text(
                          formatRupees(breakdown[i].amount),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.txtPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != breakdown.length - 1)
                  Divider(height: 1, color: context.hairline),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionLabel('Recent',
            trailing: 'All transactions',
            onTrailingTap: () => setState(() => _tab = 1)),
        AppCard(
          child: Column(
            children: <Widget>[
              for (int i = 0; i < recent.length; i++) ...<Widget>[
                _txnRow(context, store, recent[i]),
                if (i != recent.length - 1)
                  Divider(height: 1, color: context.hairline),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ---- Transactions ------------------------------------------------------

  Widget _transactionsTab(
      BuildContext context, ExpenseStore store, DateTime month) {
    final List<ExpenseTransaction> txns = store.transactionsIn(month);
    if (txns.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions',
        message: 'Nothing recorded for ${fmtMonthYear.format(month)}.',
        actionLabel: 'Add transaction',
        onAction: () => AddTransactionSheet.show(context),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      children: <Widget>[
        SectionLabel('${txns.length} transactions'),
        AppCard(
          child: Column(
            children: <Widget>[
              for (int i = 0; i < txns.length; i++) ...<Widget>[
                _txnRow(context, store, txns[i]),
                if (i != txns.length - 1)
                  Divider(height: 1, color: context.hairline),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _txnRow(
      BuildContext context, ExpenseStore store, ExpenseTransaction t) {
    final BudgetCategory cat = store.categoryById(t.categoryId);
    final bool isIncome = t.countsAsIncome;
    final bool isTransfer = t.type == TransactionType.transfer;

    return Dismissible(
      key: ValueKey<String>('txn_${t.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.dangerBright,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final bool ok = await confirmDialog(
          context,
          title: 'Delete this transaction?',
          message: '${t.description} · ${formatRupees(t.amount)}. '
              'This cannot be undone.',
        );
        if (ok) store.delete(t.id);
        return false;
      },
      child: InkWell(
        onTap: () => AddTransactionSheet.show(context, existing: t),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: <Widget>[
              IconTile(icon: cat.icon, color: cat.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      t.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.txtPrimary,
                      ),
                    ),
                    Text(
                      isTransfer
                          ? 'Transfer → ${t.transferToAccount ?? ''}'
                          : cat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5, color: context.txtSecondary),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: <Widget>[
                        StatusChip.tone(t.method.label, ChipTone.neutral),
                        if (t.isSplit)
                          StatusChip.tone(
                              'Split ${t.splitWays} ways', ChipTone.info),
                        if (t.type == TransactionType.recurring)
                          StatusChip.tone(
                              t.recurringCycle?.label ?? 'Recurring',
                              ChipTone.purple),
                        for (final String tag in t.tags)
                          StatusChip.tone(tag, ChipTone.neutral),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '${isIncome ? '+' : (isTransfer ? '' : '−')}'
                    '${formatRupees(t.amount)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isIncome
                          ? AppColors.successText
                          : (isTransfer
                              ? context.txtSecondary
                              : AppColors.danger),
                    ),
                  ),
                  if (t.isSplit)
                    Text(
                      'yours ${formatRupees(t.ownShare)}',
                      style:
                          TextStyle(fontSize: 10, color: context.txtTertiary),
                    ),
                  Text(
                    relativeDayLabel(t.date, DateTime.now()),
                    style:
                        TextStyle(fontSize: 10.5, color: context.txtTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Budgets (PRD 4.2) -------------------------------------------------

  Widget _budgetsTab(BuildContext context, ExpenseStore store, DateTime month) {
    final List<BudgetCategory> cats = store.categories
        .where((BudgetCategory c) => (c.limitPaise ?? 0) > 0)
        .toList();
    final List<BudgetCategory> over = store.overBudgetCategories(month);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      children: <Widget>[
        AppCard(
          child: Column(
            children: <Widget>[
              for (int i = 0; i < cats.length; i++) ...<Widget>[
                _budgetRow(context, store, cats[i], month),
                if (i != cats.length - 1)
                  Divider(height: 1, color: context.hairline),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        // PRD 4.2 FR2 — persistent banner while any category is at/over limit.
        for (final BudgetCategory c in over)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InfoBanner(
              tone: ChipTone.danger,
              icon: Icons.error_outline,
              title: '${c.name} budget exceeded',
              text: 'Over by '
                  '${formatRupees(store.spentInCategory(c.id, month) - (c.limit ?? 0))}. '
                  'Tap to adjust the budget or review spend.',
              onTap: () => _editLimit(context, store, c),
            ),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => _addCategory(context, store),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add budget category'),
        ),
      ],
    );
  }

  Widget _budgetRow(BuildContext context, ExpenseStore store, BudgetCategory c,
      DateTime month) {
    final double spent = store.spentInCategory(c.id, month);
    final double limit = c.limit ?? 0;
    final double ratio = limit == 0 ? 0 : spent / limit;
    final bool isOver = spent > limit;
    final bool isFull = (spent - limit).abs() < 0.005;
    final DateTime now = DateTime.now();
    final bool currentMonth =
        month.year == now.year && month.month == now.month;

    final Color barColor = isOver
        ? AppColors.dangerBright
        : (ratio >= 0.85 ? AppColors.warning : c.color);

    return InkWell(
      onTap: () => _editLimit(context, store, c),
      onLongPress: () => _categoryMenu(context, store, c),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            IconTile(icon: c.icon, color: c.color, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    c.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.txtPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  ThinProgressBar(value: ratio, color: barColor),
                  const SizedBox(height: 4),
                  Text(
                    // PRD 4.2 AC1/AC2 — "full" at exactly 100%, else over-by.
                    isOver
                        ? '${formatRupees(spent)} of ${formatRupees(limit)} · over by ${formatRupees(spent - limit)}'
                        : isFull
                            ? '${formatRupees(spent)} of ${formatRupees(limit)} · full'
                            : '${formatRupees(spent)} of ${formatRupees(limit)}'
                                '${currentMonth ? ' · ${daysLeftInMonth(now)} days left' : ''}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isOver ? AppColors.danger : context.txtSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  formatRupees(spent),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isOver ? AppColors.danger : context.txtPrimary,
                  ),
                ),
                Text(
                  'limit ${formatRupees(limit)}',
                  style: TextStyle(fontSize: 10.5, color: context.txtTertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- Analytics (PRD 4.3) -----------------------------------------------

  Widget _analyticsTab(
      BuildContext context, ExpenseStore store, DateTime month) {
    final List<MapEntry<DateTime, double>> trend = store.monthlyTrend();
    final double maxVal = trend.fold<double>(0,
        (double m, MapEntry<DateTime, double> e) => e.value > m ? e.value : m);
    final double avg = store.averageMonthlySpend();
    final double dev = store.deviationFromAverage();
    final List<MerchantSpend> merchants = store.topMerchants(month);
    final Map<PaymentMethod, double> methods = store.paymentMethodSplit(month);
    final double methodTotal =
        methods.values.fold<double>(0, (double s, double v) => s + v);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      children: <Widget>[
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '6-month trend',
                style: TextStyle(fontSize: 11.5, color: context.txtSecondary),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    formatRupees(avg),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: context.txtPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      'avg/month',
                      style:
                          TextStyle(fontSize: 12, color: context.txtSecondary),
                    ),
                  ),
                ],
              ),
              Text(
                dev == 0
                    ? 'This month is on the average'
                    : 'This month ${(dev.abs() * 100).round()}% '
                        '${dev > 0 ? 'above' : 'below'} average',
                style: TextStyle(
                  fontSize: 12,
                  color: dev > 0 ? AppColors.danger : AppColors.successText,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 96,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    for (final MapEntry<DateTime, double> e in trend)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                formatRupeesCompact(e.value),
                                style: TextStyle(
                                    fontSize: 8.5, color: context.txtTertiary),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                height: maxVal == 0
                                    ? 2
                                    : (e.value / maxVal * 60).clamp(2, 60),
                                decoration: BoxDecoration(
                                  color: e.key.month == month.month &&
                                          e.key.year == month.year
                                      ? AppColors.expenses
                                      : const Color(0xFF9FE1CB),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(3)),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                fmtMonthShort.format(e.key),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: e.key.month == month.month
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: e.key.month == month.month
                                      ? AppColors.expenses
                                      : context.txtTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const SectionLabel('Top merchants'),
        if (merchants.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.storefront_outlined,
              title: 'No spending yet',
              message: 'Merchant ranking appears once you log expenses.',
            ),
          )
        else
          AppCard(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < merchants.length; i++) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 22,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.txtTertiary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                merchants[i].name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.txtPrimary),
                              ),
                              Text(
                                '${merchants[i].count} transaction'
                                '${merchants[i].count == 1 ? '' : 's'}',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: context.txtSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatRupees(merchants[i].amount),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: context.txtPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i != merchants.length - 1)
                    Divider(height: 1, color: context.hairline),
                ],
              ],
            ),
          ),
        const SizedBox(height: 14),
        const SectionLabel('Payment methods'),
        AppCard(
          padding: const EdgeInsets.all(12),
          child: methodTotal == 0
              ? Text('No spending recorded',
                  style: TextStyle(fontSize: 12.5, color: context.txtSecondary))
              : Row(
                  children: <Widget>[
                    for (final PaymentMethod m in methods.keys) ...<Widget>[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10),
                          decoration: BoxDecoration(
                            color: context.fieldColor,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Column(
                            children: <Widget>[
                              Text(m.label,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: context.txtSecondary)),
                              const SizedBox(height: 3),
                              Text(
                                '${((methods[m] ?? 0) / methodTotal * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: context.txtPrimary,
                                ),
                              ),
                              Text(
                                formatRupeesCompact(methods[m] ?? 0),
                                style: TextStyle(
                                    fontSize: 11, color: context.txtSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (m != methods.keys.last) const SizedBox(width: 8),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => _export(store),
          icon: const Icon(Icons.file_download_outlined, size: 18),
          label: const Text('Export CSV'),
        ),
      ],
    );
  }

  // ---- actions -----------------------------------------------------------

  void _export(ExpenseStore store) {
    // PRD 4.3 AC4 — export contains EVERY transaction in the period.
    final String csv = store.exportCsv(store.selectedMonth);
    final int rows = csv.trim().split('\n').length - 1;
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Export ${fmtMonthYear.format(store.selectedMonth)}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('$rows transactions ready to export.',
                  style: const TextStyle(fontSize: 13.5)),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ctx.fieldColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(csv,
                      style: const TextStyle(
                          fontSize: 10, fontFamily: 'monospace')),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Writes a real file and hands it to the system share sheet.
              final String name =
                  'lifeos-expenses-${fmtMonthKey.format(store.selectedMonth)}.csv';
              try {
                await ShareService.shareAsFile(csv, name,
                    subject: 'LifeOS expenses');
              } catch (e) {
                if (context.mounted) {
                  showSnack(context, 'Could not export: $e');
                }
              }
            },
            child: const Text('Export file'),
          ),
        ],
      ),
    );
  }

  Future<void> _editLimit(
      BuildContext context, ExpenseStore store, BudgetCategory c) async {
    final TextEditingController ctl =
        TextEditingController(text: (c.limit ?? 0).toStringAsFixed(0));
    final String? v = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('${c.name} monthly budget'),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: '₹ '),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (v == null) return;
    final double? parsed = double.tryParse(v.trim());
    store.setCategoryLimit(
        c.id, parsed == null || parsed <= 0 ? null : (parsed * 100).round());
  }

  /// Icons offered when creating a category — previously every new category
  /// silently got the same generic one.
  static const List<IconData> _categoryIcons = <IconData>[
    Icons.category_outlined,
    Icons.home_outlined,
    Icons.restaurant_outlined,
    Icons.local_hospital_outlined,
    Icons.directions_car_outlined,
    Icons.shopping_bag_outlined,
    Icons.school_outlined,
    Icons.flight_outlined,
    Icons.pets_outlined,
    Icons.sports_esports_outlined,
    Icons.bolt_outlined,
    Icons.card_giftcard_outlined,
  ];

  /// Long-press a budget row to edit its limit or remove the category.
  Future<void> _categoryMenu(
      BuildContext context, ExpenseStore store, BudgetCategory c) async {
    final int used = store.allTransactions
        .where((ExpenseTransaction t) => t.categoryId == c.id)
        .length;

    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: IconTile(icon: c.icon, color: c.color, size: 32),
              title: Text(c.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '$used transaction${used == 1 ? '' : 's'} in this category'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit budget limit'),
              onTap: () {
                Navigator.pop(sheet);
                _editLimit(context, store, c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.dangerBright),
              title: const Text('Delete category'),
              subtitle: used == 0
                  ? null
                  : Text('$used transaction${used == 1 ? '' : 's'} '
                      'will move to another category'),
              onTap: () async {
                Navigator.pop(sheet);
                final bool ok = await confirmDialog(
                  context,
                  title: 'Delete "${c.name}"?',
                  message: used == 0
                      ? 'This category has no transactions.'
                      : 'Its $used transaction${used == 1 ? '' : 's'} will be '
                          'reassigned so no spending is lost.',
                );
                if (!ok) return;
                store.deleteCategory(c.id);
                if (context.mounted) {
                  showSnack(context, '${c.name} deleted');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addCategory(BuildContext context, ExpenseStore store) async {
    final TextEditingController name = TextEditingController();
    final TextEditingController limit = TextEditingController();
    int icon = _categoryIcons.first.codePoint;
    int colour = AppColors
        .picker[store.categories.length % AppColors.picker.length]
        .toARGB32();

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setLocal) => AlertDialog(
          title: const Text('New budget category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Category name'),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: limit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Monthly limit', prefixText: '₹ '),
                ),
                const SizedBox(height: 16),
                const Text('Icon', style: TextStyle(fontSize: 12.5)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final IconData i in _categoryIcons)
                      InkWell(
                        onTap: () => setLocal(() => icon = i.codePoint),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: icon == i.codePoint
                                ? Color(colour).withValues(alpha: 0.16)
                                : ctx.fieldColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: icon == i.codePoint
                                  ? Color(colour)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Icon(i, size: 19, color: Color(colour)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Colour', style: TextStyle(fontSize: 12.5)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final Color c in AppColors.picker)
                      InkWell(
                        onTap: () => setLocal(() => colour = c.toARGB32()),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colour == c.toARGB32()
                                  ? ctx.txtPrimary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final double? lim = double.tryParse(limit.text.trim());
    store.addCategory(BudgetCategory(
      id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
      name: name.text.trim(),
      colorValue: colour,
      iconCodePoint: icon,
      limitPaise: lim == null || lim <= 0 ? null : (lim * 100).round(),
    ));
  }
}
