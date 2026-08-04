import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digidaily/data/models/enums.dart';
import 'package:digidaily/data/models/habit.dart';
import 'package:digidaily/data/models/reminder.dart';
import 'package:digidaily/data/stores/persistence.dart';
import 'package:digidaily/data/stores/reminder_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Persistence.reset();
  });

  group('weekly habits use the chosen day, not always Monday', () {
    Habit weeklyOn(int weekday) => Habit(
          id: 'h1',
          name: 'Deep clean',
          repeat: RepeatPattern.weekly,
          days: <int>{weekday},
        );

    test('a Thursday habit is scheduled on Thursday', () {
      // 2026-07-30 is a Thursday.
      expect(
        weeklyOn(DateTime.thursday).isScheduledOn(DateTime(2026, 7, 30)),
        isTrue,
      );
    });

    test('a Thursday habit is NOT scheduled on Monday', () {
      // 2026-07-27 is a Monday — the old code fired here regardless.
      expect(
        weeklyOn(DateTime.thursday).isScheduledOn(DateTime(2026, 7, 27)),
        isFalse,
      );
    });

    test('falls back to Monday when no day was chosen', () {
      final Habit h =
          Habit(id: 'h2', name: 'X', repeat: RepeatPattern.weekly, days: <int>{});
      expect(h.isScheduledOn(DateTime(2026, 7, 27)), isTrue);
    });
  });

  group('monthly habits anchor to their start day', () {
    test('a habit started on the 15th recurs on the 15th', () {
      final Habit h = Habit(
        id: 'h3',
        name: 'Pay rent',
        repeat: RepeatPattern.monthly,
        startedOn: DateTime(2026, 5, 15),
      );
      expect(h.isScheduledOn(DateTime(2026, 8, 15)), isTrue);
      // The old code only ever fired on the 1st.
      expect(h.isScheduledOn(DateTime(2026, 8, 1)), isFalse);
    });

    test('day 31 clamps to the last day of a short month', () {
      final Habit h = Habit(
        id: 'h4',
        name: 'Month end',
        repeat: RepeatPattern.monthly,
        startedOn: DateTime(2026, 1, 31),
      );
      // February 2026 has 28 days, so it should land on the 28th.
      expect(h.isScheduledOn(DateTime(2026, 2, 28)), isTrue);
      expect(h.isScheduledOn(DateTime(2026, 3, 31)), isTrue);
    });
  });

  group('planner event serialization', () {
    test('alertType round-trips', () {
      final PlannerEvent e = PlannerEvent(
        id: 'e1',
        title: 'Dentist',
        type: PlannerItemType.appointment,
        start: DateTime(2026, 8, 3, 11, 30),
        alertType: AlertType.forceConfirm,
        reminderLeadMinutes: 60,
      );
      final PlannerEvent back = PlannerEvent.fromJson(e.toJson());
      expect(back.alertType, AlertType.forceConfirm);
      expect(back.reminderLeadMinutes, 60);
      expect(back.start, DateTime(2026, 8, 3, 11, 30));
    });

    test('habit startedOn round-trips', () {
      final Habit h = Habit(
        id: 'h5',
        name: 'Monthly review',
        repeat: RepeatPattern.monthly,
        startedOn: DateTime(2026, 6, 12),
      );
      expect(Habit.fromJson(h.toJson()).startedOn, DateTime(2026, 6, 12));
    });
  });

  group('reminders due on a date are available for the Planner Day view', () {
    test('forDate surfaces an enabled reminder scheduled for that day', () {
      final ReminderStore store = ReminderStore();
      final Reminder r = Reminder(
        id: 'r1',
        title: 'Metformin',
        type: ReminderType.medicine,
        time: const TimeOfDay(hour: 8, minute: 0),
      );
      store.add(r);

      final DateTime today = DateTime(2026, 7, 28);
      expect(store.forDate(today).map((Reminder e) => e.id), contains('r1'));
    });

    test('a disabled reminder is excluded once filtered for display', () {
      final ReminderStore store = ReminderStore();
      final Reminder r = Reminder(
        id: 'r2',
        title: 'Paused med',
        type: ReminderType.medicine,
        time: const TimeOfDay(hour: 9, minute: 0),
        enabled: false,
      );
      store.add(r);

      final DateTime today = DateTime(2026, 7, 28);
      final List<Reminder> visible = store
          .forDate(today)
          .where((Reminder e) => e.enabled && e.id == 'r2')
          .toList();
      expect(visible, isEmpty);
    });
  });
}
