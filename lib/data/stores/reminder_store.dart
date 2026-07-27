import 'package:flutter/material.dart';

import '../../core/utils/date_x.dart';
import '../../core/utils/streak_calculator.dart';
import '../models/enums.dart';
import '../models/reminder.dart';
import 'id_gen.dart';
import 'persistence.dart';

/// Owns all reminder + water state (PRD 2.x). Home reads from here rather than
/// keeping its own copy, satisfying "Home mirrors the owning module".
class ReminderStore extends ChangeNotifier {
  ReminderStore() {
    if (!_load()) _seed();
  }

  static const String _key = 'reminders';

  final List<Reminder> _reminders = <Reminder>[];
  WaterConfig water = WaterConfig();

  /// Date-keyed millilitres consumed.
  final Map<DateTime, int> _waterLog = <DateTime, int>{};

  bool _load() {
    final Map<String, dynamic>? j = Persistence.load(_key);
    if (j == null) return false;
    _reminders.addAll((j['reminders'] as List<dynamic>)
        .map((dynamic e) => Reminder.fromJson(e as Map<String, dynamic>)));
    water = WaterConfig.fromJson(j['water'] as Map<String, dynamic>);
    (j['waterLog'] as Map<String, dynamic>).forEach(
        (String k, dynamic v) => _waterLog[DateTime.parse(k)] = v as int);
    return true;
  }

  void _save() {
    Persistence.save(_key, <String, dynamic>{
      'reminders': _reminders.map((Reminder r) => r.toJson()).toList(),
      'water': water.toJson(),
      'waterLog': _waterLog.map((DateTime k, int v) =>
          MapEntry<String, int>(k.toIso8601String(), v)),
    });
  }

  @override
  void notifyListeners() {
    _save();
    super.notifyListeners();
  }

  List<Reminder> get all => List<Reminder>.unmodifiable(_reminders);

  Reminder? byId(String id) {
    for (final Reminder r in _reminders) {
      if (r.id == id) return r;
    }
    return null;
  }

  List<Reminder> ofType(ReminderType? t) =>
      t == null ? all : _reminders.where((Reminder r) => r.type == t).toList();

  /// Reminders that apply on a date, in chronological order.
  List<Reminder> forDate(DateTime date) {
    final List<Reminder> list =
        _reminders.where((Reminder r) => r.appliesOn(date)).toList();
    list.sort((Reminder a, Reminder b) =>
        (a.time.hour * 60 + a.time.minute) - (b.time.hour * 60 + b.time.minute));
    return list;
  }

  Map<String, List<Reminder>> groupedByBucket(DateTime date,
      {ReminderType? filter}) {
    final Map<String, List<Reminder>> out = <String, List<Reminder>>{
      'Morning': <Reminder>[],
      'Afternoon': <Reminder>[],
      'Evening': <Reminder>[],
    };
    for (final Reminder r in forDate(date)) {
      if (filter != null && r.type != filter) continue;
      out[r.bucket]!.add(r);
    }
    out.removeWhere((String _, List<Reminder> v) => v.isEmpty);
    return out;
  }

  CompletionStatus? statusOn(Reminder r, DateTime date) =>
      r.completions[dayKey(date)];

  bool isDone(Reminder r, DateTime date) =>
      statusOn(r, date) == CompletionStatus.done;

  /// PRD 2.1 AC3 — past its time, neither done nor skipped => missed.
  bool isMissed(Reminder r, DateTime date, DateTime now) {
    if (!r.enabled || !r.appliesOn(date)) return false;
    final CompletionStatus? s = statusOn(r, date);
    if (s == CompletionStatus.done ||
        s == CompletionStatus.skipped ||
        s == CompletionStatus.partial) {
      return false;
    }
    if (!isSameDay(date, now)) return date.isBefore(dayKey(now));
    final int nowMin = now.hour * 60 + now.minute;
    return nowMin > r.time.hour * 60 + r.time.minute;
  }

  /// PRD 2.1 FR7 — a chained reminder is blocked until its dependency is done.
  bool isBlockedByDependency(Reminder r, DateTime date) {
    if (r.dependencyId == null) return false;
    final Reminder? dep = byId(r.dependencyId!);
    if (dep == null) return false;
    return !isDone(dep, date);
  }

  int missedCount(DateTime date, DateTime now) => forDate(date)
      .where((Reminder r) => isMissed(r, date, now))
      .length;

  int dueCount(DateTime date) =>
      forDate(date).where((Reminder r) => r.enabled).length;

