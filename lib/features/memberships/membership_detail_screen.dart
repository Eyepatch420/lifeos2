import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/common.dart';
import '../../data/models/commitments.dart';
import '../../data/models/enums.dart';
import '../../data/models/expense.dart';
import '../../data/stores/commitments_store.dart';
import '../../data/stores/expense_store.dart';
import '../../data/stores/id_gen.dart';
import 'add_membership_sheet.dart';

/// PRD 7.2 — membership detail, renewal history and reminder configuration.
class MembershipDetailScreen extends StatelessWidget {
  const MembershipDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final CommitmentsStore store = context.watch<CommitmentsStore>();
    final Membership? m = store.membershipById(id);
    final DateTime now = DateTime.now();

    if (m == null) {
      return Scaffold(
        appBar: AppBar(
            backgroundColor: AppColors.memberships,
            title: const Text('Membership')),
        body: const EmptyState(
          icon: Icons.link_off,
          title: 'Membership not found',
          message: 'It may have been deleted.',
        ),
      );
    }

    final int days = m.daysLeftFrom(now);
    final bool urgent = m.active && days <= 7;
    final Color headerColor = !m.active
        ? AppColors.textSecondary
        : (urgent ? AppColors.danger : AppColors.memberships);

    return Scaffold(
      body: Column(
        children: <Widget>[
          Container(
            color: headerColor,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 14, 14),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            m.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined,
                              color: Colors.white),
                          onPressed: () =>
                              AddMembershipSheet.show(context, existing: m),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 0, 0),
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              !m.active
                                  ? Icons.cancel_outlined
                                  : (days < 0
                                      ? Icons.error_outline
                                      : Icons.alarm),
                              color: const Color(0xFFFAC775),
                              size: 22,
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    !m.active
                                        ? 'Membership cancelled'
                                        : days < 0
                                            ? 'Expired ${-days} days ago'
                                            : 'Expiring in $days days',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '${fmtShortDate.format(m.expiryDate)} '
                                    '${m.expiryDate.year}'
                                    '${m.active ? ' · Renew to keep your streak' : ''}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color:
                                          Colors.white.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: <Widget>[
                AppCard(
                  padding: const EdgeInsets.all(12),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.6,
                    children: <Widget>[
                      _fact(context, 'Type', m.cycle.label),
                      _fact(context, 'Cost',
                          '${formatRupees(m.cost)}/${m.cycle.label.toLowerCase()}'),
                      _fact(context, 'Member since',
                          '${fmtMonthShort.format(m.startDate)} ${m.startDate.year}'),
                      // PRD 7.2 AC1 — paid entries only.
                      _fact(context, 'Total paid', formatRupees(m.totalPaid)),
                      _fact(context, 'Annual cost', formatRupees(m.annualCost)),
                      _fact(context, 'Category', m.category.label),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const SectionLabel('Renewal history'),
                if (m.history.isEmpty)
                  const AppCard(
                    child: EmptyState(
                      icon: Icons.history,
                      title: 'No renewals yet',
                      message: 'Renewals you record will appear here.',
                    ),
                  )
                else
                  AppCard(
                    child: Column(
                      children: <Widget>[
                        for (int i = 0; i < m.history.length; i++) ...<Widget>[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 11),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: m.history[i].paid
                                        ? AppColors.success
                                        : AppColors.dangerBright,
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        '${m.history[i].paid ? 'Renewed' : 'Lapsed'} · '
                                        '${fmtShortDate.format(m.history[i].date)} '
                                        '${m.history[i].date.year}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: context.txtPrimary,
                                        ),
                                      ),
                                      Text(
                                        m.history[i].paid
                                            ? '${formatRupees(m.history[i].amount)} · ${m.history[i].method}'
                                            : m.history[i].note,
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            color: context.txtSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusChip.tone(
                                  m.history[i].paid ? 'Paid' : 'Missed',
                                  m.history[i].paid
                                      ? ChipTone.success
                                      : ChipTone.danger,
                                ),
                              ],
                            ),
                          ),
                          if (i != m.history.length - 1)
                            Divider(height: 1, color: context.hairline),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                const SectionLabel('Renewal reminder'),
                AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Alert me before expiry',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: context.txtPrimary,
                                  ),
                                ),
                                Text(
                                  'Currently: ${m.reminderLeadDays} days before'
                                  ' · ${m.alertType.label}',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: context.txtSecondary),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: m.reminderEnabled,
                            activeThumbColor: AppColors.checkGreen,
                            onChanged: (bool v) {
                              m.reminderEnabled = v;
                              store.updateMembership(m);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          for (final int d in <int>[3, 7, 15, 30])
                            ChoicePill(
                              label: d == 30 ? '1 month' : '$d days',
                              selected: m.reminderLeadDays == d,
                              color: AppColors.memberships,
                              // PRD 7.2 AC4 — affects only FUTURE reminders.
                              onTap: () {
                                m.reminderLeadDays = d;
                                store.updateMembership(m);
                                showSnack(context,
                                    'Future reminders will fire $d days before expiry');
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (m.active)
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.successBg,
                            foregroundColor: AppColors.successText,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: () {
                            store.markRenewed(m, now);
                            // Memberships↔Expenses — a renewal is real spend,
                            // so it must show up in Expenses/budgets.
                            final ExpenseStore expenses =
                                context.read<ExpenseStore>();
                            final ExpenseTransaction txn = ExpenseTransaction(
                              id: IdGen.next('txn'),
                              type: TransactionType.expense,
                              amountPaise: m.costPaise,
                              description: '${m.name} renewal',
                              categoryId: m.category == MembershipCategory.health
                                  ? expenses.medicineCategoryId
                                  : expenses.categories.last.id,
                              date: now,
                              note: 'Logged from Memberships',
                            );
                            expenses.add(txn);
                            m.linkedExpenseId = txn.id;
                            showSnack(
                                context,
                                'Renewed — expiry moved to '
                                '${fmtShortDate.format(m.expiryDate)} · logged to Expenses');
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Mark as renewed'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.dangerBg,
                            foregroundColor: AppColors.dangerText,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: () async {
                            final bool ok = await confirmDialog(
                              context,
                              title: 'Cancel ${m.name}?',
                              message:
                                  'It will be removed from active counts and '
                                  'alerts. Your renewal history is kept.',
                              confirmLabel: 'Cancel membership',
                              cancelLabel: 'Keep it',
                            );
                            if (ok) {
                              store.cancelMembership(m);
                              if (context.mounted) {
                                showSnack(context, '${m.name} cancelled');
                              }
                            }
                          },
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Cancel membership'),
                        ),
                      ),
                    ],
                  )
                else
                  const InfoBanner(
                    tone: ChipTone.neutral,
                    icon: Icons.history,
                    title: 'This membership is cancelled',
                    text: 'Its history is preserved for your records.',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fact(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.fieldColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(label,
              style: TextStyle(fontSize: 10.5, color: context.txtSecondary)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: context.txtPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
