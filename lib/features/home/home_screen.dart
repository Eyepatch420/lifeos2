import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/habit.dart';
import '../../data/models/reminder.dart';
import '../../data/stores/commitments_store.dart';
import '../../data/stores/expense_store.dart';
import '../../data/stores/health_store.dart';
import '../../data/stores/planner_store.dart';
import '../../data/stores/reminder_store.dart';
import '../../data/stores/settings_store.dart';
import '../expenses/expenses_screen.dart';
import '../health/health_screen.dart';
import '../planner/planner_screen.dart';
import '../reminders/alerts_screen.dart';
import '../reminders/reminders_screen.dart';
import '../reminders/water_card.dart';
import '../search/global_search_screen.dart';
import '../settings/settings_screen.dart';
import 'consolidated_progress_screen.dart';
import 'habit_streak_detail_screen.dart';

/// PRD 1.1 — Home dashboard. Every figure here is read live from the owning
/// module's store, so Home can never disagree with the module it mirrors.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  DateTime _now = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // PRD 1.1 edge case: handle midnight rollover while the app is open.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      final DateTime next = DateTime.now();
      if (!isSameDay(next, _now) || next.hour != _now.hour) {
        setState(() => _now = next);
      } else {
        setState(() => _now = next);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// PRD 1.1 FR9 — refresh whenever the app is foregrounded, not only on start.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _now = DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    final SettingsStore settings = context.watch<SettingsStore>();
    final ReminderStore reminders = context.watch<ReminderStore>();
    final PlannerStore planner = context.watch<PlannerStore>();
    final ExpenseStore expenses = context.watch<ExpenseStore>();
    final HealthStore health = context.watch<HealthStore>();
    final CommitmentsStore commitments = context.watch<CommitmentsStore>();

    final int remindersDue = reminders.dueCount(_now);
    final int remindersDone = reminders.doneCount(_now);
    final int habitsDue = planner.habitsDueCount(_now);
    final int habitsDone = planner.habitsDoneCount(_now);
    final double todaySpend = expenses.spendOn(_now);
    final int todayTxns = expenses.transactionCountOn(_now);

    final int alertCount = reminders.missedCount(_now, _now) +
        commitments.overdueBills(_now).length +
        commitments.expiringMemberships(_now).length +
        commitments.expiringDocuments(_now).length;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _now = DateTime.now()),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
                child: _header(
                    context,
                    settings,
                    alertCount,
                    remindersDue,
                    remindersDone,
                    habitsDue,
                    habitsDone,
                    todaySpend,
                    todayTxns)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate(<Widget>[
                  _upNext(context, reminders, planner),
                  const SizedBox(height: 14),
                  _habitStreaks(context, planner),
                  const SizedBox(height: 14),
                  _moduleShortcuts(context, reminders, planner, expenses,
                      health, commitments),
                  const SizedBox(height: 14),
                  const SectionLabel("Today's water"),
                  WaterCard(date: _now, showGlasses: false),
                  const SizedBox(height: 14),
                  _wellnessPrompt(context, health),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    SettingsStore settings,
    int alertCount,
    int remindersDue,
    int remindersDone,
    int habitsDue,
    int habitsDone,
    double todaySpend,
    int todayTxns,
  ) {
    return Container(
      color: AppColors.home,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          greetingFor(_now),
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7)),
                        ),
                        Text(
                          settings.name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Search everything',
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const GlobalSearchScreen()),
                    ),
                  ),
                  Stack(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Alerts',
                        icon: const Icon(Icons.notifications_none,
                            color: Colors.white),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const AlertsScreen()),
                        ),
                      ),
                      if (alertCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.dangerBright,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            constraints: const BoxConstraints(minWidth: 16),
                            child: Text(
                              '$alertCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen()),
                    ),
                    customBorder: const CircleBorder(),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white.withValues(alpha: 0.22),
                      child: Text(
                        settings.initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  Icon(Icons.calendar_today_outlined,
                      size: 13, color: Colors.white.withValues(alpha: 0.65)),
                  const SizedBox(width: 6),
                  Text(
                    fmtLongDate.format(_now),
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _StatCard(
                      label: 'Reminders today',
                      value: '$remindersDue',
                      // PRD 1.1 AC3 — graceful empty state, never NaN.
                      sub: remindersDue == 0
                          ? 'Nothing scheduled'
                          : '$remindersDone done · ${remindersDue - remindersDone} pending',
                      progress:
                          remindersDue == 0 ? 0 : remindersDone / remindersDue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      label: 'Habits today',
                      value: '$habitsDue',
                      sub: habitsDue == 0
                          ? 'No habits today'
                          : '$habitsDone done · ${habitsDue - habitsDone} pending',
                      progress: habitsDue == 0 ? 0 : habitsDone / habitsDue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      label: "Today's spend",
                      value: formatRupeesCompact(todaySpend),
                      sub: todayTxns == 0
                          ? 'No transactions'
                          : '$todayTxns transaction${todayTxns == 1 ? '' : 's'}',
                      progress: null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// PRD 1.1 FR5 — next-due item chronologically across Reminders and Planner.
  Widget _upNext(
      BuildContext context, ReminderStore reminders, PlannerStore planner) {
    final Reminder? nextReminder = reminders.nextUp(_now);
    final PlannerEvent? nextAppt = planner.nextAppointment(_now);

    if (nextReminder == null && nextAppt == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionLabel('Up next'),
          AppCard(
            child: EmptyState(
              icon: Icons.check_circle_outline,
              title: "You're all caught up",
              message: 'Nothing else is scheduled for today.',
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionLabel(
          'Up next',
          trailing: 'All reminders',
          onTrailingTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const RemindersScreen()),
          ),
        ),
        AppCard(
          child: Column(
            children: <Widget>[
              if (nextReminder != null)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: IconTile(
                      icon: nextReminder.icon, color: nextReminder.color),
                  title: Text(
                    nextReminder.title,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${relativeTimeLabel(DateTime(_now.year, _now.month, _now.day, nextReminder.time.hour, nextReminder.time.minute), _now)}'
                    ' · ${formatTimeOfDay(nextReminder.time)}',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  trailing: InkWell(
                    onTap: () {
                      final ReminderStore reminders =
                          context.read<ReminderStore>();
                      if (!reminders.markDone(nextReminder, _now)) {
                        final Reminder? dep = reminders.blockingDependency(
                            nextReminder, _now);
                        showSnack(
                          context,
                          dep == null
                              ? 'Complete its dependency first'
                              : 'Complete "${dep.title}" first',
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 27,
                      height: 27,
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: AppColors.checkGreen, width: 1.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check,
                          size: 15, color: AppColors.checkGreen),
                    ),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const RemindersScreen()),
                  ),
                ),
              if (nextReminder != null && nextAppt != null)
                Divider(height: 1, color: context.hairline),
              if (nextAppt != null)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: IconTile(
                      icon: Icons.medical_services_outlined,
                      color: nextAppt.color),
                  title: Text(
                    nextAppt.title,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${relativeDayLabel(nextAppt.start, _now)} '
                    '${fmtTime.format(nextAppt.start)}'
                    '${nextAppt.location.isEmpty ? '' : ' · ${nextAppt.location}'}',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  trailing:
                      StatusChip.tone(nextAppt.badgeLabel, ChipTone.warning),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const PlannerScreen()),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// PRD 1.1 FR6 + edge case: top 3 by streak length, with "View all".
  Widget _habitStreaks(BuildContext context, PlannerStore planner) {
    final List<Habit> habits = List<Habit>.from(planner.habits);
    habits.sort((Habit a, Habit b) =>
        planner.streakDays(b, _now).compareTo(planner.streakDays(a, _now)));
    final List<Habit> top = habits.take(3).toList();

    if (top.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SectionLabel('Habit streaks'),
          AppCard(
            child: EmptyState(
              icon: Icons.local_fire_department_outlined,
              title: 'No habits yet',
              message: 'Add a habit in the Planner to start a streak.',
              actionLabel: 'Open Planner',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const PlannerScreen()),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionLabel(
          'Habit streaks',
          trailing: 'View all',
          onTrailingTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => const ConsolidatedProgressScreen()),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              for (int i = 0; i < top.length; i++) ...<Widget>[
                Expanded(child: _habitMini(context, planner, top[i])),
                if (i != top.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _habitMini(BuildContext context, PlannerStore planner, Habit h) {
    final int streak = planner.streakDays(h, _now);
    final DateTime weekStart = startOfWeek(_now);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => HabitStreakDetailScreen(habitId: h.id)),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: context.fieldColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: <Widget>[
            Icon(h.icon, size: 18, color: h.color),
            const SizedBox(height: 4),
            Text(
              h.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: context.txtPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$streak',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: h.color),
            ),
            Text('day streak',
                style: TextStyle(fontSize: 10, color: context.txtTertiary)),
            const SizedBox(height: 5),
            // 7-day dot strip. PRD 1.1 AC6 — colours match the legend exactly.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int d = 0; d < 7; d++) ...<Widget>[
                  _dot(
                    planner.displayStatus(
                        h, weekStart.add(Duration(days: d)), _now),
                    h.color,
                    context,
                  ),
                  if (d != 6) const SizedBox(width: 2),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(CompletionStatus s, Color base, BuildContext context) {
    final Color c = switch (s) {
      CompletionStatus.done => base,
      CompletionStatus.partial => base.withValues(alpha: 0.45),
      CompletionStatus.missed => AppColors.dangerBright,
      CompletionStatus.skipped => AppColors.borderSecondary,
      CompletionStatus.rest => context.hairline,
    };
    return Container(
      width: 7,
      height: 7,
      decoration:
          BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
    );
  }

  /// PRD 1.1 FR7 — shortcut tiles with live badges, deep-linking to modules.
  Widget _moduleShortcuts(
    BuildContext context,
    ReminderStore reminders,
    PlannerStore planner,
    ExpenseStore expenses,
    HealthStore health,
    CommitmentsStore commitments,
  ) {
    final int due = reminders.dueCount(_now) - reminders.doneCount(_now);
    final Reminder? next = reminders.nextUp(_now);
    final PlannerEvent? appt = planner.nextAppointment(_now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionLabel('Module shortcuts'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.75,
          children: <Widget>[
            _shortcut(
              context,
              icon: Icons.notifications_none,
              color: AppColors.info,
              label: 'Reminders',
              sub: next != null
                  ? 'Next: ${formatTimeOfDay(next.time)}'
                  : due > 0
                      ? '$due overdue'
                      : 'Nothing pending',
              badge: due > 0 ? '$due due' : null,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const RemindersScreen())),
            ),
            _shortcut(
              context,
              icon: Icons.calendar_today_outlined,
              color: AppColors.success,
              label: 'Planner',
              sub: appt == null
                  ? 'No appointments'
                  : '${appt.title.split(' —').first} ${fmtTime.format(appt.start)}',
              badge: appt != null ? '1 appt' : null,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const PlannerScreen())),
            ),
            _shortcut(
              context,
              icon: Icons.currency_rupee,
              color: AppColors.teal,
              label: 'Expenses',
              sub: '${formatRupeesCompact(expenses.monthSpend)} this month',
              badge: '${formatRupeesCompact(expenses.spendOn(_now))} today',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const ExpensesScreen())),
            ),
            _shortcut(
              context,
              icon: Icons.monitor_heart_outlined,
              color: AppColors.warning,
              label: 'Health',
              sub: 'Last scan: ${health.lastScanLabel(_now)}',
              badge: '${health.reportCount} reports',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const HealthScreen())),
            ),
          ],
        ),
      ],
    );
  }

  Widget _shortcut(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String sub,
    String? badge,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IconTile(icon: icon, color: color, size: 32),
              const Spacer(),
              if (badge != null)
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      badge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.txtPrimary),
              ),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: context.txtSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _wellnessPrompt(BuildContext context, HealthStore health) {
    if (health.hasEntryToday(_now)) return const SizedBox.shrink();
    return InfoBanner(
      tone: ChipTone.purple,
      icon: Icons.mood,
      title: "How are you feeling today?",
      text: "You haven't logged your wellness entry yet. Tap to log it.",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const HealthScreen()),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.progress,
  });

  final String label;
  final String value;
  final String sub;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10.5, color: Colors.white.withValues(alpha: 0.72)),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (progress ?? 0).clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
