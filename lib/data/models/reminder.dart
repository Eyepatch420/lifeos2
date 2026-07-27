import 'package:flutter/material.dart';
import 'enums.dart';

/// A single reminder (PRD 2.1-2.4).
class Reminder {
  Reminder({
    required this.id,
    required this.title,
    required this.type,
    required this.time,
    this.subtitle = '',
    this.dose = '',
    this.form = '',
    this.repeat = RepeatPattern.daily,
    this.specificDays = const <int>{},
    this.everyXHours = 2,
    this.duration = 'Ongoing',
    this.alertType = AlertType.alarm,
    this.forceConfirmIntervalMinutes = 2,
    this.enabled = true,
    this.iconCodePoint = 0xe80e,
    this.colorValue = 0xFF185FA5,
    this.dependencyId,
    this.prescriptionPath,
    this.costPaise,
    this.note = '',
    this.notifStyle = 'Sound',
    this.startedOn,
    Map<DateTime, CompletionStatus>? completions,
  }) : completions = completions ?? <DateTime, CompletionStatus>{};

  final String id;
  String title;
  ReminderType type;
  TimeOfDay time;
  String subtitle;
  String dose;
  String form;
  RepeatPattern repeat;

  /// 1 = Monday … 7 = Sunday (matches DateTime.weekday).
  Set<int> specificDays;
  int everyXHours;
  String duration;
  AlertType alertType;
  int forceConfirmIntervalMinutes;
  bool enabled;
  int iconCodePoint;
  int colorValue;

  /// PRD 2.1 FR7 — chained reminders don't fire until their dependency is done.
  String? dependencyId;
  String? prescriptionPath;
  int? costPaise;
  String note;

  /// Transient snooze target — the scheduler fires at this instead of [time]
  /// until it passes. Never rewrites [time] (snooze must not be destructive).
  DateTime? snoozedUntil;

  /// 'Sound' | 'Vibrate' | 'Silent' — how the alert presents itself.
  String notifStyle;

  /// When the course began, so a fixed [duration] can expire it (PRD 2.2).
  DateTime? startedOn;

  /// A course like "7 days" stops applying once it has run its length.
  /// "Ongoing" never expires.
  bool hasExpired(DateTime now) {
    final DateTime? from = startedOn;
    if (from == null) return false;
    final RegExpMatch? m =
        RegExp(r'(\d+)\s*(day|week|month)', caseSensitive: false)
            .firstMatch(duration);
    if (m == null) return false;
    final int n = int.parse(m.group(1)!);
    final int days = switch (m.group(2)!.toLowerCase()) {
      'week' => n * 7,
      'month' => n * 30,
      _ => n,
    };
    return now.difference(from).inDays >= days;
  }

  /// Date-keyed completion log (date normalised to midnight).
  final Map<DateTime, CompletionStatus> completions;

  Color get color => Color(colorValue);
  // ignore: non_const_argument_for_const_parameter
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  /// PRD 2.1 — configurable time-of-day buckets. A reminder landing exactly on
  /// a boundary (12:00) is deliberately bucketed as Afternoon.
  String get bucket {
    final int m = time.hour * 60 + time.minute;
    if (m < 12 * 60) return 'Morning';
    if (m < 17 * 60) return 'Afternoon';
    return 'Evening';
  }

  bool get isForceConfirm => alertType == AlertType.forceConfirm;

