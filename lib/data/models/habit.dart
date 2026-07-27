import 'package:flutter/material.dart';
import 'enums.dart';

/// A recurring habit tracked by the Planner and surfaced on Home (PRD 3.1/1.2).
class Habit {
  Habit({
    required this.id,
    required this.name,
    this.durationMinutes = 30,
    this.preferredTime,
    this.repeat = RepeatPattern.daily,
    this.days = const <int>{1, 2, 3, 4, 5, 6, 7},
    this.colorValue = 0xFF3B6D11,
    this.iconCodePoint = 0xe1d5,
    this.goalStreak,
    this.note = '',
    Map<DateTime, CompletionStatus>? completions,
  }) : completions = completions ?? <DateTime, CompletionStatus>{};

  final String id;
  String name;
  int durationMinutes;
  TimeOfDay? preferredTime;
  RepeatPattern repeat;

  /// 1 = Monday … 7 = Sunday.
  Set<int> days;
  int colorValue;
  int iconCodePoint;

  /// Optional target streak set via "Set goal" (PRD 3.3).
  int? goalStreak;
  String note;
  final Map<DateTime, CompletionStatus> completions;

  Color get color => Color(colorValue);
  // ignore: non_const_argument_for_const_parameter
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'durationMinutes': durationMinutes,
        'preferredTime': preferredTime == null
            ? null
            : preferredTime!.hour * 60 + preferredTime!.minute,
        'repeat': repeat.index,
        'days': days.toList(),
        'colorValue': colorValue,
        'iconCodePoint': iconCodePoint,
        'goalStreak': goalStreak,
        'note': note,
        'completions': completions.map((DateTime k, CompletionStatus v) =>
            MapEntry<String, int>(k.toIso8601String(), v.index)),
      };

  factory Habit.fromJson(Map<String, dynamic> j) {
    final int? pt = j['preferredTime'] as int?;
    return Habit(
      id: j['id'] as String,
      name: j['name'] as String,
      durationMinutes: j['durationMinutes'] as int? ?? 30,
      preferredTime:
          pt == null ? null : TimeOfDay(hour: pt ~/ 60, minute: pt % 60),
      repeat: RepeatPattern.values[j['repeat'] as int? ?? 0],
      days: (j['days'] as List<dynamic>? ?? <dynamic>[1, 2, 3, 4, 5, 6, 7])
          .cast<int>()
          .toSet(),
      colorValue: j['colorValue'] as int? ?? 0xFF3B6D11,
      iconCodePoint: j['iconCodePoint'] as int? ?? 0xe1d5,
      goalStreak: j['goalStreak'] as int?,
      note: j['note'] as String? ?? '',
      completions: (j['completions'] as Map<String, dynamic>? ?? <String, dynamic>{})
          .map((String k, dynamic v) => MapEntry<DateTime, CompletionStatus>(
              DateTime.parse(k), CompletionStatus.values[v as int])),
    );
  }

  /// Is the habit scheduled on this date? Unscheduled days render as "rest",
  /// never as "missed" (PRD 3.1 AC1).
  bool isScheduledOn(DateTime date) {
    switch (repeat) {
      case RepeatPattern.daily:
        return true;
      case RepeatPattern.specificDays:
        return days.contains(date.weekday);
      case RepeatPattern.weekly:
        return date.weekday == DateTime.monday;
      case RepeatPattern.monthly:
        return date.day == 1;
      case RepeatPattern.everyXHours:
      case RepeatPattern.sos:
        return true;
    }
  }
}

/// Events, appointments and tasks in the Planner (PRD 3.1-3.3).
class PlannerEvent {
  PlannerEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.start,
    this.durationMinutes = 60,
    this.location = '',
    this.note = '',
    this.colorValue = 0xFF534AB7,
    this.done = false,
    this.reminderLeadMinutes,
  });

  final String id;
  String title;
  PlannerItemType type;
  DateTime start;
  int durationMinutes;
  String location;
  String note;
  int colorValue;

  /// Only meaningful for PlannerItemType.task.
  bool done;
  int? reminderLeadMinutes;

  Color get color => Color(colorValue);
  DateTime get end => start.add(Duration(minutes: durationMinutes));

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'type': type.index,
        'start': start.toIso8601String(),
        'durationMinutes': durationMinutes,
        'location': location,
        'note': note,
        'colorValue': colorValue,
        'done': done,
        'reminderLeadMinutes': reminderLeadMinutes,
      };

  factory PlannerEvent.fromJson(Map<String, dynamic> j) => PlannerEvent(
        id: j['id'] as String,
        title: j['title'] as String,
        type: PlannerItemType.values[j['type'] as int],
        start: DateTime.parse(j['start'] as String),
        durationMinutes: j['durationMinutes'] as int? ?? 60,
        location: j['location'] as String? ?? '',
        note: j['note'] as String? ?? '',
        colorValue: j['colorValue'] as int? ?? 0xFF534AB7,
        done: j['done'] as bool? ?? false,
        reminderLeadMinutes: j['reminderLeadMinutes'] as int?,
      );

  String get badgeLabel => switch (type) {
        PlannerItemType.appointment => 'Appointment',
        PlannerItemType.event => 'Event',
        PlannerItemType.task => 'Task',
        PlannerItemType.habit => 'Habit',
      };
}
