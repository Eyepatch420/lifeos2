import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/share_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/habit.dart';
import '../../data/models/expense.dart';
import '../../data/stores/expense_store.dart';
import '../../data/stores/health_store.dart';
import '../../data/stores/planner_store.dart';
import '../../data/stores/progress_store.dart';
import '../../data/stores/reminder_store.dart';
import 'habit_streak_detail_screen.dart';

/// One module's contribution to the composite wellness score.
class _ModuleHealth {
  const _ModuleHealth(
      this.label, this.icon, this.color, this.value, this.weight,
      {this.hasData = true});
  final String label;
  final IconData icon;
  final Color color;

  /// 0..1 adherence.
  final double value;

  /// PRD 1.3 FR1 — weights are configurable, not baked into one formula.
  final double weight;
  final bool hasData;
}

/// PRD 1.3 — cross-module wellness score and all streaks at a glance.
class ConsolidatedProgressScreen extends StatelessWidget {
  const ConsolidatedProgressScreen({super.key});

  /// Tunable weights for the composite score.
  static const Map<String, double> weights = <String, double>{
    'Reminders': 0.3,
    'Planner habits': 0.3,
    'Budget adherence': 0.2,
    'Health tracking': 0.2,
  };

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final ReminderStore reminders = context.watch<ReminderStore>();
    final PlannerStore planner = context.watch<PlannerStore>();
    final ExpenseStore expenses = context.watch<ExpenseStore>();
    final HealthStore health = context.watch<HealthStore>();

    final int due = reminders.dueCount(now);
    final int done = reminders.doneCount(now);

    final List<_ModuleHealth> modules = <_ModuleHealth>[
      _ModuleHealth(
        'Reminders',
        Icons.notifications_none,
        AppColors.info,
        due == 0 ? 0 : done / due,
        weights['Reminders']!,
        hasData: due > 0,
      ),
      _ModuleHealth(
        'Planner habits',
        Icons.calendar_today_outlined,
        AppColors.success,
        planner.monthlyAdherence(now),
        weights['Planner habits']!,
        hasData: planner.habits.isNotEmpty,
      ),
      _ModuleHealth(
        'Budget adherence',
        Icons.currency_rupee,
        AppColors.teal,
        expenses.budgetAdherence(expenses.selectedMonth),
        weights['Budget adherence']!,
        hasData:
            expenses.categories.any((BudgetCategory c) => (c.limit ?? 0) > 0),
      ),
      _ModuleHealth(
        'Health tracking',
        Icons.monitor_heart_outlined,
        AppColors.warning,
        health.trackingAdherence(now),
        weights['Health tracking']!,
        hasData: health.wellnessEntries.isNotEmpty,
      ),
    ];

    // Score is a weighted composite over modules that actually have data —
    // a module with no data must not silently drag the score to 0 (AC2).
    final List<_ModuleHealth> withData =
        modules.where((_ModuleHealth m) => m.hasData).toList();
    final double totalWeight =
        withData.fold<double>(0, (double s, _ModuleHealth m) => s + m.weight);
    final int score = totalWeight == 0
        ? 0
        : (withData.fold<double>(
                    0, (double s, _ModuleHealth m) => s + m.value * m.weight) /
                totalWeight *
                100)
            .round();

    // PRD 1.3 AC3 — delta against a real recorded snapshot. Recomputing the
    // current numbers with a past date (the old approach) just reproduced
    // today's score, so the delta was meaningless.
    final ProgressStore progress = context.watch<ProgressStore>();
    final int? lastMonthScore = progress.previousMonthScore(now);
    final int? delta = lastMonthScore == null ? null : score - lastMonthScore;

