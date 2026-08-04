import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:digidaily/data/models/alarm.dart';
import 'package:digidaily/data/stores/alarm_store.dart';

void main() {
  // Monday 27 July 2026, 08:00.
  final DateTime mondayMorning = DateTime(2026, 7, 27, 8, 0);

  group('Alarm.nextOccurrence — one-off alarms', () {
    test('rings later today when the time is still ahead', () {
      final Alarm a = Alarm(id: 'a', time: const TimeOfDay(hour: 20, minute: 30));
      expect(a.nextOccurrence(mondayMorning), DateTime(2026, 7, 27, 20, 30));
    });

    test('rolls to tomorrow when the time has passed', () {
      final Alarm a = Alarm(id: 'a', time: const TimeOfDay(hour: 6, minute: 0));
      expect(a.nextOccurrence(mondayMorning), DateTime(2026, 7, 28, 6, 0));
    });

    test('a time exactly equal to now rolls to tomorrow', () {
      final Alarm a = Alarm(id: 'a', time: const TimeOfDay(hour: 8, minute: 0));
      expect(a.nextOccurrence(mondayMorning), DateTime(2026, 7, 28, 8, 0),
          reason: 'an alarm for the current minute should not fire instantly');
    });
  });

  group('Alarm.nextOccurrence — repeating alarms', () {
    test('weekday alarm later today fires today', () {
      final Alarm a = Alarm(
        id: 'a',
        time: const TimeOfDay(hour: 18, minute: 0),
        repeatDays: <int>{1, 2, 3, 4, 5},
      );
      expect(a.nextOccurrence(mondayMorning), DateTime(2026, 7, 27, 18, 0));
    });

    test('weekday alarm already passed fires tomorrow', () {
      final Alarm a = Alarm(
        id: 'a',
        time: const TimeOfDay(hour: 6, minute: 0),
        repeatDays: <int>{1, 2, 3, 4, 5},
      );
      expect(a.nextOccurrence(mondayMorning), DateTime(2026, 7, 28, 6, 0));
    });

    test('weekend alarm from a Monday jumps to Saturday', () {
      final Alarm a = Alarm(
        id: 'a',
        time: const TimeOfDay(hour: 9, minute: 0),
        repeatDays: <int>{6, 7},
      );
      // Mon 27 Jul 2026 -> Sat 1 Aug 2026
      expect(a.nextOccurrence(mondayMorning), DateTime(2026, 8, 1, 9, 0));
    });

    test('single-day alarm on today, already passed, waits a full week', () {
      final Alarm a = Alarm(
        id: 'a',
        time: const TimeOfDay(hour: 7, minute: 0),
        repeatDays: <int>{1}, // Mondays only
      );
      expect(a.nextOccurrence(mondayMorning), DateTime(2026, 8, 3, 7, 0));
    });

    test('crossing a month boundary works', () {
      final Alarm a = Alarm(
        id: 'a',
        time: const TimeOfDay(hour: 6, minute: 0),
        repeatDays: <int>{5}, // Friday
      );
      // From Wed 29 Jul 2026 the next Friday is 31 Jul.
      expect(a.nextOccurrence(DateTime(2026, 7, 29, 8, 0)),
          DateTime(2026, 7, 31, 6, 0));
      // From Sat 1 Aug 2026 the next Friday is 7 Aug.
      expect(a.nextOccurrence(DateTime(2026, 8, 1, 8, 0)),
          DateTime(2026, 8, 7, 6, 0));
    });
  });

  group('Alarm.repeatLabel', () {
    Alarm withDays(Set<int> d) =>
        Alarm(id: 'a', time: const TimeOfDay(hour: 7, minute: 0), repeatDays: d);

    test('no days = Once', () => expect(withDays(<int>{}).repeatLabel, 'Once'));
    test('all seven = Every day',
        () => expect(withDays(<int>{1, 2, 3, 4, 5, 6, 7}).repeatLabel, 'Every day'));
    test('Mon-Fri = Weekdays',
        () => expect(withDays(<int>{1, 2, 3, 4, 5}).repeatLabel, 'Weekdays'));
    test('Sat+Sun = Weekends',
        () => expect(withDays(<int>{6, 7}).repeatLabel, 'Weekends'));
    test('arbitrary days list in order',
        () => expect(withDays(<int>{5, 1, 3}).repeatLabel, 'Mon, Wed, Fri'));
  });

  group('AlarmStore', () {
    test('seeds with alarms and reports the enabled count', () {
      final AlarmStore s = AlarmStore()..seed();
      expect(s.all, isNotEmpty);
      expect(s.enabled.length, lessThanOrEqualTo(s.all.length));
    });

    test('alarms are listed in time order', () {
      final AlarmStore s = AlarmStore()..seed();
      final List<int> mins = s.all.map((Alarm a) => a.minutesOfDay).toList();
      final List<int> sorted = List<int>.from(mins)..sort();
      expect(mins, sorted);
    });

    test('nextAlarm returns the soonest ENABLED alarm', () {
      final AlarmStore s = AlarmStore()..seed();
      final Alarm? next = s.nextAlarm(mondayMorning);
      expect(next, isNotNull);
      expect(next!.enabled, isTrue);
      for (final Alarm a in s.enabled) {
        expect(
          next.nextOccurrence(mondayMorning).isAfter(a.nextOccurrence(mondayMorning)),
          isFalse,
          reason: 'no enabled alarm should ring before the reported next one',
        );
      }
    });

    test('disabling every alarm makes nextAlarm null', () {
      final AlarmStore s = AlarmStore();
      for (final Alarm a in s.all) {
        s.setEnabled(a, false);
      }
      expect(s.nextAlarm(mondayMorning), isNull);
    });

    test('add, update and delete work', () {
      final AlarmStore s = AlarmStore();
      final int before = s.all.length;
      final Alarm a = Alarm(
          id: 'test-1', time: const TimeOfDay(hour: 5, minute: 15), label: 'X');
      s.add(a);
      expect(s.all.length, before + 1);
      expect(s.byId('test-1')!.label, 'X');

      s.update(a.copyWith(label: 'Y'));
      expect(s.byId('test-1')!.label, 'Y');

      s.delete('test-1');
      expect(s.byId('test-1'), isNull);
      expect(s.all.length, before);
    });

    test('snooze delays the next ring without moving the alarm itself', () {
      final AlarmStore s = AlarmStore();
      final Alarm a = Alarm(
        id: 'sn',
        time: const TimeOfDay(hour: 23, minute: 55),
        snoozeMinutes: 10,
      );
      s.add(a);
      final DateTime before = DateTime.now();
      s.snooze(a);

      // The alarm's real schedule must survive — rewriting `time` here made
      // every snooze drift the alarm permanently later, day after day.
      expect(a.time.hour, 23);
      expect(a.time.minute, 55);

      // The next ring is pushed out by the snooze duration.
      expect(a.snoozedUntil, isNotNull);
      expect(
        a.snoozedUntil!.difference(before).inMinutes,
        closeTo(10, 1),
      );
      expect(a.nextOccurrence(before), a.snoozedUntil);
    });

    test('clearing a snooze restores the normal schedule', () {
      final AlarmStore s = AlarmStore();
      final Alarm a = Alarm(
        id: 'sn2',
        time: const TimeOfDay(hour: 7, minute: 0),
        snoozeMinutes: 10,
      );
      s.add(a);
      s.snooze(a);
      s.clearSnooze(a);
      expect(a.snoozedUntil, isNull);
      expect(a.nextOccurrence(DateTime.now()).hour, 7);
    });

    test('toggle flips the enabled flag', () {
      final AlarmStore s = AlarmStore()..seed();
      final Alarm a = s.all.first;
      final bool was = a.enabled;
      s.toggle(a);
      expect(a.enabled, !was);
    });
  });

  group('formatStopwatch', () {
    test('zero', () => expect(formatStopwatch(Duration.zero), '00:00.00'));
    test('centiseconds', () =>
        expect(formatStopwatch(const Duration(milliseconds: 90)), '00:00.09'));
    test('rounds down to centiseconds', () =>
        expect(formatStopwatch(const Duration(milliseconds: 1999)), '00:01.99'));
    test('minutes and seconds', () => expect(
        formatStopwatch(const Duration(minutes: 3, seconds: 7, milliseconds: 250)),
        '03:07.25'));
    test('adds an hours segment past 60 min', () => expect(
        formatStopwatch(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03.00'));
    test('minutes wrap correctly inside an hour', () => expect(
        formatStopwatch(const Duration(hours: 2, minutes: 5)), '2:05:00.00'));
  });

  group('Lap maths', () {
    test('splits sum to the final total', () {
      const List<Lap> laps = <Lap>[
        Lap(index: 1, split: Duration(seconds: 30), total: Duration(seconds: 30)),
        Lap(index: 2, split: Duration(seconds: 25), total: Duration(seconds: 55)),
        Lap(index: 3, split: Duration(seconds: 35), total: Duration(seconds: 90)),
      ];
      final Duration sum = laps.fold<Duration>(
          Duration.zero, (Duration a, Lap l) => a + l.split);
      expect(sum, laps.last.total);
    });

    test('best and worst laps identified correctly', () {
      const List<Duration> splits = <Duration>[
        Duration(seconds: 30),
        Duration(seconds: 25),
        Duration(seconds: 35),
      ];
      expect(splits.reduce((Duration a, Duration b) => a < b ? a : b),
          const Duration(seconds: 25));
      expect(splits.reduce((Duration a, Duration b) => a > b ? a : b),
          const Duration(seconds: 35));
    });
  });
}
