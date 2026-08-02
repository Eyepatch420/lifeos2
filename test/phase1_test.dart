import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digilife/data/models/enums.dart';
import 'package:digilife/data/models/reminder.dart';
import 'package:digilife/data/stores/persistence.dart';
import 'package:digilife/data/stores/reminder_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Persistence.reset();
  });

  group('snooze is transient, not destructive', () {
    test('snoozing never rewrites the scheduled time', () {
      final Reminder r = Reminder(
        id: 'r1',
        title: 'Metformin',
        type: ReminderType.medicine,
        time: const TimeOfDay(hour: 8, minute: 0),
      );

      r.snoozedUntil = DateTime.now().add(const Duration(minutes: 10));

      // The real schedule must be untouched — the old code moved this to 8:10
      // permanently, so the reminder drifted later every single day.
      expect(r.time.hour, 8);
      expect(r.time.minute, 0);
    });
  });

  group('fixed-duration courses expire', () {
    Reminder course(String duration, int startedDaysAgo) => Reminder(
          id: 'r2',
          title: 'Antibiotic',
          type: ReminderType.medicine,
          time: const TimeOfDay(hour: 9, minute: 0),
          duration: duration,
          startedOn: DateTime.now().subtract(Duration(days: startedDaysAgo)),
        );

    test('an ongoing course never expires', () {
      expect(course('Ongoing', 400).hasExpired(DateTime.now()), isFalse);
    });

    test('a 7-day course is still active on day 6', () {
      expect(course('7 days', 6).hasExpired(DateTime.now()), isFalse);
    });

    test('a 7-day course has expired on day 7', () {
      expect(course('7 days', 7).hasExpired(DateTime.now()), isTrue);
    });

    test('a 1-month course expires after 30 days', () {
      expect(course('1 month', 29).hasExpired(DateTime.now()), isFalse);
      expect(course('1 month', 30).hasExpired(DateTime.now()), isTrue);
    });

    test('a reminder with no start date never expires', () {
      final Reminder r = Reminder(
        id: 'r3',
        title: 'Legacy',
        type: ReminderType.medicine,
        time: const TimeOfDay(hour: 9, minute: 0),
        duration: '7 days',
      );
      expect(r.hasExpired(DateTime.now()), isFalse);
    });
  });

  group('serialization round-trips the new fields', () {
    test('notifStyle, startedOn and snoozedUntil survive a save/load', () {
      final DateTime started = DateTime(2026, 7, 1);
      final DateTime snoozed = DateTime(2026, 7, 27, 8, 10);
      final Reminder original = Reminder(
        id: 'r4',
        title: 'Vitamin D3',
        type: ReminderType.medicine,
        time: const TimeOfDay(hour: 8, minute: 30),
        duration: '14 days',
        notifStyle: 'Vibrate',
        startedOn: started,
        prescriptionPath: '/data/attachments/rx.jpg',
      )..snoozedUntil = snoozed;

      final Reminder restored = Reminder.fromJson(original.toJson());

      expect(restored.notifStyle, 'Vibrate');
      expect(restored.startedOn, started);
      expect(restored.snoozedUntil, snoozed);
      expect(restored.prescriptionPath, '/data/attachments/rx.jpg');
      expect(restored.time.hour, 8);
      expect(restored.time.minute, 30);
    });
  });

  group('duplicate() does not silently drop fields', () {
    test('prescription, notification style and course start survive a copy',
        () {
      final ReminderStore store = ReminderStore();
      final Reminder original = Reminder(
        id: 'orig',
        title: 'Amoxicillin',
        type: ReminderType.medicine,
        time: const TimeOfDay(hour: 9, minute: 0),
        notifStyle: 'Vibrate',
        startedOn: DateTime(2026, 7, 1),
        prescriptionPath: '/data/attachments/rx.jpg',
      );
      store.add(original);

      final Reminder copy = store.duplicate(original);

      expect(copy.id, isNot(original.id));
      expect(copy.notifStyle, 'Vibrate');
      expect(copy.startedOn, DateTime(2026, 7, 1));
      expect(copy.prescriptionPath, '/data/attachments/rx.jpg');
    });
  });

  group('copyWith() can actually override every field it declares', () {
    test('prescriptionPath, notifStyle and startedOn are overridable', () {
      final Reminder original = Reminder(
        id: 'r5',
        title: 'Vitamin D3',
        type: ReminderType.medicine,
        time: const TimeOfDay(hour: 8, minute: 0),
        notifStyle: 'Sound',
        prescriptionPath: '/old.jpg',
      );

      final Reminder updated = original.copyWith(
        notifStyle: 'Silent',
        prescriptionPath: '/new.jpg',
        startedOn: DateTime(2026, 7, 20),
      );

      expect(updated.notifStyle, 'Silent');
      expect(updated.prescriptionPath, '/new.jpg');
      expect(updated.startedOn, DateTime(2026, 7, 20));
      // Omitted params keep the original's value, not a fresh default.
      expect(updated.title, 'Vitamin D3');
    });
  });

  group('weekly repeat honours the chosen day, not always Monday', () {
    test('a Thursday-only weekly reminder does not apply on Monday', () {
      final Reminder r = Reminder(
        id: 'r6',
        title: 'Bin day',
        type: ReminderType.custom,
        time: const TimeOfDay(hour: 7, minute: 0),
        repeat: RepeatPattern.weekly,
        specificDays: <int>{DateTime.thursday},
      );
      final DateTime monday = DateTime(2026, 7, 27); // a Monday
      final DateTime thursday = DateTime(2026, 7, 30); // that week's Thursday
      expect(r.appliesOn(monday), isFalse);
      expect(r.appliesOn(thursday), isTrue);
    });

    test('weekly with no explicit day falls back to Monday for old data', () {
      final Reminder r = Reminder(
        id: 'r7',
        title: 'Legacy weekly',
        type: ReminderType.custom,
        time: const TimeOfDay(hour: 7, minute: 0),
        repeat: RepeatPattern.weekly,
      );
      expect(r.appliesOn(DateTime(2026, 7, 27)), isTrue); // Monday
      expect(r.appliesOn(DateTime(2026, 7, 30)), isFalse); // Thursday
    });
  });

  group('dependency gating actually blocks completion', () {
    late ReminderStore store;
    late Reminder water;
    late Reminder medicine;
    final DateTime today = DateTime(2026, 7, 28);

    setUp(() {
      store = ReminderStore();
      water = Reminder(
        id: 'dep_water',
        title: 'Water reminder',
        type: ReminderType.water,
        time: const TimeOfDay(hour: 7, minute: 0),
      );
      medicine = Reminder(
        id: 'dep_med',
        title: 'Metformin',
        type: ReminderType.medicine,
        time: const TimeOfDay(hour: 8, minute: 0),
        dependencyId: 'dep_water',
      );
      store.add(water);
      store.add(medicine);
    });

    test('markDone is refused while the dependency is unmet', () {
      expect(store.isBlockedByDependency(medicine, today), isTrue);
      expect(store.markDone(medicine, today), isFalse);
      expect(store.isDone(medicine, today), isFalse);
    });

    test('blockingDependency reports exactly which reminder is blocking', () {
      expect(store.blockingDependency(medicine, today)?.id, 'dep_water');
    });

    test('completing the dependency immediately unblocks, no extra step',
        () {
      store.markDone(water, today);
      expect(store.isBlockedByDependency(medicine, today), isFalse);
      expect(store.markDone(medicine, today), isTrue);
      expect(store.isDone(medicine, today), isTrue);
    });

    test('toggleDone is blocked the same way as markDone', () {
      expect(store.toggleDone(medicine, today), isFalse);
      expect(store.isDone(medicine, today), isFalse);
    });

    test('un-completing a done reminder is never blocked', () {
      store.markDone(water, today);
      store.markDone(medicine, today);
      expect(store.isDone(medicine, today), isTrue);
      expect(store.toggleDone(medicine, today), isTrue);
      expect(store.isDone(medicine, today), isFalse);
    });

    test('a reminder with no dependency is never blocked', () {
      expect(store.isBlockedByDependency(water, today), isFalse);
      expect(store.markDone(water, today), isTrue);
    });
  });
}
