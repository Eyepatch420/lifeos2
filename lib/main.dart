import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/services/notification_service.dart';
import 'data/stores/alarm_store.dart';
import 'data/stores/commitments_store.dart';
import 'data/stores/expense_store.dart';
import 'data/stores/health_store.dart';
import 'data/stores/lists_notes_store.dart';
import 'data/stores/persistence.dart';
import 'data/stores/planner_store.dart';
import 'data/stores/reminder_store.dart';
import 'data/stores/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Persistence.init();
  await NotificationService.init();

  final SettingsStore settingsStore = SettingsStore();
  final ReminderStore reminderStore = ReminderStore();
  final PlannerStore plannerStore = PlannerStore();
  final AlarmStore alarmStore = AlarmStore();
  final CommitmentsStore commitmentsStore = CommitmentsStore();

  // Notification actions ("Done"/"Snooze") mutate stores directly, so the
  // service needs handles that outlive any widget.
  NotificationService.bindStores(reminderStore, alarmStore);

  // Keep the device notification schedule in lock-step with store state.
  void sync() => NotificationService.syncAll(
        reminderStore,
        plannerStore,
        alarms: alarmStore,
        commitments: commitmentsStore,
        settings: settingsStore,
      );
  reminderStore.addListener(sync);
  plannerStore.addListener(sync);
  alarmStore.addListener(sync);
  commitmentsStore.addListener(sync);
  settingsStore.addListener(sync);
  sync();

  final ExpenseStore expenseStore = ExpenseStore();
  final HealthStore healthStore = HealthStore();
  final ListsNotesStore listsNotesStore = ListsNotesStore();

  // Write every store once at startup. Without this, a store the user hasn't
  // touched yet has nothing on disk, so a backup taken on a fresh install
  // would silently omit it.
  settingsStore.flush();
  reminderStore.flush();
  plannerStore.flush();
  alarmStore.flush();
  commitmentsStore.flush();
  expenseStore.flush();
  healthStore.flush();
  listsNotesStore.flush();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsStore>.value(value: settingsStore),
        ChangeNotifierProvider<AlarmStore>.value(value: alarmStore),
        ChangeNotifierProvider<ReminderStore>.value(value: reminderStore),
        ChangeNotifierProvider<PlannerStore>.value(value: plannerStore),
        ChangeNotifierProvider<CommitmentsStore>.value(value: commitmentsStore),
        ChangeNotifierProvider<ExpenseStore>.value(value: expenseStore),
        ChangeNotifierProvider<HealthStore>.value(value: healthStore),
        ChangeNotifierProvider<ListsNotesStore>.value(value: listsNotesStore),
      ],
      child: const LifeOSApp(),
    ),
  );
}