  /// Does this reminder apply on the given date at all?
  bool appliesOn(DateTime date) {
    switch (repeat) {
      case RepeatPattern.daily:
      case RepeatPattern.everyXHours:
        return true;
      case RepeatPattern.specificDays:
        return specificDays.contains(date.weekday);
      case RepeatPattern.weekly:
        return date.weekday == DateTime.monday;
      case RepeatPattern.monthly:
        return date.day == 1;
      case RepeatPattern.sos:
        return false;
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'type': type.index,
        'time': time.hour * 60 + time.minute,
        'subtitle': subtitle,
        'dose': dose,
        'form': form,
        'repeat': repeat.index,
        'specificDays': specificDays.toList(),
        'everyXHours': everyXHours,
        'duration': duration,
        'alertType': alertType.index,
        'forceConfirmIntervalMinutes': forceConfirmIntervalMinutes,
        'enabled': enabled,
        'iconCodePoint': iconCodePoint,
        'colorValue': colorValue,
        'dependencyId': dependencyId,
        'prescriptionPath': prescriptionPath,
        'costPaise': costPaise,
        'note': note,
        'notifStyle': notifStyle,
        'startedOn': startedOn?.toIso8601String(),
        'snoozedUntil': snoozedUntil?.toIso8601String(),
        'completions': completions.map((DateTime k, CompletionStatus v) =>
            MapEntry<String, int>(k.toIso8601String(), v.index)),
      };

  factory Reminder.fromJson(Map<String, dynamic> j) {
    final int t = j['time'] as int;
    return Reminder(
      id: j['id'] as String,
      title: j['title'] as String,
      type: ReminderType.values[j['type'] as int],
      time: TimeOfDay(hour: t ~/ 60, minute: t % 60),
      subtitle: j['subtitle'] as String? ?? '',
      dose: j['dose'] as String? ?? '',
      form: j['form'] as String? ?? '',
      repeat: RepeatPattern.values[j['repeat'] as int? ?? 0],
      specificDays:
          (j['specificDays'] as List<dynamic>? ?? <dynamic>[]).cast<int>().toSet(),
      everyXHours: j['everyXHours'] as int? ?? 2,
      duration: j['duration'] as String? ?? 'Ongoing',
      alertType: AlertType.values[j['alertType'] as int? ?? 1],
      forceConfirmIntervalMinutes: j['forceConfirmIntervalMinutes'] as int? ?? 2,
      enabled: j['enabled'] as bool? ?? true,
      iconCodePoint: j['iconCodePoint'] as int? ?? 0xe80e,
      colorValue: j['colorValue'] as int? ?? 0xFF185FA5,
      dependencyId: j['dependencyId'] as String?,
      prescriptionPath: j['prescriptionPath'] as String?,
      costPaise: j['costPaise'] as int?,
      note: j['note'] as String? ?? '',
      notifStyle: j['notifStyle'] as String? ?? 'Sound',
      startedOn: j['startedOn'] == null
          ? null
          : DateTime.parse(j['startedOn'] as String),
      completions: (j['completions'] as Map<String, dynamic>? ?? <String, dynamic>{})
          .map((String k, dynamic v) => MapEntry<DateTime, CompletionStatus>(
              DateTime.parse(k), CompletionStatus.values[v as int])),
    )..snoozedUntil = j['snoozedUntil'] == null
        ? null
        : DateTime.parse(j['snoozedUntil'] as String);
  }

  Reminder copyWith({
    String? title,
    ReminderType? type,
    TimeOfDay? time,
    String? subtitle,
    String? dose,
    String? form,
    RepeatPattern? repeat,
    Set<int>? specificDays,
    int? everyXHours,
    String? duration,
    AlertType? alertType,
    int? forceConfirmIntervalMinutes,
    bool? enabled,
    int? iconCodePoint,
    int? colorValue,
    String? dependencyId,
    String? note,
  }) {
    return Reminder(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      time: time ?? this.time,
      subtitle: subtitle ?? this.subtitle,
      dose: dose ?? this.dose,
      form: form ?? this.form,
      repeat: repeat ?? this.repeat,
      specificDays: specificDays ?? this.specificDays,
      everyXHours: everyXHours ?? this.everyXHours,
      duration: duration ?? this.duration,
      alertType: alertType ?? this.alertType,
      forceConfirmIntervalMinutes:
          forceConfirmIntervalMinutes ?? this.forceConfirmIntervalMinutes,
      enabled: enabled ?? this.enabled,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      dependencyId: dependencyId ?? this.dependencyId,
      prescriptionPath: prescriptionPath,
      costPaise: costPaise,
      note: note ?? this.note,
      notifStyle: notifStyle,
      startedOn: startedOn,
      completions: completions,
    );
  }
}

/// PRD 2.1 / 2.2 — water tracking config + per-day log, shared with Home (1.1).
class WaterConfig {
  WaterConfig({
    this.goalMl = 2500,
    this.everyHours = 2,
    this.fromHour = 7,
    this.untilHour = 22,
    this.amountPerReminderMl = 250,
  });

  int goalMl;
  int everyHours;
  int fromHour;
  int untilHour;
  int amountPerReminderMl;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'goalMl': goalMl,
        'everyHours': everyHours,
        'fromHour': fromHour,
        'untilHour': untilHour,
        'amountPerReminderMl': amountPerReminderMl,
      };

  factory WaterConfig.fromJson(Map<String, dynamic> j) => WaterConfig(
        goalMl: j['goalMl'] as int? ?? 2500,
        everyHours: j['everyHours'] as int? ?? 2,
        fromHour: j['fromHour'] as int? ?? 7,
        untilHour: j['untilHour'] as int? ?? 22,
        amountPerReminderMl: j['amountPerReminderMl'] as int? ?? 250,
      );
}