    // Record this month so next month has something honest to compare with.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      progress.record(now, score);
    });

    return Scaffold(
      body: Column(
        children: <Widget>[
          _header(context, score, delta, now),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: <Widget>[
                _allStreaks(context, planner, now),
                const SizedBox(height: 14),
                _moduleHealth(context, modules),
                const SizedBox(height: 14),
                InfoBanner(
                  tone: ChipTone.neutral,
                  icon: Icons.calculate_outlined,
                  title: 'How this score is calculated',
                  text: withData.isEmpty
                      ? 'Start logging in any module to build your score.'
                      : 'A weighted average of '
                          '${withData.map((_ModuleHealth m) => '${m.label} '
                              '(${(m.weight * 100).round()}%)').join(', ')}. '
                          'Modules with no data yet are excluded rather than '
                          'counted as zero.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _header(BuildContext context, int score, int? delta, DateTime now) {
    return Container(
      color: AppColors.progress,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'My progress',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Share summary',
                    icon: const Icon(Icons.ios_share, color: Colors.white),
                    onPressed: () => ShareService.shareText(
                      'LifeOS wellness score: $score/100 '
                      'for ${fmtMonthYear.format(now)}',
                      subject: 'My LifeOS progress',
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 10, top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Overall wellness score · ${fmtMonthYear.format(now)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.65)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text.rich(
                          TextSpan(children: <InlineSpan>[
                            TextSpan(
                              text: '$score',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            const TextSpan(
                              text: '/100',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            // No invented delta before there is history.
                            delta == null
                                ? 'first month tracked'
                                : delta == 0
                                    ? 'same as last month'
                                    : '${delta > 0 ? '+' : ''}$delta from last month',
                            style: TextStyle(
                              fontSize: 12,
                              color: delta == null
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : (delta >= 0
                                      ? const Color(0xFF9FE1CB)
                                      : const Color(0xFFF09595)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (score / 100).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF5DCAA5)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Weekly streak strip per habit, flagging broken/at-risk ones (PRD 1.3 FR4).
  Widget _allStreaks(BuildContext context, PlannerStore planner, DateTime now) {
    final List<Habit> habits = planner.habits;
    if (habits.isEmpty) {
      return const AppCard(
        child: EmptyState(
          icon: Icons.timeline,
          title: 'No habits tracked yet',
          message: 'Add habits in the Planner to see streaks here.',
        ),
      );
    }
    final DateTime weekStart = startOfWeek(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionLabel('All streaks this week'),
        AppCard(
          child: Column(
            children: <Widget>[
              for (int i = 0; i < habits.length; i++) ...<Widget>[
                _streakRow(context, planner, habits[i], weekStart, now),
                if (i != habits.length - 1)
                  Divider(height: 1, color: context.hairline),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _streakRow(BuildContext context, PlannerStore planner, Habit h,
      DateTime weekStart, DateTime now) {
    final int streak = planner.streakDays(h, now);
    // "At risk" when a scheduled day was missed in the last 7 days.
    final bool broken = List<int>.generate(7, (int i) => i).any((int i) {
      final DateTime d = weekStart.add(Duration(days: i));
      if (d.isAfter(dayKey(now))) return false;
      return planner.displayStatus(h, d, now) == CompletionStatus.missed;
    });

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => HabitStreakDetailScreen(habitId: h.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(h.icon, size: 16, color: h.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    h.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.txtPrimary,
                    ),
                  ),
                ),
                Text(
                  streak > 0
                      ? '$streak days'
                      : (broken ? 'Broken' : 'Not started'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: streak > 0
                        ? h.color
                        : (broken ? AppColors.danger : context.txtTertiary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: <Widget>[
                for (int i = 0; i < 7; i++) ...<Widget>[
                  Expanded(
                    child: _dayBlock(context, planner, h,
                        weekStart.add(Duration(days: i)), now),
                  ),
                  if (i != 6) const SizedBox(width: 4),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayBlock(BuildContext context, PlannerStore planner, Habit h,
      DateTime date, DateTime now) {
    const List<String> labels = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final bool isFuture = date.isAfter(dayKey(now));
    final bool isToday = isSameDay(date, now);
    final CompletionStatus s =
        isFuture ? CompletionStatus.rest : planner.displayStatus(h, date, now);

    final Color fill = switch (s) {
      CompletionStatus.done => h.color,
      CompletionStatus.partial => h.color.withValues(alpha: 0.45),
      CompletionStatus.missed => AppColors.dangerBright,
      CompletionStatus.skipped => AppColors.borderSecondary,
      CompletionStatus.rest =>
        isFuture ? context.hairline.withValues(alpha: 0.5) : context.hairline,
    };

    return Column(
      children: <Widget>[
        Container(
          height: 22,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
            border: isToday ? Border.all(color: h.color, width: 2) : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          labels[date.weekday - 1],
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
            color: isToday ? h.color : context.txtTertiary,
          ),
        ),
      ],
    );
  }

  Widget _moduleHealth(BuildContext context, List<_ModuleHealth> modules) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionLabel('Module health'),
        AppCard(
          child: Column(
            children: <Widget>[
              for (int i = 0; i < modules.length; i++) ...<Widget>[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: <Widget>[
                      IconTile(
                          icon: modules[i].icon,
                          color: modules[i].color,
                          size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              modules[i].label,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: context.txtPrimary,
                              ),
                            ),
                            const SizedBox(height: 5),
                            ThinProgressBar(
                              value: modules[i].hasData ? modules[i].value : 0,
                              color: modules[i].color,
                              height: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 46,
                        child: Text(
                          // PRD 1.3 AC2 — explicit "No data", never a fake 0%.
                          modules[i].hasData
                              ? '${(modules[i].value * 100).round()}%'
                              : 'No data',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: modules[i].hasData ? 13.5 : 11,
                            fontWeight: FontWeight.w600,
                            color: modules[i].hasData
                                ? modules[i].color
                                : context.txtTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != modules.length - 1)
                  Divider(height: 1, color: context.hairline),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
