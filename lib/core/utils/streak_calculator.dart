import '../../data/models/enums.dart';
import 'date_x.dart';

/// PRD G.5 — ONE streak implementation, used by Home (1.1/1.2), Planner
/// habits (3.1) and Consolidated Progress (1.3), so the numbers can never
/// drift apart between screens.
class StreakStats {
  const StreakStats({
    required this.current,
    required this.best,
    required this.completionRate,
    required this.totalSessions,
    required this.missedThisMonth,
    required this.bestDayOfWeek,
    required this.scheduledThisMonth,
    required this.doneThisMonth,
  });

  final int current;
  final int best;

  /// 0.0-1.0. Partial days count as half (documented in PRD 1.2 AC3).
  final double completionRate;
  final int totalSessions;
  final int missedThisMonth;

  /// 1 = Monday … 7 = Sunday. Null when there is no data yet.
  final int? bestDayOfWeek;
  final int scheduledThisMonth;
  final int doneThisMonth;

  static const StreakStats empty = StreakStats(
    current: 0,
    best: 0,
    completionRate: 0,
    totalSessions: 0,
    missedThisMonth: 0,
    bestDayOfWeek: null,
    scheduledThisMonth: 0,
    doneThisMonth: 0,
  );
}

class StreakCalculator {
  const StreakCalculator._();

  /// Whether a day counts toward keeping a streak alive.
  static bool _keepsStreak(CompletionStatus? s, {required bool skipBreaks}) {
    if (s == CompletionStatus.done || s == CompletionStatus.partial) return true;
    // Rest days (habit not scheduled) never break a streak.
    if (s == CompletionStatus.rest || s == null) return false;
    if (s == CompletionStatus.skipped) return !skipBreaks;
    return false;
  }

