import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/services/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifeos/data/stores/persistence.dart';
import 'package:lifeos/data/stores/settings_store.dart';
import 'package:lifeos/data/stores/reminder_store.dart';
import 'package:lifeos/data/stores/planner_store.dart';
import 'package:lifeos/data/stores/alarm_store.dart';
import 'package:lifeos/data/stores/expense_store.dart';
import 'package:lifeos/data/stores/health_store.dart';
import 'package:lifeos/data/stores/commitments_store.dart';
import 'package:lifeos/data/stores/lists_notes_store.dart';
import 'dart:convert';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Persistence.reset();
  });

  test('a backup taken on a fresh install contains every module', () async {
    // Mirrors main(): construct every store, then flush once.
    SettingsStore().flush();
    ReminderStore().flush();
    PlannerStore().flush();
    AlarmStore().flush();
    ExpenseStore().flush();
    HealthStore().flush();
    CommitmentsStore().flush();
    ListsNotesStore().flush();

    final Map<String, dynamic> parsed =
        jsonDecode(await BackupService.buildBackup()) as Map<String, dynamic>;
    final Map<String, dynamic> data = parsed['data'] as Map<String, dynamic>;

    for (final String key in <String>[
      'settings',
      'reminders',
      'planner',
      'alarms',
      'expenses',
      'health',
      'commitments',
      'lists_notes',
    ]) {
      expect(data.containsKey(key), isTrue, reason: '$key missing from backup');
    }
    expect(parsed['app'], 'LifeOS');
    expect(parsed['formatVersion'], BackupService.formatVersion);
    expect(parsed.containsKey('appVersion'), isTrue);
  });

  test('a backup round-trips back into storage', () async {
    ReminderStore()..seed()..flush();
    final String backup = await BackupService.buildBackup();
    final Map<String, dynamic> data = (jsonDecode(backup)
        as Map<String, dynamic>)['data'] as Map<String, dynamic>;

    // Wipe, then re-apply exactly what restoreFromFile would write.
    Persistence.save('reminders', <String, dynamic>{});
    Persistence.save('reminders', data['reminders'] as Map<String, dynamic>);

    final ReminderStore restored = ReminderStore();
    expect(restored.all.length, greaterThan(0));
  });
}
