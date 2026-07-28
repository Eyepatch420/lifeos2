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
import '../../data/stores/planner_store.dart';
import '../../data/stores/reminder_store.dart';
import '../home/habit_streak_detail_screen.dart';
import '../reminders/reminders_screen.dart';
import 'add_planner_item_sheet.dart';

/// PRD 3.1 / 3.2 — Planner with Plan (agenda), Day (timeline) and Week views.
/// The Week view closes PRD Gap 5, which the mockups left undesigned.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  DateTime _selected = DateTime.now();
  int _view = 0; // 0 = Plan, 1 = Day, 2 = Week
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Keeps the "Now" line live while the Day view is open (PRD 3.2 AC1).
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          _header(context),
          Expanded(
            child: switch (_view) {
              1 => _dayView(context),
              2 => _weekView(context),
              _ => _planView(context),
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.planner,
        tooltip: 'Add to planner',
        onPressed: () =>
            AddPlannerItemSheet.show(context, initialDate: _selected),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final PlannerStore planner = context.watch<PlannerStore>();
    final DateTime weekStart = startOfWeek(_selected);

    return Container(
      color: AppColors.planner,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Planner',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          fmtMonthYear.format(_selected),
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Jump to today',
                    icon: const Icon(Icons.today_outlined, color: Colors.white),
                    onPressed: () => setState(() => _selected = DateTime.now()),
                  ),
                  IconButton(
                    tooltip: 'Pick a date',
                    icon: const Icon(Icons.calendar_month_outlined,
                        color: Colors.white),
                    onPressed: () async {
                      final DateTime? p = await showDatePicker(
                        context: context,
                        initialDate: _selected,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 365)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (p != null) setState(() => _selected = p);
                    },
                  ),
                ],
              ),
            ),
            // 7-day date strip with "has items" dots (PRD 3.1 FR1).
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < 7; i++)
                    Expanded(
                      child: _dayCell(
                          context, planner, weekStart.add(Duration(days: i))),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < 3; i++)
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _view = i),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _view == i
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              <String>['Plan', 'Day', 'Week'][i],
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: _view == i
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: _view == i
                                    ? AppColors.planner
                                    : Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(BuildContext context, PlannerStore planner, DateTime date) {
    final bool isSelected = isSameDay(date, _selected);
    final bool isToday = isSameDay(date, _now);
    final bool hasItems = planner.hasItemsOn(date);

    return InkWell(
      onTap: () => setState(() => _selected = date),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : (isToday
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: <Widget>[
            Text(
              fmtDayName.format(date),
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? AppColors.info
                    : Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              fmtDayNum.format(date),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.planner : Colors.white,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasItems
                    ? (isSelected
                        ? AppColors.info
                        : Colors.white.withValues(alpha: 0.75))
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Plan view (PRD 3.1) ----------------------------------------------

  Widget _planView(BuildContext context) {
    final PlannerStore planner = context.watch<PlannerStore>();
    final List<Habit> habits = planner.habitsFor(_selected);
    final List<PlannerEvent> todays = planner.eventsOn(_selected);
    final List<PlannerEvent> upcoming = planner.upcomingAfter(_selected);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      children: <Widget>[
        SectionLabel(
          'Daily habits',
          trailing: 'Manage',
          onTrailingTap: () => AddPlannerItemSheet.show(context,
              initialType: PlannerItemType.habit, initialDate: _selected),
        ),
        if (habits.isEmpty)
          AppCard(
            child: EmptyState(
              icon: Icons.repeat,
              title: 'No habits scheduled',
              message: 'Nothing is scheduled for this day.',
              actionLabel: 'Add habit',
              onAction: () => AddPlannerItemSheet.show(context,
                  initialType: PlannerItemType.habit, initialDate: _selected),
            ),
          )
        else
          AppCard(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < habits.length; i++) ...<Widget>[
                  _habitRow(context, planner, habits[i]),
                  if (i != habits.length - 1)
                    Divider(height: 1, color: context.hairline),
                ],
              ],
            ),
          ),
        const SizedBox(height: 14),
        SectionLabel(isSameDay(_selected, _now)
            ? "Today's events"
            : 'Events on ${fmtShortDate.format(_selected)}'),
        if (todays.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.event_available_outlined,
              title: 'Nothing scheduled',
              message: 'No events or appointments for this day.',
            ),
          )
        else
          AppCard(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < todays.length; i++) ...<Widget>[
                  _eventRow(context, planner, todays[i]),
                  if (i != todays.length - 1)
                    Divider(height: 1, color: context.hairline),
                ],
              ],
            ),
          ),
        if (upcoming.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          const SectionLabel('Upcoming'),
          AppCard(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < upcoming.length; i++) ...<Widget>[
                  _eventRow(context, planner, upcoming[i], showRelative: true),
                  if (i != upcoming.length - 1)
                    Divider(height: 1, color: context.hairline),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _habitRow(BuildContext context, PlannerStore planner, Habit h) {
    final bool done = planner.isHabitDone(h, _selected);
    final int streak = planner.streakDays(h, _now);
    final DateTime weekStart = startOfWeek(_selected);

    return InkWell(
      onLongPress: () => _habitMenu(context, planner, h),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => HabitStreakDetailScreen(habitId: h.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            IconTile(icon: h.icon, color: h.color, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    h.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.txtPrimary,
                    ),
                  ),
                  Text(
                    '${h.durationMinutes} min'
                    '${h.preferredTime == null ? ' · Anytime' : ' · ${formatTimeOfDay(h.preferredTime!)}'}',
                    style:
                        TextStyle(fontSize: 11.5, color: context.txtSecondary),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: <Widget>[
                      for (int i = 0; i < 7; i++) ...<Widget>[
                        _weekDot(context, planner, h,
                            weekStart.add(Duration(days: i))),
                        if (i != 6) const SizedBox(width: 3),
                      ],
                    ],
                  ),
                  if (streak > 0) ...<Widget>[
                    const SizedBox(height: 5),
                    StatusChip.tone('$streak day streak', ChipTone.warning,
                        icon: Icons.local_fire_department),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Rest days show a dash and are not actionable (PRD 3.1 AC1).
            if (!h.isScheduledOn(_selected))
              Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  border: Border.all(color: context.hairline, width: 1.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.remove, size: 14, color: context.txtTertiary),
              )
            else
              InkWell(
                onTap: () => planner.toggleHabit(h, _selected),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: done ? AppColors.checkGreen : Colors.transparent,
                    border: Border.all(color: AppColors.checkGreen, width: 1.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check,
                      size: 15,
                      color: done ? Colors.white : AppColors.checkGreen),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _weekDot(
      BuildContext context, PlannerStore planner, Habit h, DateTime date) {
    const List<String> labels = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final bool isFuture = date.isAfter(dayKey(_now));
    final bool isSel = isSameDay(date, _selected);
    final CompletionStatus s =
        isFuture ? CompletionStatus.rest : planner.displayStatus(h, date, _now);

    final (Color bg, Color fg) = switch (s) {
      CompletionStatus.done => (AppColors.successBg, AppColors.success),
      CompletionStatus.partial => (AppColors.successBg, AppColors.success),
      CompletionStatus.missed => (AppColors.dangerBg, AppColors.danger),
      CompletionStatus.skipped => (
          AppColors.bgTertiary,
          AppColors.textTertiary
        ),
      CompletionStatus.rest => (Colors.transparent, AppColors.textTertiary),
    };

    return Container(
      width: 15,
      height: 15,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: isSel
            ? Border.all(color: AppColors.info, width: 1)
            : (s == CompletionStatus.rest
                ? Border.all(color: context.hairline, width: 0.6)
                : null),
      ),
      child: Text(
        labels[date.weekday - 1],
        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _eventRow(BuildContext context, PlannerStore planner, PlannerEvent e,
      {bool showRelative = false}) {
    return InkWell(
      onTap: () => AddPlannerItemSheet.show(context, existingEvent: e),
      onLongPress: () => _eventMenu(context, planner, e),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 4,
              height: 42,
              decoration: BoxDecoration(
                color: e.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            IconTile(
              icon: switch (e.type) {
                PlannerItemType.appointment => Icons.medical_services_outlined,
                PlannerItemType.task => Icons.check_box_outlined,
                _ => Icons.event_outlined,
              },
              color: e.color,
              size: 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    e.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.txtPrimary,
                      decoration: e.type == PlannerItemType.task && e.done
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  Text(
                    <String>[
                      if (e.location.isNotEmpty) e.location,
                      if (showRelative) relativeDayLabel(e.start, _now),
                      fmtTime.format(e.start),
                    ].join(' · '),
                    style:
                        TextStyle(fontSize: 11.5, color: context.txtSecondary),
                  ),
                  const SizedBox(height: 4),
                  StatusChip.tone(
                    e.badgeLabel,
                    switch (e.type) {
                      PlannerItemType.appointment => ChipTone.warning,
                      PlannerItemType.task => ChipTone.success,
                      _ => ChipTone.purple,
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (e.type == PlannerItemType.task)
              InkWell(
                onTap: () => planner.toggleTaskDone(e),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: e.done ? AppColors.checkGreen : Colors.transparent,
                    border: Border.all(color: AppColors.checkGreen, width: 1.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check,
                      size: 14,
                      color: e.done ? Colors.white : AppColors.checkGreen),
                ),
              )
            else
              Text(
                e.durationMinutes >= 60
                    ? '${(e.durationMinutes / 60).toStringAsFixed(e.durationMinutes % 60 == 0 ? 0 : 1)} hr'
                    : '${e.durationMinutes} min',
                style: TextStyle(fontSize: 11.5, color: context.txtSecondary),
              ),
          ],
        ),
      ),
    );
  }

  // ---- Day view (PRD 3.2) -----------------------------------------------

  Widget _dayView(BuildContext context) {
    final PlannerStore planner = context.watch<PlannerStore>();
    final ReminderStore reminders = context.watch<ReminderStore>();
    final List<PlannerEvent> events = planner.eventsOn(_selected);
    final List<Habit> habits = planner.habitsFor(_selected);
    final List<Reminder> dueReminders = reminders
        .forDate(_selected)
        .where((Reminder r) => r.enabled)
        .toList();
    final bool isToday = isSameDay(_selected, _now);

    // Default window is 6 AM–10 PM, but it expands so an early or late item
    // is never invisible here while showing up in the other views.
    int startHour = 6;
    int endHour = 22;
    for (final PlannerEvent e in events) {
      if (e.start.hour < startHour) startHour = e.start.hour;
      if (e.end.hour > endHour) endHour = e.end.hour;
    }
    for (final Habit h in habits) {
      final TimeOfDay? t = h.preferredTime;
      if (t == null) continue;
      if (t.hour < startHour) startHour = t.hour;
      if (t.hour > endHour) endHour = t.hour;
    }
    for (final Reminder r in dueReminders) {
      if (r.time.hour < startHour) startHour = r.time.hour;
      if (r.time.hour > endHour) endHour = r.time.hour;
    }
    if (isToday) {
      if (_now.hour < startHour) startHour = _now.hour;
      if (_now.hour > endHour) endHour = _now.hour;
    }
    endHour = endHour.clamp(startHour, 23);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      itemCount: endHour - startHour + 1,
      itemBuilder: (BuildContext context, int index) {
        final int hour = startHour + index;
        final List<PlannerEvent> hourEvents =
            events.where((PlannerEvent e) => e.start.hour == hour).toList();
        final List<Habit> hourHabits = habits
            .where((Habit h) =>
                h.preferredTime != null && h.preferredTime!.hour == hour)
            .toList();
        final List<Reminder> hourReminders = dueReminders
            .where((Reminder r) => r.time.hour == hour)
            .toList();
        final bool showNow = isToday && _now.hour == hour;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 46,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, right: 6),
                  child: Text(
                    formatTimeOfDay(TimeOfDay(hour: hour, minute: 0))
                        .replaceAll(':00', ''),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, color: context.txtTertiary),
                  ),
                ),
              ),
              Column(
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hourEvents.isNotEmpty ||
                              hourHabits.isNotEmpty ||
                              hourReminders.isNotEmpty
                          ? (hourHabits.isNotEmpty
                              ? AppColors.success
                              : hourEvents.isNotEmpty
                                  ? hourEvents.first.color
                                  : hourReminders.first.color)
                          : context.hairline,
                    ),
                  ),
                  Expanded(
                    child: Container(width: 1, color: context.hairline),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // PRD 3.2 FR2 — the Now marker renders only for today.
                      if (showNow)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.dangerBright,
                                ),
                              ),
                              Expanded(
                                child: Container(
                                    height: 1, color: AppColors.dangerBright),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Now ${fmtTime.format(_now)}',
                                style: const TextStyle(
                                    fontSize: 10, color: AppColors.danger),
                              ),
                            ],
                          ),
                        ),
                      for (final Habit h in hourHabits)
                        _timelineBlock(
                          context,
                          color: h.color,
                          title: h.name,
                          subtitle:
                              '${formatTimeOfDay(h.preferredTime!)} · Habit',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  HabitStreakDetailScreen(habitId: h.id),
                            ),
                          ),
                          onLongPress: () => _habitMenu(context, planner, h),
                        ),
                      for (final PlannerEvent e in hourEvents)
                        _timelineBlock(
                          context,
                          color: e.color,
                          title: e.title,
                          subtitle:
                              '${fmtTime.format(e.start)}–${fmtTime.format(e.end)}'
                              '${e.location.isEmpty ? '' : ' · ${e.location}'}',
                          onTap: () => AddPlannerItemSheet.show(context,
                              existingEvent: e),
                          onLongPress: () => _eventMenu(context, planner, e),
                        ),
                      for (final Reminder r in hourReminders)
                        _timelineBlock(
                          context,
                          color: r.color,
                          title: r.title,
                          subtitle: '${formatTimeOfDay(r.time)} · Reminder',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const RemindersScreen(),
                            ),
                          ),
                        ),
                      if (hourEvents.isEmpty &&
                          hourHabits.isEmpty &&
                          hourReminders.isEmpty &&
                          !showNow)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'Free',
                            style: TextStyle(
                                fontSize: 12, color: context.txtTertiary),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _timelineBlock(
    BuildContext context, {
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      // A rounded box cannot use a Border whose sides differ in colour —
      // Flutter throws while painting and the block renders blank. The accent
      // stripe is therefore drawn as its own element, not as a border side.
      child: Material(
        color: context.cardColor,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: BorderSide(color: context.hairline, width: 0.5),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(width: 3, color: color),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.txtPrimary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: TextStyle(
                              fontSize: 11.5, color: context.txtSecondary),
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
    );
  }

  // ---- Week view (closes PRD Gap 5) --------------------------------------

  Widget _weekView(BuildContext context) {
    final PlannerStore planner = context.watch<PlannerStore>();
    final DateTime weekStart = startOfWeek(_selected);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      children: <Widget>[
        SectionLabel(
          'Week of ${fmtShortDate.format(weekStart)}',
        ),
        for (int i = 0; i < 7; i++)
          Builder(builder: (BuildContext c) {
            final DateTime d = weekStart.add(Duration(days: i));
            final List<PlannerEvent> evts = planner.eventsOn(d);
            final List<Habit> habits = planner.habitsFor(d);
            final int habitsDone =
                habits.where((Habit h) => planner.isHabitDone(h, d)).length;
            final bool isToday = isSameDay(d, _now);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () => setState(() {
                  _selected = d;
                  _view = 1;
                }),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isToday
                                ? AppColors.planner
                                : context.fieldColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(
                                fmtDayName.format(d),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isToday
                                      ? Colors.white70
                                      : context.txtTertiary,
                                ),
                              ),
                              Text(
                                fmtDayNum.format(d),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isToday
                                      ? Colors.white
                                      : context.txtPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                habits.isEmpty && evts.isEmpty
                                    ? 'Nothing scheduled'
                                    : '${habits.length} habit${habits.length == 1 ? '' : 's'} · '
                                        '${evts.length} event${evts.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: context.txtPrimary,
                                ),
                              ),
                              if (habits.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: ThinProgressBar(
                                    value: habits.isEmpty
                                        ? 0
                                        : habitsDone / habits.length,
                                    color: AppColors.success,
                                    height: 4,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (habits.isNotEmpty)
                          Text(
                            '$habitsDone/${habits.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.txtSecondary,
                            ),
                          ),
                      ],
                    ),
                    if (evts.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: <Widget>[
                          for (final PlannerEvent e in evts)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: e.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${fmtTime.format(e.start)} ${e.title}',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: e.color,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // ---- context menus -----------------------------------------------------

  Future<void> _habitMenu(
      BuildContext context, PlannerStore planner, Habit h) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: const Text('View streak detail'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => HabitStreakDetailScreen(habitId: h.id)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit habit'),
              onTap: () {
                Navigator.pop(ctx);
                AddPlannerItemSheet.show(context, existingHabit: h);
              },
            ),
            ListTile(
              leading: const Icon(Icons.skip_next_outlined),
              title: const Text('Skip today'),
              subtitle: const Text('Keeps your streak',
                  style: TextStyle(fontSize: 12)),
              onTap: () {
                planner.setHabitStatus(h, _selected, CompletionStatus.skipped);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.dangerBright),
              title: const Text('Delete habit',
                  style: TextStyle(color: AppColors.dangerBright)),
              onTap: () async {
                Navigator.pop(ctx);
                final bool ok = await confirmDialog(
                  context,
                  title: 'Delete ${h.name}?',
                  message:
                      'This removes the habit and its full streak history. '
                      'This cannot be undone.',
                );
                if (ok) planner.deleteHabit(h.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eventMenu(
      BuildContext context, PlannerStore planner, PlannerEvent e) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                AddPlannerItemSheet.show(context, existingEvent: e);
              },
            ),
            if (e.type == PlannerItemType.task)
              ListTile(
                leading: const Icon(Icons.check, color: AppColors.checkGreen),
                title: Text(e.done ? 'Mark as not done' : 'Mark as done'),
                onTap: () {
                  planner.toggleTaskDone(e);
                  Navigator.pop(ctx);
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
                  title: 'Delete ${e.title}?',
                  message: 'This cannot be undone.',
                );
                if (ok) planner.deleteEvent(e.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
