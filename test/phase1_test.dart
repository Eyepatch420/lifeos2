import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/data/models/enums.dart';
import 'package:lifeos/data/models/reminder.dart';

void main() {
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
}
