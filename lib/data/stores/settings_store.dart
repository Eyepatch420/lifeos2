import 'package:flutter/material.dart';

import '../models/enums.dart';
import 'persistence.dart';

/// App-wide preferences and profile (PRD 10.1).
class SettingsStore extends ChangeNotifier {
  SettingsStore() {
    _load();
  }

  static const String _key = 'settings';

  void _load() {
    final Map<String, dynamic>? j = Persistence.load(_key);
    if (j == null) return;
    name = j['name'] as String? ?? name;
    email = j['email'] as String? ?? email;
    age = j['age'] as int?;
    weightKg = (j['weightKg'] as num?)?.toDouble();
    defaultAlertType = AlertType.values[j['defaultAlertType'] as int? ?? 1];
    final int ds = j['dndStart'] as int? ?? 23 * 60;
    final int de = j['dndEnd'] as int? ?? 6 * 60;
    dndStart = TimeOfDay(hour: ds ~/ 60, minute: ds % 60);
    dndEnd = TimeOfDay(hour: de ~/ 60, minute: de % 60);
    defaultSnoozeMinutes = j['defaultSnoozeMinutes'] as int? ?? 10;
    appLockEnabled = j['appLockEnabled'] as bool? ?? true;
    biometricPreferred = j['biometricPreferred'] as bool? ?? true;
    themeMode = ThemeMode.values[j['themeMode'] as int? ?? 0];
    language = j['language'] as String? ?? 'English';
    weeklyDigestEnabled = j['weeklyDigestEnabled'] as bool? ?? true;
  }

  void flush() {
    Persistence.save(_key, <String, dynamic>{
      'name': name,
      'email': email,
      'age': age,
      'weightKg': weightKg,
      'defaultAlertType': defaultAlertType.index,
      'dndStart': dndStart.hour * 60 + dndStart.minute,
      'dndEnd': dndEnd.hour * 60 + dndEnd.minute,
      'defaultSnoozeMinutes': defaultSnoozeMinutes,
      'appLockEnabled': appLockEnabled,
      'biometricPreferred': biometricPreferred,
      'themeMode': themeMode.index,
      'language': language,
      'weeklyDigestEnabled': weeklyDigestEnabled,
    });
  }

  @override
  void notifyListeners() {
    flush();
    super.notifyListeners();
  }

  String name = 'testuser';
  String email = 'testuser@gmail.com';
  int? age = 32;
  double? weightKg = 74;

  /// Defaults only pre-select in the Add flows; they never rewrite existing
  /// reminders (PRD 10.1 FR1 / AC1).
  AlertType defaultAlertType = AlertType.alarm;
  TimeOfDay dndStart = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay dndEnd = const TimeOfDay(hour: 6, minute: 0);
  int defaultSnoozeMinutes = 10;

  bool appLockEnabled = true;
  bool biometricPreferred = true;

  ThemeMode themeMode = ThemeMode.system;
  String language = 'English';

  /// Weekly insights digest (recommended feature from the PRD).
  bool weeklyDigestEnabled = true;

  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  void setName(String v) {
    name = v;
    notifyListeners();
  }

  void setEmail(String v) {
    email = v;
    notifyListeners();
  }

  void setProfile({int? age, double? weightKg}) {
    if (age != null) this.age = age;
    if (weightKg != null) this.weightKg = weightKg;
    notifyListeners();
  }

  void setDefaultAlertType(AlertType t) {
    defaultAlertType = t;
    notifyListeners();
  }

  void setDnd(TimeOfDay start, TimeOfDay end) {
    dndStart = start;
    dndEnd = end;
    notifyListeners();
  }

  void setSnooze(int minutes) {
    defaultSnoozeMinutes = minutes;
    notifyListeners();
  }

  void setAppLock(bool v) {
    appLockEnabled = v;
    notifyListeners();
  }

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    notifyListeners();
  }

  void setLanguage(String l) {
    language = l;
    notifyListeners();
  }

  void setWeeklyDigest(bool v) {
    weeklyDigestEnabled = v;
    notifyListeners();
  }
}
