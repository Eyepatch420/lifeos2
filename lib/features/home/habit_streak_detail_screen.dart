import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/utils/streak_calculator.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/habit.dart';
import '../../data/stores/planner_store.dart';

/// PRD 1.2 — deep-dive into one habit: 28-day heatmap, stats and milestones.
class HabitStreakDetailScreen extends StatelessWidget {
  const HabitStreakDetailScreen({super.key, required this.habitId});

  final String habitId;

  static const List<String> _weekdayLabels = <String>[
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S'
  ];

  @override
  Widget build(BuildContext context) {
    final PlannerStore planner = context.watch<PlannerStore>();
    final Habit? habit = planner.habitById(habitId);
    final DateTime now = DateTime.now();

    if (habit == null) {
      return Scaffold(
        appBar:
            AppBar(backgroundColor: AppColors.home, title: const Text('Habit')),
        body: const EmptyState(
          icon: Icons.link_off,
          title: 'This habit no longer exists',
          message: 'It may have been deleted from the Planner.',
        ),
      );
    }

    final StreakStats stats = planner.statsFor(habit, now);

    return Scaffold(
      body: Column(
        children: <Widget>[
          _header(context, habit, stats),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: <Widget>[
                _heatmap(context, planner, habit, now),
                const SizedBox(height: 14),
                _stats(context, stats),
                const SizedBox(height: 14),
                _milestones(context, habit, stats),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, Habit habit, StreakStats stats) {
    return Container(
      color: habit.color,
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
                  Expanded(
                    child: Text(
                      habit.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Icon(habit.icon, color: Colors.white.withValues(alpha: 0.9)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 10, top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Current streak',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.white.withValues(alpha: 0.7))),
                        Text.rich(
                          TextSpan(children: <InlineSpan>[
                            TextSpan(
                              text: '${stats.current}',
                              style: const TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            const TextSpan(
                              text: ' days',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ]),
                        ),
                      ],
                    ),
                    const SizedBox(width: 22),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Best ever',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white.withValues(alpha: 0.7))),
                          Text(
                            '${stats.best}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text('This month',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white.withValues(alpha: 0.7))),
                          Text(
                            '${stats.doneThisMonth}/${stats.scheduledThisMonth}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
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

  /// 28-day heatmap. Today's cell is outlined (PRD 1.2 FR2).
  Widget _heatmap(
      BuildContext context, PlannerStore planner, Habit habit, DateTime now) {
    // Align the grid so columns are Mon..Sun.
    final DateTime end = dayKey(now);
    final DateTime endWeekStart = startOfWeek(end);
    final DateTime start = endWeekStart.subtract(const Duration(days: 21));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionLabel('Last 28 days'),
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  for (final String l in _weekdayLabels)
                    Expanded(
                      child: Center(
                        child: Text(
                          l,
                          style: TextStyle(
                              fontSize: 10, color: context.txtTertiary),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              for (int week = 0; week < 4; week++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: <Widget>[
                      for (int d = 0; d < 7; d++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _cell(
                              context,
                              planner,
                              habit,
                              start.add(Duration(days: week * 7 + d)),
                              now,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Divider(height: 12, color: context.hairline),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: <Widget>[
                  _legend(context, 'Done', habit.color),
                  _legend(
                      context, 'Partial', habit.color.withValues(alpha: 0.45)),
                  _legend(context, 'Missed', AppColors.dangerBright),
                  _legend(context, 'Rest', context.hairline),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cell(BuildContext context, PlannerStore planner, Habit habit,
      DateTime date, DateTime now) {
    final bool isFuture = date.isAfter(dayKey(now));
    final bool isToday = isSameDay(date, now);
    final CompletionStatus status = isFuture
        ? CompletionStatus.rest
        : planner.displayStatus(habit, date, now);

    final Color fill = switch (status) {
      CompletionStatus.done => habit.color,
      CompletionStatus.partial => habit.color.withValues(alpha: 0.45),
      CompletionStatus.missed => AppColors.dangerBright,
      CompletionStatus.skipped => AppColors.borderSecondary,
      CompletionStatus.rest =>
        isFuture ? context.hairline.withValues(alpha: 0.4) : context.hairline,
    };

    return Tooltip(
      message: '${fmtShortDate.format(date)} · '
          '${isFuture ? 'Upcoming' : _statusLabel(status)}',
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
            border: isToday ? Border.all(color: habit.color, width: 2) : null,
          ),
        ),
      ),
    );
  }

  String _statusLabel(CompletionStatus s) => switch (s) {
        CompletionStatus.done => 'Done',
        CompletionStatus.partial => 'Partial',
        CompletionStatus.missed => 'Missed',
        CompletionStatus.skipped => 'Skipped',
        CompletionStatus.rest => 'Rest day',
      };

  Widget _legend(BuildContext context, String label, Color c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration:
              BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(fontSize: 10.5, color: context.txtSecondary)),
      ],
    );
  }

  Widget _stats(BuildContext context, StreakStats stats) {
    const List<String> dayNames = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun'
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionLabel('Stats'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          // 2.3 left the label + value + sub-label 3.5px short of fitting,
          // so every tile painted an overflow stripe.
          childAspectRatio: 2.0,
          children: <Widget>[
            _statTile(context, 'Completion rate',
                '${(stats.completionRate * 100).round()}%', 'this month'),
            _statTile(context, 'Total sessions', '${stats.totalSessions}',
                'all time'),
            _statTile(
              context,
              'Best day',
              stats.bestDayOfWeek == null
                  ? '—'
                  : dayNames[stats.bestDayOfWeek! - 1],
              'most consistent',
            ),
            _statTile(context, 'Missed days', '${stats.missedThisMonth}',
                'this month',
                valueColor:
                    stats.missedThisMonth > 0 ? AppColors.danger : null),
          ],
        ),
      ],
    );
  }

  Widget _statTile(BuildContext context, String label, String value, String sub,
      {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: context.fieldColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(label,
              style: TextStyle(fontSize: 11, color: context.txtSecondary)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: valueColor ?? context.txtPrimary,
            ),
          ),
          Text(sub, style: TextStyle(fontSize: 11, color: context.txtTertiary)),
        ],
      ),
    );
  }

  /// PRD 1.2 FR4 / AC4 — thresholds come from the shared config.
  Widget _milestones(BuildContext context, Habit habit, StreakStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionLabel('Streak milestones'),
        AppCard(
          child: Column(
            children: <Widget>[
              for (int i = 0; i < StreakCalculator.milestones.length; i++)
                Builder(builder: (BuildContext c) {
                  final int m = StreakCalculator.milestones[i];
                  final int hits = StreakCalculator.milestoneHits(
                      habit.completions, m,
                      isScheduled: habit.isScheduledOn);
                  final bool achieved = hits > 0;
                  final int toGo = m - stats.current;
                  return Column(
                    children: <Widget>[
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 0),
                        leading: IconTile(
                          icon: achieved
                              ? Icons.emoji_events
                              : Icons.emoji_events_outlined,
                          color:
                              achieved ? habit.color : AppColors.textTertiary,
                          size: 30,
                        ),
                        title: Text('$m-day streak',
                            style: const TextStyle(fontSize: 13.5)),
                        subtitle: Text(
                          achieved
                              ? 'Achieved $hits time${hits == 1 ? '' : 's'}'
                              : (toGo > 0
                                  ? '$toGo day${toGo == 1 ? '' : 's'} to go'
                                  : 'In progress'),
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        trailing: achieved
                            ? StatusChip.tone('Done', ChipTone.success)
                            : StatusChip.tone(toGo > 0 ? '$toGo left' : '—',
                                ChipTone.neutral),
                      ),
                      if (i != StreakCalculator.milestones.length - 1)
                        Divider(height: 1, color: context.hairline),
                    ],
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}