  /// Current consecutive streak counting back from [now].
  ///
  /// [isScheduled] lets the caller exclude unscheduled days so a Mon/Wed/Fri
  /// habit is not penalised on a Tuesday (PRD 3.1 AC1).
  /// [skipBreaksStreak] resolves PRD Gap 8: by default "Skip today" PRESERVES
  /// the streak (treated like a rest day) rather than breaking it.
  static int currentStreak(
    Map<DateTime, CompletionStatus> log,
    DateTime now, {
    bool Function(DateTime)? isScheduled,
    bool skipBreaksStreak = false,
    int lookbackDays = 400,
  }) {
    int streak = 0;
    DateTime cursor = dayKey(now);

    // Today not yet actioned should not immediately zero an existing streak.
    final CompletionStatus? todayStatus = log[cursor];
    if (todayStatus == null ||
        todayStatus == CompletionStatus.rest ||
        (isScheduled != null && !isScheduled(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    for (int i = 0; i < lookbackDays; i++) {
      final bool scheduled = isScheduled?.call(cursor) ?? true;
      if (!scheduled) {
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }
      final CompletionStatus? s = log[cursor];
      if (_keepsStreak(s, skipBreaks: skipBreaksStreak)) {
        if (s == CompletionStatus.done || s == CompletionStatus.partial) {
          streak++;
        }
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }
      if (s == CompletionStatus.skipped && !skipBreaksStreak) {
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }
      break;
    }
    return streak;
  }

  /// Longest streak ever achieved. Never decreases once earned (PRD 1.2 AC2).
  static int bestStreak(
    Map<DateTime, CompletionStatus> log, {
    bool Function(DateTime)? isScheduled,
    bool skipBreaksStreak = false,
  }) {
    if (log.isEmpty) return 0;
    final List<DateTime> days = log.keys.toList()..sort();
    final DateTime first = days.first;
    final DateTime last = days.last;

    int best = 0;
    int run = 0;
    DateTime cursor = first;
    while (!cursor.isAfter(last)) {
      final bool scheduled = isScheduled?.call(cursor) ?? true;
      if (!scheduled) {
        cursor = cursor.add(const Duration(days: 1));
        continue;
      }
      final CompletionStatus? s = log[cursor];
      if (s == CompletionStatus.done || s == CompletionStatus.partial) {
        run++;
        if (run > best) best = run;
      } else if (s == CompletionStatus.skipped && !skipBreaksStreak) {
        // neither extends nor breaks
      } else {
        run = 0;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return best;
  }

  /// Full stats bundle for the streak detail screen (PRD 1.2).
  static StreakStats compute(
    Map<DateTime, CompletionStatus> log,
    DateTime now, {
    bool Function(DateTime)? isScheduled,
    bool skipBreaksStreak = false,
  }) {
    if (log.isEmpty) {
      return const StreakStats(
        current: 0,
        best: 0,
        completionRate: 0,
        totalSessions: 0,
        missedThisMonth: 0,
        bestDayOfWeek: null,
        scheduledThisMonth: 0,
        doneThisMonth: 0,
      );
    }

    final DateTime monthStart = startOfMonth(now);
    int scheduled = 0;
    int done = 0;
    int partial = 0;
    int missed = 0;

    log.forEach((DateTime d, CompletionStatus s) {
      if (d.isBefore(monthStart) || d.isAfter(dayKey(now))) return;
      if (s == CompletionStatus.rest) return;
      scheduled++;
      if (s == CompletionStatus.done) done++;
      if (s == CompletionStatus.partial) partial++;
      if (s == CompletionStatus.missed) missed++;
    });

    // PRD 1.2 AC3: (done + 0.5 * partial) / scheduled.
    final double rate =
        scheduled == 0 ? 0 : ((done + 0.5 * partial) / scheduled).clamp(0.0, 1.0);

    final int totalSessions = log.values
        .where((CompletionStatus s) =>
            s == CompletionStatus.done || s == CompletionStatus.partial)
        .length;

    // Most consistent day of week across all history.
    final Map<int, int> hits = <int, int>{};
    final Map<int, int> chances = <int, int>{};
    log.forEach((DateTime d, CompletionStatus s) {
      if (s == CompletionStatus.rest) return;
      chances[d.weekday] = (chances[d.weekday] ?? 0) + 1;
      if (s == CompletionStatus.done || s == CompletionStatus.partial) {
        hits[d.weekday] = (hits[d.weekday] ?? 0) + 1;
      }
    });
    int? bestDay;
    double bestRatio = -1;
    chances.forEach((int wd, int total) {
      final double r = (hits[wd] ?? 0) / total;
      if (r > bestRatio) {
        bestRatio = r;
        bestDay = wd;
      }
    });

    return StreakStats(
      current: currentStreak(log, now,
          isScheduled: isScheduled, skipBreaksStreak: skipBreaksStreak),
      best: bestStreak(log,
          isScheduled: isScheduled, skipBreaksStreak: skipBreaksStreak),
      completionRate: rate,
      totalSessions: totalSessions,
      missedThisMonth: missed,
      bestDayOfWeek: bestDay,
      scheduledThisMonth: scheduled,
      doneThisMonth: done + partial,
    );
  }

  /// Milestone thresholds live in ONE place (PRD 1.2 FR4).
  static const List<int> milestones = <int>[7, 14, 30, 60, 100];

  /// How many times a given milestone length has been achieved historically.
  static int milestoneHits(
    Map<DateTime, CompletionStatus> log,
    int length, {
    bool Function(DateTime)? isScheduled,
  }) {
    if (log.isEmpty) return 0;
    final List<DateTime> days = log.keys.toList()..sort();
    int hitCount = 0;
    int run = 0;
    DateTime cursor = days.first;
    final DateTime last = days.last;
    while (!cursor.isAfter(last)) {
      final bool scheduled = isScheduled?.call(cursor) ?? true;
      if (!scheduled) {
        cursor = cursor.add(const Duration(days: 1));
        continue;
      }
      final CompletionStatus? s = log[cursor];
      if (s == CompletionStatus.done || s == CompletionStatus.partial) {
        run++;
        if (run == length) hitCount++;
      } else if (s != CompletionStatus.skipped) {
        run = 0;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return hitCount;
  }
}