  int doneCount(DateTime date) => forDate(date)
      .where((Reminder r) => r.enabled && isDone(r, date))
      .length;

  /// Next enabled, not-yet-done reminder after [now] (feeds Home "Up next").
  /// PRD 1.1 edge case: ties break by earliest-created (list order).
  Reminder? nextUp(DateTime now) {
    final int nowMin = now.hour * 60 + now.minute;
    for (final Reminder r in forDate(now)) {
      if (!r.enabled) continue;
      if (isDone(r, now)) continue;
      if (r.time.hour * 60 + r.time.minute >= nowMin) return r;
    }
    return null;
  }

  // ---- mutations -------------------------------------------------------

  /// Toggling is idempotent for the same occurrence (PRD 2.1 AC1/AC5).
  void toggleDone(Reminder r, DateTime date) {
    final DateTime k = dayKey(date);
    if (r.completions[k] == CompletionStatus.done) {
      r.completions.remove(k);
    } else {
      r.completions[k] = CompletionStatus.done;
    }
    notifyListeners();
  }

  void markDone(Reminder r, DateTime date) {
    r.completions[dayKey(date)] = CompletionStatus.done;
    notifyListeners();
  }

  /// PRD 2.4 — "Skip today" is explicitly distinct from "missed".
  void skipToday(Reminder r, DateTime date) {
    r.completions[dayKey(date)] = CompletionStatus.skipped;
    notifyListeners();
  }

  /// Transient: shifts only the next fire, never the reminder's real time.
  void snooze(Reminder r, int minutes) {
    r.snoozedUntil = DateTime.now().add(Duration(minutes: minutes));
    notifyListeners();
  }

  void clearSnooze(Reminder r) {
    r.snoozedUntil = null;
    notifyListeners();
  }

  /// Disabling preserves history and streaks (PRD 2.1 FR2/AC2).
  void setEnabled(Reminder r, bool value) {
    r.enabled = value;
    notifyListeners();
  }

  void add(Reminder r) {
    _reminders.add(r);
    notifyListeners();
  }

  void update(Reminder updated) {
    final int i = _reminders.indexWhere((Reminder r) => r.id == updated.id);
    if (i >= 0) {
      _reminders[i] = updated;
      notifyListeners();
    }
  }

  /// Deletes the reminder AND its history (PRD 2.4 AC3).
  void delete(String id) {
    _reminders.removeWhere((Reminder r) => r.id == id);
    for (final Reminder r in _reminders) {
      if (r.dependencyId == id) r.dependencyId = null; // avoid orphan link (G.4)
    }
    notifyListeners();
  }

  /// A duplicate is a NEW reminder — fresh id, no shared completion history.
  Reminder duplicate(Reminder r) {
    return Reminder(
      id: IdGen.next('rem'),
      title: '${r.title} (copy)',
      type: r.type,
      time: r.time,
      subtitle: r.subtitle,
      dose: r.dose,
      form: r.form,
      repeat: r.repeat,
      specificDays: Set<int>.from(r.specificDays),
      everyXHours: r.everyXHours,
      duration: r.duration,
      alertType: r.alertType,
      forceConfirmIntervalMinutes: r.forceConfirmIntervalMinutes,
      enabled: r.enabled,
      iconCodePoint: r.iconCodePoint,
      colorValue: r.colorValue,
      dependencyId: r.dependencyId,
      note: r.note,
    );
  }

  StreakStats streakFor(Reminder r, DateTime now) => StreakCalculator.compute(
        r.completions,
        now,
        isScheduled: r.appliesOn,
      );

  int streakDays(Reminder r, DateTime now) => StreakCalculator.currentStreak(
        r.completions,
        now,
        isScheduled: r.appliesOn,
      );

  // ---- water -----------------------------------------------------------

  int waterOn(DateTime date) => _waterLog[dayKey(date)] ?? 0;

  double waterProgress(DateTime date) {
    if (water.goalMl <= 0) return 0; // PRD 1.1 edge case: no divide-by-zero.
    return (waterOn(date) / water.goalMl).clamp(0.0, 1.0);
  }

  void addWater(DateTime date, int ml) {
    final DateTime k = dayKey(date);
    _waterLog[k] = (_waterLog[k] ?? 0) + ml;
    if (_waterLog[k]! < 0) _waterLog[k] = 0;
    notifyListeners();
  }

  void setWaterGoal(int ml) {
    water.goalMl = ml;
    notifyListeners();
  }

