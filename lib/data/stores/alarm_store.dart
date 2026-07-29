import 'package:flutter/material.dart';

import '../models/alarm.dart';
import '../models/enums.dart';
import 'id_gen.dart';
import 'persistence.dart';

/// Owns the clock alarms. Stopwatch state deliberately lives in the screen,
/// not here — it is transient UI state, not app data.
class AlarmStore extends ChangeNotifier {
  AlarmStore() {
    _load();
  }

  static const String _key = 'alarms';

  final List<Alarm> _alarms = <Alarm>[];

  bool _load() {
    final Map<String, dynamic>? j = Persistence.load(_key);
    if (j == null) return false;
    _alarms.addAll((j['alarms'] as List<dynamic>)
        .map((dynamic a) => Alarm.fromJson(a as Map<String, dynamic>)));
    return true;
  }

  void flush() {
    Persistence.save(_key, <String, dynamic>{
      'alarms': _alarms.map((Alarm a) => a.toJson()).toList(),
    });
  }

  @override
  void notifyListeners() {
    flush();
    super.notifyListeners();
  }

  List<Alarm> get all {
    final List<Alarm> list = List<Alarm>.from(_alarms);
    list.sort((Alarm a, Alarm b) => a.minutesOfDay.compareTo(b.minutesOfDay));
    return list;
  }

  List<Alarm> get enabled => all.where((Alarm a) => a.enabled).toList();

  Alarm? byId(String id) {
    for (final Alarm a in _alarms) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// The alarm that will ring soonest, or null if none are enabled.
  Alarm? nextAlarm(DateTime now) {
    final List<Alarm> active = enabled;
    if (active.isEmpty) return null;
    active.sort((Alarm a, Alarm b) =>
        a.nextOccurrence(now).compareTo(b.nextOccurrence(now)));
    return active.first;
  }

  void add(Alarm a) {
    _alarms.add(a);
    notifyListeners();
  }

  void update(Alarm a) {
    final int i = _alarms.indexWhere((Alarm x) => x.id == a.id);
    if (i >= 0) _alarms[i] = a;
    notifyListeners();
  }

  void delete(String id) {
    _alarms.removeWhere((Alarm a) => a.id == id);
    notifyListeners();
  }

  void setEnabled(Alarm a, bool value) {
    a.enabled = value;
    notifyListeners();
  }

  void toggle(Alarm a) => setEnabled(a, !a.enabled);

  /// Pushes the NEXT ring forward by the snooze duration without touching the
  /// alarm's real schedule (PRD: snooze is transient, never destructive).
  void snooze(Alarm a) {
    a.snoozedUntil = DateTime.now().add(Duration(minutes: a.snoozeMinutes));
    notifyListeners();
  }

  void clearSnooze(Alarm a) {
    a.snoozedUntil = null;
    notifyListeners();
  }

  /// A duplicate is a NEW alarm — it must never share the original's id.
  Alarm duplicate(Alarm a) => Alarm(
        id: IdGen.next('alm'),
        time: a.time,
        label: a.label.isEmpty ? 'Copy' : '${a.label} (copy)',
        repeatDays: Set<int>.from(a.repeatDays),
        enabled: a.enabled,
        alertType: a.alertType,
        snoozeMinutes: a.snoozeMinutes,
        vibrate: a.vibrate,
        forceConfirmIntervalMinutes: a.forceConfirmIntervalMinutes,
      );

  void seed() {
    _alarms.addAll(<Alarm>[
      Alarm(
        id: IdGen.next('alm'),
        time: const TimeOfDay(hour: 6, minute: 0),
        label: 'Morning jog',
        repeatDays: <int>{1, 2, 3, 4, 5},
        alertType: AlertType.alarm,
      ),
      Alarm(
        id: IdGen.next('alm'),
        time: const TimeOfDay(hour: 7, minute: 45),
        label: 'Leave for work',
        repeatDays: <int>{1, 2, 3, 4, 5},
        alertType: AlertType.notification,
      ),
      Alarm(
        id: IdGen.next('alm'),
        time: const TimeOfDay(hour: 22, minute: 30),
        label: 'Wind down / medicines',
        repeatDays: <int>{1, 2, 3, 4, 5, 6, 7},
        alertType: AlertType.forceConfirm,
      ),
      Alarm(
        id: IdGen.next('alm'),
        time: const TimeOfDay(hour: 9, minute: 0),
        label: 'Weekend lie-in check',
        repeatDays: <int>{6, 7},
        enabled: false,
      ),
    ]);
  }
}
