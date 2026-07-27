import 'package:flutter/material.dart';
import 'enums.dart';

/// A clock alarm. Distinct from a Reminder: an alarm is purely time-based and
/// has no completion history, streak or module linkage.
class Alarm {
  Alarm({
    required this.id,
    required this.time,
    this.label = '',
    Set<int>? repeatDays,
    this.enabled = true,
    this.alertType = AlertType.alarm,
    this.snoozeMinutes = 10,
    this.vibrate = true,
    this.forceConfirmIntervalMinutes = 2,
  }) : repeatDays = repeatDays ?? <int>{};

  final String id;
  TimeOfDay time;
  String label;

  /// 1 = Monday … 7 = Sunday (matches DateTime.weekday).
  /// Empty means a one-off alarm that rings once and then switches itself off.
  Set<int> repeatDays;
  bool enabled;

  /// Reuses the shared three-tier alert system (PRD 2.3 / G.2).
  AlertType alertType;
  int snoozeMinutes;
  bool vibrate;
  int forceConfirmIntervalMinutes;

  /// Transient snooze target — overrides [nextOccurrence] until it passes.
  /// Never rewrites [time], so the alarm's real schedule is preserved.
  DateTime? snoozedUntil;

  bool get repeats => repeatDays.isNotEmpty;
  int get minutesOfDay => time.hour * 60 + time.minute;

  /// The next date-time this alarm should ring, counting from [from].
  ///
  /// For a repeating alarm this is the next matching weekday; for a one-off it
  /// is today if the time is still ahead, otherwise tomorrow.
  DateTime nextOccurrence(DateTime from) {
    if (snoozedUntil != null && snoozedUntil!.isAfter(from)) {
      return snoozedUntil!;
    }
    final DateTime todayAt =
        DateTime(from.year, from.month, from.day, time.hour, time.minute);

    if (!repeats) {
      return todayAt.isAfter(from)
          ? todayAt
          : todayAt.add(const Duration(days: 1));
    }

    for (int offset = 0; offset <= 7; offset++) {
      final DateTime candidate = todayAt.add(Duration(days: offset));
      if (!repeatDays.contains(candidate.weekday)) continue;
      if (candidate.isAfter(from)) return candidate;
    }
    // Unreachable while repeatDays is non-empty, but keeps the return total.
    return todayAt.add(const Duration(days: 7));
  }

  /// "in 8 hr 20 min" style countdown to the next ring.
  String timeUntilLabel(DateTime from) {
    final Duration d = nextOccurrence(from).difference(from);
    if (d.inMinutes < 1) return 'in less than a minute';
    final int days = d.inDays;
    final int hours = d.inHours % 24;
    final int mins = d.inMinutes % 60;
    if (days > 0) return 'in $days day${days == 1 ? '' : 's'} $hours hr';
    if (hours > 0) return 'in $hours hr $mins min';
    return 'in $mins min';
  }

  /// "Every day", "Weekdays", "Mon, Wed, Fri", or "Once".
  String get repeatLabel {
    if (!repeats) return 'Once';
    if (repeatDays.length == 7) return 'Every day';
    if (repeatDays.length == 5 &&
        repeatDays.containsAll(<int>{1, 2, 3, 4, 5})) {
      return 'Weekdays';
    }
    if (repeatDays.length == 2 && repeatDays.containsAll(<int>{6, 7})) {
      return 'Weekends';
    }
    const List<String> names = <String>[
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    ];
    final List<int> sorted = repeatDays.toList()..sort();
    return sorted.map((int d) => names[d - 1]).join(', ');
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'time': minutesOfDay,
        'label': label,
        'repeatDays': repeatDays.toList(),
        'enabled': enabled,
        'alertType': alertType.index,
        'snoozeMinutes': snoozeMinutes,
        'vibrate': vibrate,
        'forceConfirmIntervalMinutes': forceConfirmIntervalMinutes,
        'snoozedUntil': snoozedUntil?.toIso8601String(),
      };

  factory Alarm.fromJson(Map<String, dynamic> j) {
    final int t = j['time'] as int;
    return Alarm(
      id: j['id'] as String,
      time: TimeOfDay(hour: t ~/ 60, minute: t % 60),
      label: j['label'] as String? ?? '',
      repeatDays:
          (j['repeatDays'] as List<dynamic>? ?? <dynamic>[]).cast<int>().toSet(),
      enabled: j['enabled'] as bool? ?? true,
      alertType: AlertType.values[j['alertType'] as int? ?? 1],
      snoozeMinutes: j['snoozeMinutes'] as int? ?? 10,
      vibrate: j['vibrate'] as bool? ?? true,
      forceConfirmIntervalMinutes:
          j['forceConfirmIntervalMinutes'] as int? ?? 2,
    )..snoozedUntil = j['snoozedUntil'] == null
        ? null
        : DateTime.parse(j['snoozedUntil'] as String);
  }

  Alarm copyWith({
    TimeOfDay? time,
    String? label,
    Set<int>? repeatDays,
    bool? enabled,
    AlertType? alertType,
    int? snoozeMinutes,
    bool? vibrate,
    int? forceConfirmIntervalMinutes,
  }) {
    return Alarm(
      id: id,
      time: time ?? this.time,
      label: label ?? this.label,
      repeatDays: repeatDays ?? this.repeatDays,
      enabled: enabled ?? this.enabled,
      alertType: alertType ?? this.alertType,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      vibrate: vibrate ?? this.vibrate,
      forceConfirmIntervalMinutes:
          forceConfirmIntervalMinutes ?? this.forceConfirmIntervalMinutes,
    );
  }
}

/// One recorded lap on the stopwatch.
class Lap {
  const Lap({required this.index, required this.split, required this.total});

  final int index;

  /// Time for this lap alone.
  final Duration split;

  /// Cumulative elapsed time when the lap was taken.
  final Duration total;
}

/// Formats a duration as mm:ss.cc (or h:mm:ss.cc past an hour).
String formatStopwatch(Duration d) {
  final int hours = d.inHours;
  final String mm = (d.inMinutes % 60).toString().padLeft(2, '0');
  final String ss = (d.inSeconds % 60).toString().padLeft(2, '0');
  final String cc =
      ((d.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$mm:$ss.$cc';
  return '$mm:$ss.$cc';
}