  void updateWaterConfig({
    int? goalMl,
    int? everyHours,
    int? fromHour,
    int? untilHour,
    int? amountPerReminderMl,
  }) {
    if (goalMl != null) water.goalMl = goalMl;
    if (everyHours != null) water.everyHours = everyHours;
    if (fromHour != null) water.fromHour = fromHour;
    if (untilHour != null) water.untilHour = untilHour;
    if (amountPerReminderMl != null) {
      water.amountPerReminderMl = amountPerReminderMl;
    }
    notifyListeners();
  }

  // ---- seed ------------------------------------------------------------

  void _seed() {
    final DateTime now = DateTime.now();
    Map<DateTime, CompletionStatus> history(int days, {List<int> miss = const <int>[]}) {
      final Map<DateTime, CompletionStatus> m = <DateTime, CompletionStatus>{};
      for (int i = days; i >= 1; i--) {
        final DateTime d = dayKey(now.subtract(Duration(days: i)));
        m[d] = miss.contains(i)
            ? CompletionStatus.missed
            : CompletionStatus.done;
      }
      return m;
    }

    final Reminder waterReminder = Reminder(
      id: 'rem_water',
      title: 'Water reminder',
      type: ReminderType.water,
      time: const TimeOfDay(hour: 14, minute: 0),
      subtitle: '250 ml · Every 2 hrs',
      repeat: RepeatPattern.everyXHours,
      everyXHours: 2,
      iconCodePoint: Icons.water_drop_outlined.codePoint,
      colorValue: 0xFF185FA5,
      alertType: AlertType.notification,
      completions: history(6, miss: <int>[4]),
    );

    _reminders.addAll(<Reminder>[
      Reminder(
        id: 'rem_metformin',
        title: 'Metformin 500mg',
        type: ReminderType.medicine,
        time: const TimeOfDay(hour: 8, minute: 0),
        subtitle: '1 tablet · After breakfast',
        dose: '500 mg',
        form: 'Tablet',
        iconCodePoint: Icons.medication_outlined.codePoint,
        colorValue: 0xFF3B6D11,
        alertType: AlertType.forceConfirm,
        dependencyId: 'rem_water',
        completions: history(12),
      ),
      Reminder(
        id: 'rem_vitd',
        title: 'Vitamin D3',
        type: ReminderType.medicine,
        time: const TimeOfDay(hour: 8, minute: 30),
        subtitle: '1 capsule · With milk',
        dose: '1 capsule',
        form: 'Capsule',
        iconCodePoint: Icons.medication_liquid_outlined.codePoint,
        colorValue: 0xFF534AB7,
        alertType: AlertType.alarm,
        completions: history(12),
      ),
      Reminder(
        id: 'rem_eyedrops',
        title: 'Eye drops',
        type: ReminderType.custom,
        time: const TimeOfDay(hour: 13, minute: 0),
        subtitle: '2 drops each eye',
        enabled: false,
        iconCodePoint: Icons.notifications_none.codePoint,
        colorValue: 0xFF854F0B,
        alertType: AlertType.notification,
      ),
      waterReminder,
      Reminder(
        id: 'rem_amlodipine',
        title: 'Amlodipine 5mg',
        type: ReminderType.medicine,
        time: const TimeOfDay(hour: 18, minute: 0),
        subtitle: '1 tablet',
        dose: '5 mg',
        form: 'Tablet',
        iconCodePoint: Icons.medication_outlined.codePoint,
        colorValue: 0xFFA32D2D,
        alertType: AlertType.alarm,
        completions: <DateTime, CompletionStatus>{
          dayKey(now.subtract(const Duration(days: 1))): CompletionStatus.missed,
          dayKey(now.subtract(const Duration(days: 2))): CompletionStatus.done,
          dayKey(now.subtract(const Duration(days: 3))): CompletionStatus.done,
        },
      ),
      Reminder(
        id: 'rem_walk',
        title: 'Evening walk',
        type: ReminderType.custom,
        time: const TimeOfDay(hour: 18, minute: 30),
        subtitle: 'Custom · 30 min',
        iconCodePoint: Icons.directions_walk.codePoint,
        colorValue: 0xFF0F6E56,
        alertType: AlertType.notification,
        completions: history(5, miss: <int>[3]),
      ),
    ]);

    _waterLog[dayKey(now)] = 1200;
    _waterLog[dayKey(now.subtract(const Duration(days: 1)))] = 2500;
    _waterLog[dayKey(now.subtract(const Duration(days: 2)))] = 2000;
  }
}
