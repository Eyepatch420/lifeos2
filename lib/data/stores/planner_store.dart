import 'package:flutter/material.dart';

import '../../core/utils/date_x.dart';
import '../../core/utils/streak_calculator.dart';
import '../models/enums.dart';
import '../models/habit.dart';
import 'persistence.dart';

/// Owns habits, events, appointments and tasks (PRD 3.x).
class PlannerStore extends ChangeNotifier {
  PlannerStore() {
    if (!_load()) _seed();
  }

  static const String _key = 'planner';

  final List<Habit> _habits = <Habit>[];
  final List<PlannerEvent> _events = <PlannerEvent>[];

  bool _load() {
    final Map<String, dynamic>? j = Persistence.load(_key);
    if (j == null) return false;
    _habits.addAll((j['habits'] as List<dynamic>)
        .map((dynamic e) => Habit.fromJson(e as Map<String, dynamic>)));
    _events.addAll((j['events'] as List<dynamic>)
        .map((dynamic e) => PlannerEvent.fromJson(e as Map<String, dynamic>)));
    return true;
  }

  void flush() {
    Persistence.save(_key, <String, dynamic>{
      'habits': _habits.map((Habit h) => h.toJson()).toList(),
      'events': _events.map((PlannerEvent e) => e.toJson()).toList(),
    });
  }

  @override
  void notifyListeners() {
    flush();
    super.notifyListeners();
  }

  List<Habit> get habits => List<Habit>.unmodifiable(_habits);
  List<PlannerEvent> get events => List<PlannerEvent>.unmodifiable(_events);

  Habit? habitById(String id) {
    for (final Habit h in _habits) {
      if (h.id == id) return h;
    }
    return null;
  }

  List<Habit> habitsFor(DateTime date) =>
      _habits.where((Habit h) => h.isScheduledOn(date)).toList();

  List<PlannerEvent> eventsOn(DateTime date) {
    final List<PlannerEvent> list = _events
        .where((PlannerEvent e) => isSameDay(e.start, date))
        .toList();
    list.sort((PlannerEvent a, PlannerEvent b) => a.start.compareTo(b.start));
    return list;
  }

  List<PlannerEvent> upcomingAfter(DateTime now, {int limit = 5}) {
    final List<PlannerEvent> list = _events
        .where((PlannerEvent e) => e.start.isAfter(now) && !isSameDay(e.start, now))
        .toList();
    list.sort((PlannerEvent a, PlannerEvent b) => a.start.compareTo(b.start));
    return list.take(limit).toList();
  }

  /// Days in a range that have any planner item — powers the date-strip dots.
  bool hasItemsOn(DateTime date) =>
      habitsFor(date).isNotEmpty || eventsOn(date).isNotEmpty;

  PlannerEvent? nextAppointment(DateTime now) {
    final List<PlannerEvent> list = _events
        .where((PlannerEvent e) =>
            e.type == PlannerItemType.appointment && e.start.isAfter(now))
        .toList();
    list.sort((PlannerEvent a, PlannerEvent b) => a.start.compareTo(b.start));
    return list.isEmpty ? null : list.first;
  }

  // ---- habit completion -------------------------------------------------

  CompletionStatus? habitStatus(Habit h, DateTime date) =>
      h.completions[dayKey(date)];

  bool isHabitDone(Habit h, DateTime date) =>
      habitStatus(h, date) == CompletionStatus.done;

  void toggleHabit(Habit h, DateTime date) {
    final DateTime k = dayKey(date);
    if (!h.isScheduledOn(date)) return; // rest day: not actionable
    if (h.completions[k] == CompletionStatus.done) {
      h.completions.remove(k);
    } else {
      h.completions[k] = CompletionStatus.done;
    }
    notifyListeners();
  }

  void setHabitStatus(Habit h, DateTime date, CompletionStatus s) {
    h.completions[dayKey(date)] = s;
    notifyListeners();
  }

  /// PRD 3.1 AC1 — unscheduled days are "rest", never "missed".
  CompletionStatus displayStatus(Habit h, DateTime date, DateTime now) {
    if (!h.isScheduledOn(date)) return CompletionStatus.rest;
    final CompletionStatus? s = h.completions[dayKey(date)];
    if (s != null) return s;
    if (dayKey(date).isBefore(dayKey(now))) return CompletionStatus.missed;
    return CompletionStatus.rest;
  }

  StreakStats statsFor(Habit h, DateTime now) => StreakCalculator.compute(
        h.completions,
        now,
        isScheduled: h.isScheduledOn,
      );

  int streakDays(Habit h, DateTime now) => StreakCalculator.currentStreak(
        h.completions,
        now,
        isScheduled: h.isScheduledOn,
      );

  int habitsDueCount(DateTime date) => habitsFor(date).length;
  int habitsDoneCount(DateTime date) =>
      habitsFor(date).where((Habit h) => isHabitDone(h, date)).length;

