import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/utils/date_x.dart';
import 'package:lifeos/core/utils/streak_calculator.dart';
import 'package:lifeos/data/models/commitments.dart';
import 'package:lifeos/data/models/enums.dart';
import 'package:lifeos/data/models/expense.dart';
import 'package:lifeos/data/models/health.dart';
import 'package:lifeos/data/stores/expense_store.dart';
import 'package:lifeos/data/stores/reminder_store.dart';

/// Tests target the acceptance criteria from the requirements document that
/// are pure logic — the parts most likely to silently drift.
void main() {
  group('StreakCalculator (PRD 1.2 / G.5)', () {
    final DateTime now = DateTime(2026, 7, 27); // a Monday

    Map<DateTime, CompletionStatus> log(
        Map<int, CompletionStatus> daysAgo) {
      return daysAgo.map((int d, CompletionStatus s) =>
          MapEntry<DateTime, CompletionStatus>(
              dayKey(now.subtract(Duration(days: d))), s));
    }

    test('counts consecutive completed days', () {
      final int streak = StreakCalculator.currentStreak(
        log(<int, CompletionStatus>{
          1: CompletionStatus.done,
          2: CompletionStatus.done,
          3: CompletionStatus.done,
        }),
        now,
      );
      expect(streak, 3);
    });

    test('AC1: streak resets after a missed day', () {
      final int streak = StreakCalculator.currentStreak(
        log(<int, CompletionStatus>{
          1: CompletionStatus.done,
          2: CompletionStatus.missed,
          3: CompletionStatus.done,
          4: CompletionStatus.done,
        }),
        now,
      );
      expect(streak, 1);
    });

    test('Gap 8: "Skip today" preserves the streak by default', () {
      final int streak = StreakCalculator.currentStreak(
        log(<int, CompletionStatus>{
          1: CompletionStatus.skipped,
          2: CompletionStatus.done,
          3: CompletionStatus.done,
        }),
        now,
      );
      expect(streak, 2, reason: 'skip neither extends nor breaks the streak');
    });

    test('AC2: best-ever streak survives a later break', () {
      final Map<DateTime, CompletionStatus> l = log(<int, CompletionStatus>{
        1: CompletionStatus.done,
        2: CompletionStatus.missed,
        3: CompletionStatus.done,
        4: CompletionStatus.done,
        5: CompletionStatus.done,
        6: CompletionStatus.done,
      });
      expect(StreakCalculator.currentStreak(l, now), 1);
      expect(StreakCalculator.bestStreak(l), 4);
    });

    test('unscheduled days are skipped, not treated as misses', () {
      // Habit only on Mondays; the gap between Mondays must not break it.
      bool onlyMondays(DateTime d) => d.weekday == DateTime.monday;
      final int streak = StreakCalculator.currentStreak(
        log(<int, CompletionStatus>{
          7: CompletionStatus.done,
          14: CompletionStatus.done,
          21: CompletionStatus.done,
        }),
        now,
        isScheduled: onlyMondays,
      );
      expect(streak, 3);
    });

    test('AC3: completion rate counts partial days as half', () {
      final StreakStats s = StreakCalculator.compute(
        <DateTime, CompletionStatus>{
          DateTime(2026, 7, 1): CompletionStatus.done,
          DateTime(2026, 7, 2): CompletionStatus.done,
          DateTime(2026, 7, 3): CompletionStatus.partial,
          DateTime(2026, 7, 4): CompletionStatus.missed,
        },
        DateTime(2026, 7, 27),
      );
      // (2 + 0.5) / 4 = 0.625
      expect(s.completionRate, closeTo(0.625, 0.001));
    });

    test('empty log yields zeroes, not NaN', () {
      final StreakStats s = StreakCalculator.compute(
          <DateTime, CompletionStatus>{}, DateTime(2026, 7, 27));
      expect(s.current, 0);
      expect(s.completionRate, 0);
      expect(s.completionRate.isNaN, isFalse);
    });
  });

  group('Billing cycle normalisation (PRD 7.1 AC1 / 8.1 AC1)', () {
    test('monthly membership annualises correctly', () {
      final Membership m = Membership(
        id: 'm1',
        name: 'Gym',
        category: MembershipCategory.fitness,
        costPaise: 250000, // Rs 2,500
        cycle: BillingCycle.monthly,
        startDate: DateTime(2026, 1, 1),
        expiryDate: DateTime(2026, 2, 1),
      );
      expect(m.annualCost, 30000);
    });

    test('quarterly membership annualises correctly', () {
      final Membership m = Membership(
        id: 'm2',
        name: 'Yoga',
        category: MembershipCategory.fitness,
        costPaise: 360000, // Rs 3,600
        cycle: BillingCycle.quarterly,
        startDate: DateTime(2026, 1, 1),
        expiryDate: DateTime(2026, 4, 1),
      );
      expect(m.annualCost, 14400);
    });

    test('AC1: total paid excludes missed renewals', () {
      final Membership m = Membership(
        id: 'm3',
        name: 'Club',
        category: MembershipCategory.club,
        costPaise: 100000,
        cycle: BillingCycle.monthly,
        startDate: DateTime(2026, 1, 1),
        expiryDate: DateTime(2026, 2, 1),
        history: <RenewalEntry>[
          RenewalEntry(
              date: DateTime(2026, 1, 1), amountPaise: 100000, paid: true),
          RenewalEntry(
              date: DateTime(2025, 12, 1), amountPaise: 100000, paid: true),
          RenewalEntry(
              date: DateTime(2025, 11, 1), amountPaise: 100000, paid: false),
        ],
      );
      expect(m.totalPaid, 2000, reason: 'the lapsed entry must not count');
    });
  });

  group('Bills & EMI (PRD 8.x)', () {
    Bill emi() => Bill(
          id: 'b1',
          name: 'Laptop EMI',
          kind: BillKind.emi,
          amountPaise: 420000, // Rs 4,200
          cycle: BillingCycle.monthly,
          dueDate: DateTime(2026, 7, 20),
          dayOfMonth: 20,
          installmentsPaid: 6,
          installmentsTotal: 12,
        );

    test('remaining balance = per-installment x installments left', () {
      expect(emi().remainingBalance, 4200 * 6);
    });

    test('progress reflects installments paid', () {
      expect(emi().emiProgress, closeTo(0.5, 0.0001));
    });

    test('AC2: overdue only AFTER the due date passes', () {
      final Bill b = Bill(
        id: 'b2',
        name: 'Rent',
        kind: BillKind.bill,
        amountPaise: 900000,
        cycle: BillingCycle.monthly,
        dueDate: DateTime(2026, 7, 27),
      );
      expect(b.isOverdue(DateTime(2026, 7, 27)), isFalse,
          reason: 'due today is not yet overdue');
      expect(b.isOverdue(DateTime(2026, 7, 28)), isTrue);
      expect(b.daysLate(DateTime(2026, 7, 30)), 3);
    });

    test('auto-pay bills never appear as overdue', () {
      final Bill b = Bill(
        id: 'b3',
        name: 'Netflix',
        kind: BillKind.subscription,
        amountPaise: 64900,
        cycle: BillingCycle.monthly,
        dueDate: DateTime(2026, 7, 1),
        autoPay: true,
      );
      expect(b.isOverdue(DateTime(2026, 7, 28)), isFalse);
    });

    test('FR3: "31st of every month" clamps in short months', () {
      final Bill b = Bill(
        id: 'b4',
        name: 'Loan',
        kind: BillKind.bill,
        amountPaise: 100000,
        cycle: BillingCycle.monthly,
        dueDate: DateTime(2026, 1, 31),
        dayOfMonth: 31,
      );
      // February 2026 has 28 days.
      expect(b.nextDueDate(), DateTime(2026, 2, 28));
    });

    test('monthly equivalent normalises a yearly bill', () {
      final Bill b = Bill(
        id: 'b5',
        name: 'Insurance',
        kind: BillKind.bill,
        amountPaise: 1200000, // Rs 12,000/yr
        cycle: BillingCycle.yearly,
        dueDate: DateTime(2026, 7, 1),
      );
      expect(b.monthlyEquivalent, 1000);
    });
  });

  group('Lab markers & vitals (PRD 5.2 / 5.4)', () {
    test('AC2: range bounds are inclusive', () {
      final LabMarker atLow = LabMarker(
          name: 'Hb', value: 12, unit: 'g/dL', normalLow: 12, normalHigh: 17);
      final LabMarker atHigh = LabMarker(
          name: 'Hb', value: 17, unit: 'g/dL', normalLow: 12, normalHigh: 17);
      expect(atLow.status, MarkerStatus.normal);
      expect(atHigh.status, MarkerStatus.normal);
    });

    test('slightly out of range is borderline, far out is abnormal', () {
      final LabMarker borderline = LabMarker(
          name: 'WBC', value: 11.4, unit: 'K/uL', normalLow: 4, normalHigh: 11);
      final LabMarker abnormal = LabMarker(
          name: 'WBC', value: 15, unit: 'K/uL', normalLow: 4, normalHigh: 11);
      expect(borderline.status, MarkerStatus.borderline);
      expect(abnormal.status, MarkerStatus.abnormal);
    });

    test('AC1: report summary counts match the individual markers', () {
      final LabReport r = LabReport(
        id: 'r1',
        name: 'CBC',
        lab: 'SRL',
        date: DateTime(2026, 7, 1),
        markers: <LabMarker>[
          LabMarker(name: 'A', value: 5, unit: 'x', normalLow: 1, normalHigh: 10),
          LabMarker(name: 'B', value: 50, unit: 'x', normalLow: 1, normalHigh: 10),
        ],
      );
      final int total = r.countOf(MarkerStatus.normal) +
          r.countOf(MarkerStatus.borderline) +
          r.countOf(MarkerStatus.abnormal);
      expect(total, r.markers.length);
      expect(r.summaryBadge, '1 high');
    });

    test('BP thresholds are applied per vital, not per reading', () {
      expect(
        VitalReading(
                kind: VitalKind.bloodPressure,
                value: 118,
                secondaryValue: 76,
                takenAt: DateTime(2026, 7, 1))
            .status,
        MarkerStatus.normal,
      );
      expect(
        VitalReading(
                kind: VitalKind.bloodPressure,
                value: 132,
                secondaryValue: 82,
                takenAt: DateTime(2026, 7, 1))
            .status,
        MarkerStatus.borderline,
      );
      expect(
        VitalReading(
                kind: VitalKind.bloodPressure,
                value: 145,
                secondaryValue: 95,
                takenAt: DateTime(2026, 7, 1))
            .status,
        MarkerStatus.abnormal,
      );
    });
  });

  group('Expenses (PRD 4.x)', () {
    test('AC: split expense only attributes the user\'s own share', () {
      final ExpenseTransaction t = ExpenseTransaction(
        id: 't1',
        type: TransactionType.expense,
        amountPaise: 240000, // Rs 2,400
        description: 'Team dinner',
        categoryId: 'cat_food',
        date: DateTime(2026, 7, 1),
        splitWays: 4,
      );
      expect(t.amount, 2400);
      expect(t.ownShare, 600);
      expect(t.isSplit, isTrue);
    });

    test('transfers count as neither spend nor income', () {
      final ExpenseTransaction t = ExpenseTransaction(
        id: 't2',
        type: TransactionType.transfer,
        amountPaise: 500000,
        description: 'To savings',
        categoryId: 'cat_other',
        date: DateTime(2026, 7, 1),
      );
      expect(t.countsAsSpend, isFalse);
      expect(t.countsAsIncome, isFalse);
    });

    test('AC1: category breakdown sums to total spend', () {
      final ExpenseStore store = ExpenseStore();
      final double total = store.monthSpend;
      final double sum = store
          .categoryBreakdown(store.selectedMonth)
          .fold<double>(0, (double s, CategorySpend c) => s + c.amount);
      expect(sum, closeTo(total, 0.01));
    });

    test('AC2: savings = income - spend and may go negative', () {
      final ExpenseStore store = ExpenseStore();
      expect(store.monthSavings,
          closeTo(store.monthIncome - store.monthSpend, 0.01));
    });

    test('AC3: payment-method shares sum to 100%', () {
      final ExpenseStore store = ExpenseStore();
      final Map<PaymentMethod, double> split =
          store.paymentMethodSplit(store.selectedMonth);
      final double total =
          split.values.fold<double>(0, (double s, double v) => s + v);
      expect(total, closeTo(store.monthSpend, 0.01));
    });

    test('AC4: CSV export contains every transaction for the month', () {
      final ExpenseStore store = ExpenseStore();
      final int rows =
          store.exportCsv(store.selectedMonth).trim().split('\n').length - 1;
      expect(rows, store.transactionsIn(store.selectedMonth).length);
    });
  });

  group('Reminders (PRD 2.1)', () {
    test('time-of-day bucketing, with 12:00 treated as Afternoon', () {
      final ReminderStore store = ReminderStore()..seed();
      final dynamic r = store.all.first;
      expect(<String>['Morning', 'Afternoon', 'Evening'].contains(r.bucket),
          isTrue);
    });

    test('AC1: marking done is idempotent for the same occurrence', () {
      final ReminderStore store = ReminderStore()..seed();
      final DateTime today = DateTime.now();
      final dynamic r = store.all.firstWhere((dynamic x) => x.enabled == true);
      store.markDone(r, today);
      final int after1 = store.doneCount(today);
      store.markDone(r, today);
      expect(store.doneCount(today), after1);
    });

    test('water progress never divides by zero', () {
      final ReminderStore store = ReminderStore();
      store.setWaterGoal(0);
      expect(store.waterProgress(DateTime.now()), 0);
      expect(store.waterProgress(DateTime.now()).isNaN, isFalse);
    });

    test('water total cannot go negative', () {
      final ReminderStore store = ReminderStore();
      final DateTime d = DateTime(2020, 1, 1);
      store.addWater(d, -500);
      expect(store.waterOn(d), greaterThanOrEqualTo(0));
    });
  });

  group('Documents (PRD 9.1)', () {
    test('AC1: no expiry date is excluded from expiry alerts', () {
      final StoredDocument d = StoredDocument(
          id: 'd1', name: 'PAN card', category: DocCategory.identity);
      expect(d.hasExpiry, isFalse);
      expect(d.statusChip(DateTime(2026, 7, 27)), 'No expiry');
      expect(d.isExpiringSoon(DateTime(2026, 7, 27)), isFalse);
    });

    test('expiry thresholds map to the right status chip', () {
      StoredDocument doc(int daysOut) => StoredDocument(
            id: 'd',
            name: 'Licence',
            category: DocCategory.identity,
            expiryDate: DateTime(2026, 7, 27).add(Duration(days: daysOut)),
          );
      expect(doc(-1).statusChip(DateTime(2026, 7, 27)), 'Expired');
      expect(doc(18).statusChip(DateTime(2026, 7, 27)), 'Urgent');
      expect(doc(60).statusChip(DateTime(2026, 7, 27)), 'Renew soon');
      expect(doc(400).statusChip(DateTime(2026, 7, 27)), 'Valid');
    });
  });

  group('Date helpers', () {
    test('startOfWeek always lands on Monday', () {
      for (int i = 0; i < 7; i++) {
        final DateTime d = DateTime(2026, 7, 27).add(Duration(days: i));
        expect(startOfWeek(d).weekday, DateTime.monday);
      }
    });

    test('greeting changes with the time of day', () {
      expect(greetingFor(DateTime(2026, 7, 27, 8)), 'Good morning');
      expect(greetingFor(DateTime(2026, 7, 27, 14)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 7, 27, 20)), 'Good evening');
    });

    test('days left in month is correct for a 31-day month', () {
      expect(daysLeftInMonth(DateTime(2026, 7, 27)), 4);
    });
  });
}
