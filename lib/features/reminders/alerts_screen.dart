import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/common.dart';
import '../../data/models/commitments.dart';
import '../../data/models/reminder.dart';
import '../../data/stores/commitments_store.dart';
import '../../data/stores/reminder_store.dart';
import '../../data/stores/settings_store.dart';
import '../bills/bills_screen.dart';
import '../documents/document_vault_screen.dart';
import '../memberships/membership_detail_screen.dart';

/// PRD 2.5 — every alert LifeOS would raise, rendered exactly as it appears on
/// the lock screen: two contextual actions per alert (never a generic "OK"),
/// and tapping the body deep-links to the specific item (AC2).
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final ReminderStore reminders = context.watch<ReminderStore>();
    final CommitmentsStore commitments = context.watch<CommitmentsStore>();

    final List<Reminder> missed = reminders
        .forDate(now)
        .where((Reminder r) => reminders.isMissed(r, now, now))
        .toList();
    final List<Membership> expiringMemberships =
        commitments.expiringMemberships(now);
    final List<StoredDocument> expiringDocs =
        commitments.expiringDocuments(now);
    final List<Bill> overdue = commitments.overdueBills(now);

    final bool empty = missed.isEmpty &&
        expiringMemberships.isEmpty &&
        expiringDocs.isEmpty &&
        overdue.isEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.home,
        title: const Text('Alerts'),
      ),
      body: empty
          ? const EmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'Nothing needs your attention',
              message: 'Missed reminders, overdue bills and upcoming expiries '
                  'will appear here.',
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                const InfoBanner(
                  tone: ChipTone.neutral,
                  icon: Icons.lock_outline,
                  text:
                      'These are the alerts LifeOS raises on your lock screen. '
                      'Actions here work without opening the app.',
                ),
                const SizedBox(height: 12),
                for (final Bill b in overdue)
                  _AlertCard(
                    source: 'Bill overdue',
                    icon: Icons.credit_card,
                    tone: ChipTone.danger,
                    title: '${b.name} overdue',
                    body: '${formatRupees(b.amount)} was due on '
                        '${fmtShortDate.format(b.dueDate)} '
                        '(${b.daysLate(now)} day${b.daysLate(now) == 1 ? '' : 's'} late). '
                        'Pay now to avoid a late fee.',
                    primaryLabel: 'Mark as paid',
                    onPrimary: () {
                      context.read<CommitmentsStore>().markBillPaid(b, now);
                      showSnack(context, '${b.name} marked paid');
                    },
                    secondaryLabel: 'Snooze',
                    onSecondary: () {
                      final int mins =
                          context.read<SettingsStore>().defaultSnoozeMinutes;
                      context.read<CommitmentsStore>().snoozeBill(b, mins);
                      showSnack(context, 'Snoozed for $mins minutes');
                    },
                    onOpen: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const BillsScreen()),
                    ),
                  ),
                for (final Membership m in expiringMemberships)
                  _AlertCard(
                    source: 'Membership alert',
                    icon: Icons.badge_outlined,
                    tone: ChipTone.warning,
                    title: '${m.name} expires in ${m.daysLeftFrom(now)} days',
                    body: 'Renew before ${fmtShortDate.format(m.expiryDate)} '
                        'to avoid a membership gap.',
                    primaryLabel: 'Mark renewed',
                    onPrimary: () {
                      context.read<CommitmentsStore>().markRenewed(m, now);
                      showSnack(context, '${m.name} renewed');
                    },
                    secondaryLabel: 'Remind later',
                    onSecondary: () {
                      context
                          .read<CommitmentsStore>()
                          .remindMembershipLater(m);
                      showSnack(context, 'Will remind tomorrow');
                    },
                    onOpen: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => MembershipDetailScreen(id: m.id),
                      ),
                    ),
                  ),
                for (final StoredDocument d in expiringDocs)
                  _AlertCard(
                    source: 'Document alert',
                    icon: Icons.description_outlined,
                    tone: ChipTone.warning,
                    title: '${d.name} expires in ${d.daysLeftFrom(now)} days',
                    body: 'Expires on ${fmtShortDate.format(d.expiryDate!)}. '
                        'Renew it before the deadline.',
                    primaryLabel: 'View document',
                    onPrimary: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const DocumentVaultScreen()),
                    ),
                    secondaryLabel: 'Dismiss',
                    onSecondary: () {
                      context
                          .read<CommitmentsStore>()
                          .dismissDocumentAlert(d);
                      showSnack(context, 'Dismissed for today');
                    },
                    onOpen: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const DocumentVaultScreen()),
                    ),
                  ),
                for (final Reminder r in missed)
                  _AlertCard(
                    source: r.isForceConfirm
                        ? 'Reminder · force confirm'
                        : 'Reminder',
                    icon: r.icon,
                    tone: ChipTone.danger,
                    title: '${r.title} missed',
                    body: r.isForceConfirm
                        ? 'Scheduled for ${formatTimeOfDay(r.time)}. This alarm '
                            'repeats every ${r.forceConfirmIntervalMinutes} min '
                            "until you confirm you've taken it."
                        : 'Scheduled for ${formatTimeOfDay(r.time)}.',
                    primaryLabel:
                        r.isForceConfirm ? "I've taken it" : 'Mark done',
                    onPrimary: () {
                      final ReminderStore reminders =
                          context.read<ReminderStore>();
                      if (reminders.markDone(r, now)) {
                        showSnack(context, '${r.title} marked done');
                      } else {
                        final Reminder? dep =
                            reminders.blockingDependency(r, now);
                        showSnack(
                          context,
                          dep == null
                              ? 'Complete its dependency first'
                              : 'Complete "${dep.title}" first',
                        );
                      }
                    },
                    secondaryLabel: 'Snooze',
                    onSecondary: () {
                      final int m =
                          context.read<SettingsStore>().defaultSnoozeMinutes;
                      context.read<ReminderStore>().snooze(r, m);
                      showSnack(context, 'Snoozed $m minutes');
                    },
                    onOpen: () => Navigator.pop(context),
                  ),
              ],
            ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.source,
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    required this.onOpen,
  });

  final String source;
  final IconData icon;
  final ChipTone tone;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;
  final VoidCallback onOpen;

  Color get _accent => switch (tone) {
        ChipTone.danger => AppColors.danger,
        ChipTone.warning => AppColors.warning,
        ChipTone.success => AppColors.success,
        _ => AppColors.info,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        // Tapping the body deep-links to the exact item (PRD 2.5 AC2).
        onTap: onOpen,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                IconTile(icon: icon, color: _accent, size: 30),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'LifeOS · $source',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.txtSecondary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: context.txtTertiary),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: context.txtPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              body,
              style: TextStyle(
                  fontSize: 12, height: 1.4, color: context.txtSecondary),
            ),
            const SizedBox(height: 11),
            // Exactly two contextual actions (PRD 2.5 FR1).
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSecondary,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(color: context.hairline),
                    ),
                    child: Text(secondaryLabel,
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: onPrimary,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(primaryLabel,
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