  /// Adherence % across all habits this month — feeds the wellness score (1.3).
  double monthlyAdherence(DateTime now) {
    if (_habits.isEmpty) return 0;
    double sum = 0;
    for (final Habit h in _habits) {
      sum += statsFor(h, now).completionRate;
    }
    return sum / _habits.length;
  }

  // ---- mutations --------------------------------------------------------

  void addHabit(Habit h) {
    _habits.add(h);
    notifyListeners();
  }

  void updateHabit(Habit h) {
    final int i = _habits.indexWhere((Habit x) => x.id == h.id);
    if (i >= 0) _habits[i] = h;
    notifyListeners();
  }

  void deleteHabit(String id) {
    _habits.removeWhere((Habit h) => h.id == id);
    notifyListeners();
  }

  void addEvent(PlannerEvent e) {
    _events.add(e);
    notifyListeners();
  }

  void updateEvent(PlannerEvent e) {
    final int i = _events.indexWhere((PlannerEvent x) => x.id == e.id);
    if (i >= 0) _events[i] = e;
    notifyListeners();
  }

  void deleteEvent(String id) {
    _events.removeWhere((PlannerEvent e) => e.id == id);
    notifyListeners();
  }

  void toggleTaskDone(PlannerEvent e) {
    e.done = !e.done;
    notifyListeners();
  }

  // ---- seed -------------------------------------------------------------

  void _seed() {
    final DateTime now = DateTime.now();
    final DateTime today = dayKey(now);

    Map<DateTime, CompletionStatus> hist(int days, {List<int> miss = const <int>[]}) {
      final Map<DateTime, CompletionStatus> m = <DateTime, CompletionStatus>{};
      for (int i = days; i >= 1; i--) {
        m[dayKey(now.subtract(Duration(days: i)))] =
            miss.contains(i) ? CompletionStatus.missed : CompletionStatus.done;
      }
      return m;
    }

    _habits.addAll(<Habit>[
      Habit(
        id: 'hab_jog',
        name: 'Morning jog',
        durationMinutes: 30,
        preferredTime: const TimeOfDay(hour: 6, minute: 30),
        colorValue: 0xFF3B6D11,
        iconCodePoint: Icons.directions_run.codePoint,
        goalStreak: 30,
        completions: hist(20, miss: <int>[15]),
      ),
      Habit(
        id: 'hab_reading',
        name: 'Reading',
        durationMinutes: 20,
        colorValue: 0xFF534AB7,
        iconCodePoint: Icons.menu_book_outlined.codePoint,
        completions: hist(9, miss: <int>[2, 6]),
      ),
      Habit(
        id: 'hab_yoga',
        name: 'Yoga',
        durationMinutes: 15,
        repeat: RepeatPattern.specificDays,
        days: <int>{1, 3, 5},
        colorValue: 0xFF0F6E56,
        iconCodePoint: Icons.self_improvement.codePoint,
        completions: hist(14, miss: <int>[7]),
      ),
      Habit(
        id: 'hab_water',
        name: 'Water goal',
        colorValue: 0xFF185FA5,
        iconCodePoint: Icons.water_drop_outlined.codePoint,
        completions: hist(8, miss: <int>[1, 5]),
      ),
    ]);

    _events.addAll(<PlannerEvent>[
      PlannerEvent(
        id: 'ev_drmehta',
        title: 'Dr. Mehta — follow-up',
        type: PlannerItemType.appointment,
        start: today.add(const Duration(hours: 15, minutes: 30)),
        durationMinutes: 60,
        location: 'Kokilaben Hospital',
        colorValue: 0xFF854F0B,
      ),
      PlannerEvent(
        id: 'ev_standup',
        title: 'Team standup',
        type: PlannerItemType.event,
        start: today.add(const Duration(hours: 16)),
        durationMinutes: 30,
        location: 'Google Meet',
        colorValue: 0xFF534AB7,
      ),
      PlannerEvent(
        id: 'ev_flight',
        title: 'Flight to Delhi',
        type: PlannerItemType.event,
        start: today.add(const Duration(days: 2, hours: 7, minutes: 30)),
        durationMinutes: 150,
        location: 'BOM T2',
        colorValue: 0xFF185FA5,
      ),
      PlannerEvent(
        id: 'ev_bloodtest',
        title: 'Blood test — fasting',
        type: PlannerItemType.appointment,
        start: today.add(const Duration(days: 4, hours: 7)),
        durationMinutes: 45,
        location: 'SRL Diagnostics',
        colorValue: 0xFF854F0B,
      ),
      PlannerEvent(
        id: 'ev_task_rent',
        title: 'Transfer rent to landlord',
        type: PlannerItemType.task,
        start: today.add(const Duration(days: 3, hours: 10)),
        durationMinutes: 15,
        colorValue: 0xFF0F6E56,
      ),
    ]);
  }
}
