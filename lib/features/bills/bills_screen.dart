import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_header.dart';
import '../../data/models/commitments.dart';
import '../../data/models/enums.dart';
import '../../data/models/expense.dart';
import '../../data/stores/commitments_store.dart';
import '../../data/stores/expense_store.dart';
import '../../data/stores/id_gen.dart';
import 'add_bill_sheet.dart';

/// PRD 8.1 — bills, subscriptions and EMIs with overdue always surfaced.
class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  int _tab = 0;
  static const List<String> _tabs = <String>[
    'All',
    'Bills',
    'Subscriptions',
    'EMI'
  ];

  BillKind? get _filter => switch (_tab) {
        1 => BillKind.bill,
        2 => BillKind.subscription,
        3 => BillKind.emi,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final CommitmentsStore store = context.watch<CommitmentsStore>();
    final DateTime now = DateTime.now();
    final List<Bill> overdue = store.overdueBills(now);
    final List<Bill> dueWeek = store.dueThisWeek(now);
    final List<Bill> shown = store.billsOfKind(_filter);
    final List<Bill> emis =
        shown.where((Bill b) => b.kind == BillKind.emi).toList();
    final List<Bill> subs =
        shown.where((Bill b) => b.kind == BillKind.subscription).toList();

    return Scaffold(
      body: Column(
        children: <Widget>[
          ModuleHeader(
            color: AppColors.bills,
            title: 'Bills & subscriptions',
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            actions: <Widget>[
              HeaderIconButton(
                icon: Icons.add,
                tooltip: 'Add bill',
                onPressed: () => AddBillSheet.show(context),
              ),
            ],
            stats: <Widget>[
              HeaderStat(
                  label: 'Monthly committed',
                  value: formatRupeesCompact(store.monthlyCommitted)),
              HeaderStat(
                label: 'Due this week',
                value: formatRupeesCompact(store.dueThisWeekTotal(now)),
                valueColor: const Color(0xFFFAC775),
              ),
              HeaderStat(
                label: 'Overdue',
                value: formatRupeesCompact(store.overdueTotal(now)),
                valueColor:
                    overdue.isEmpty ? Colors.white : const Color(0xFFF09595),
              ),
            ],
            tabs: _tabs,
            selectedTab: _tab,
            onTabSelected: (int i) => setState(() => _tab = i),
          ),
          Expanded(
            child: store.activeBills.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Nothing tracked yet',
                    message: 'Add a bill, subscription or EMI to stay ahead of '
                        'due dates.',
                    actionLabel: 'Add bill',
                    onAction: () => AddBillSheet.show(context),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    children: <Widget>[
                      // PRD 8.1 FR2 — overdue surfaces regardless of sub-tab.
                      if (overdue.isNotEmpty) ...<Widget>[
                        SectionLabel('Overdue',
                            trailing: formatRupees(store.overdueTotal(now))),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.dangerBright, width: 1),
                          ),
                          child: AppCard(
                            child: Column(
                              children: <Widget>[
                                for (int i = 0;
                                    i < overdue.length;
                                    i++) ...<Widget>[
                                  _billRow(context, store, overdue[i], now),
                                  if (i != overdue.length - 1)
                                    Divider(height: 1, color: context.hairline),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (dueWeek.isNotEmpty && _filter == null) ...<Widget>[
                        const SectionLabel('Due this week'),
                        AppCard(
                          child: Column(
                            children: <Widget>[
                              for (int i = 0;
                                  i < dueWeek.length;
                                  i++) ...<Widget>[
                                _billRow(context, store, dueWeek[i], now),
                                if (i != dueWeek.length - 1)
                                  Divider(height: 1, color: context.hairline),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (emis.isNotEmpty) ...<Widget>[
                        const SectionLabel('EMI tracker'),
                        AppCard(
                          child: Column(
                            children: <Widget>[
                              for (int i = 0; i < emis.length; i++) ...<Widget>[
                                _emiRow(context, store, emis[i], now),
                                if (i != emis.length - 1)
                                  Divider(height: 1, color: context.hairline),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (subs.isNotEmpty) ...<Widget>[
                        const SectionLabel('All subscriptions'),
                        AppCard(
                          child: Column(
                            children: <Widget>[
                              for (int i = 0; i < subs.length; i++) ...<Widget>[
                                _subRow(context, store, subs[i], now),
                                if (i != subs.length - 1)
                                  Divider(height: 1, color: context.hairline),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_filter != null &&
                          shown.isNotEmpty &&
                          _filter != BillKind.emi &&
                          _filter != BillKind.subscription) ...<Widget>[
                        SectionLabel(_tabs[_tab]),
                        AppCard(
                          child: Column(
                            children: <Widget>[
                              for (int i = 0;
                                  i < shown.length;
                                  i++) ...<Widget>[
                                _billRow(context, store, shown[i], now),
                                if (i != shown.length - 1)
                                  Divider(height: 1, color: context.hairline),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (shown.isEmpty && overdue.isEmpty)
                        const AppCard(
                          child: EmptyState(
                            icon: Icons.filter_alt_outlined,
                            title: 'Nothing here',
                            message: 'No items match this filter.',
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.bills,
        tooltip: 'Add bill',
        onPressed: () => AddBillSheet.show(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _billRow(
      BuildContext context, CommitmentsStore store, Bill b, DateTime now) {
    final bool overdue = b.isOverdue(now);
    final int days = b.daysUntilDue(now);
    final IconData icon = switch (b.kind) {
      BillKind.bill => Icons.receipt_outlined,
      BillKind.subscription => Icons.autorenew,
      BillKind.emi => Icons.account_balance_outlined,
      BillKind.creditCard => Icons.credit_card,
    };

    return InkWell(
      onTap: () => AddBillSheet.show(context, existing: b),
      onLongPress: () => _billMenu(context, store, b, now),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            IconTile(
                icon: icon,
                color: overdue ? AppColors.danger : AppColors.bills),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    b.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: overdue ? AppColors.danger : context.txtPrimary,
                    ),
                  ),
                  Text(
                    'Due ${fmtShortDate.format(b.dueDate)} · ${b.cycle.label}'
                    '${b.autoPay ? ' · Auto-pay' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 11.5, color: context.txtSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  formatRupees(b.amount),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: overdue ? AppColors.danger : context.txtPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                if (overdue)
                  StatusChip.tone(
                      '${b.daysLate(now)} day${b.daysLate(now) == 1 ? '' : 's'} late',
                      ChipTone.danger)
                else if (b.autoPay)
                  StatusChip.tone('Auto-pay', ChipTone.success)
                else
                  StatusChip.tone(days == 0 ? 'Today' : '$days days',
                      days <= 3 ? ChipTone.warning : ChipTone.neutral),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emiRow(
      BuildContext context, CommitmentsStore store, Bill b, DateTime now) {
    return InkWell(
      onTap: () => AddBillSheet.show(context, existing: b),
      onLongPress: () => _billMenu(context, store, b, now),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            const IconTile(
                icon: Icons.account_balance_outlined, color: AppColors.bills),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    b.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.txtPrimary,
                    ),
                  ),
                  Text(
                    '${formatRupees(b.amount)}/mo · '
                    '${b.installmentsPaid} of ${b.installmentsTotal ?? 0} paid',
                    style:
                        TextStyle(fontSize: 11.5, color: context.txtSecondary),
                  ),
                  const SizedBox(height: 5),
                  ThinProgressBar(
                      value: b.emiProgress, color: AppColors.bills, height: 4),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  formatRupeesCompact(b.remainingBalance),
                  style: TextStyle(fontSize: 12.5, color: context.txtSecondary),
                ),
                Text('remaining',
                    style:
                        TextStyle(fontSize: 10.5, color: context.txtTertiary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _subRow(
      BuildContext context, CommitmentsStore store, Bill b, DateTime now) {
    return InkWell(
      onTap: () => AddBillSheet.show(context, existing: b),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: <Widget>[
            const IconTile(icon: Icons.autorenew, color: AppColors.purple),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    b.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.txtPrimary,
                    ),
                  ),
                  Text(
                    '${formatRupees(b.amount)}/${b.cycle.label.toLowerCase()} · '
                    'renews ${fmtShortDate.format(b.dueDate)}',
                    style:
                        TextStyle(fontSize: 11.5, color: context.txtSecondary),
                  ),
                ],
              ),
            ),
            // PRD 8.1 AC3 — auto-renew toggle is NOT deletion.
            Switch(
              value: b.autoPay,
              activeThumbColor: AppColors.checkGreen,
              onChanged: (_) {
                store.toggleAutoPay(b);
                showSnack(
                  context,
                  b.autoPay
                      ? 'Auto-renew on — reminders paused'
                      : 'Auto-renew off — you will be reminded before it is due',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _billMenu(BuildContext context, CommitmentsStore store, Bill b,
      DateTime now) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.check, color: AppColors.checkGreen),
              title: Text(b.kind == BillKind.emi
                  ? 'Mark installment paid'
                  : 'Mark as paid'),
              subtitle: Text(
                'Next due moves to ${fmtShortDate.format(b.nextDueDate())}',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                store.markBillPaid(b, now);
                // Bills↔Expenses — a paid bill is real spend, so it must
                // show up in the Expenses module and count toward budgets.
                final ExpenseStore expenses = context.read<ExpenseStore>();
                expenses.add(ExpenseTransaction(
                  id: IdGen.next('txn'),
                  type: TransactionType.expense,
                  amountPaise: b.amountPaise,
                  description: b.name,
                  categoryId: b.linkedCategoryId ?? expenses.categories.last.id,
                  date: now,
                  note: 'Logged from Bills',
                ));
                Navigator.pop(ctx);
                showSnack(context, '${b.name} marked paid · logged to Expenses');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                AddBillSheet.show(context, existing: b);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.dangerBright),
              title: const Text('Delete',
                  style: TextStyle(color: AppColors.dangerBright)),
              onTap: () async {
                Navigator.pop(ctx);
                final bool ok = await confirmDialog(
                  context,
                  title: 'Delete ${b.name}?',
                  message: 'This removes the record and its history. '
                      'This cannot be undone.',
                );
                if (ok) store.deleteBill(b.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
