/// Shared enums used across modules.
library;

/// PRD 2.3 / G.2 — the three-tier alert system, reused by Reminders,
/// Memberships, Bills and Document expiries.
enum AlertType { notification, alarm, forceConfirm }

extension AlertTypeX on AlertType {
  String get label => switch (this) {
        AlertType.notification => 'Notification',
        AlertType.alarm => 'Alarm',
        AlertType.forceConfirm => 'Force confirm',
      };

  String get description => switch (this) {
        AlertType.notification =>
          'Silent banner on your screen. Dismisses on its own.',
        AlertType.alarm =>
          'Plays sound + vibration. Tap to dismiss. Repeats if snoozed.',
        AlertType.forceConfirm =>
          "Alarm won't stop until you confirm. Keeps repeating at your chosen interval.",
      };
}

enum ReminderType { medicine, water, custom }

extension ReminderTypeX on ReminderType {
  String get label => switch (this) {
        ReminderType.medicine => 'Medicine',
        ReminderType.water => 'Water',
        ReminderType.custom => 'Custom',
      };
}

/// PRD 1.2 / G.5 — one shared completion vocabulary so streak maths is
/// identical everywhere it is displayed.
enum CompletionStatus { done, partial, missed, skipped, rest }

enum RepeatPattern { daily, specificDays, weekly, monthly, everyXHours, sos }

extension RepeatPatternX on RepeatPattern {
  String get label => switch (this) {
        RepeatPattern.daily => 'Daily',
        RepeatPattern.specificDays => 'Specific days',
        RepeatPattern.weekly => 'Weekly',
        RepeatPattern.monthly => 'Monthly',
        RepeatPattern.everyXHours => 'Every X hrs',
        RepeatPattern.sos => 'SOS',
      };
}

enum TransactionType { expense, income, transfer, recurring }

extension TransactionTypeX on TransactionType {
  String get label => switch (this) {
        TransactionType.expense => 'Expense',
        TransactionType.income => 'Income',
        TransactionType.transfer => 'Transfer',
        TransactionType.recurring => 'Recurring',
      };
}

enum PaymentMethod { upi, card, cash, netBanking }

extension PaymentMethodX on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.upi => 'UPI',
        PaymentMethod.card => 'Card',
        PaymentMethod.cash => 'Cash',
        PaymentMethod.netBanking => 'Net banking',
      };
}

/// PRD 5.1/5.2/5.4 — marker & vitals classification against normal ranges.
enum MarkerStatus { normal, borderline, abnormal }

extension MarkerStatusX on MarkerStatus {
  String get label => switch (this) {
        MarkerStatus.normal => 'Normal',
        MarkerStatus.borderline => 'Borderline',
        MarkerStatus.abnormal => 'Abnormal',
      };
}

enum Mood { poor, low, okay, good, great }

extension MoodX on Mood {
  String get label => switch (this) {
        Mood.poor => 'Poor',
        Mood.low => 'Low',
        Mood.okay => 'Okay',
        Mood.good => 'Good',
        Mood.great => 'Great',
      };

  /// Numeric value used for the wellness composite score (PRD 1.3).
  int get score => index + 1;
}

enum ListType { todo, shopping, checklist, custom }

extension ListTypeX on ListType {
  String get label => switch (this) {
        ListType.todo => 'To-do',
        ListType.shopping => 'Shopping',
        ListType.checklist => 'Checklist',
        ListType.custom => 'Custom',
      };
}

enum NoteCategory { health, finance, personal, work, uncategorised }

extension NoteCategoryX on NoteCategory {
  String get label => switch (this) {
        NoteCategory.health => 'Health',
        NoteCategory.finance => 'Finance',
        NoteCategory.personal => 'Personal',
        NoteCategory.work => 'Work',
        NoteCategory.uncategorised => 'Uncategorised',
      };
}

enum MembershipCategory { fitness, health, club, other }

extension MembershipCategoryX on MembershipCategory {
  String get label => switch (this) {
        MembershipCategory.fitness => 'Fitness',
        MembershipCategory.health => 'Health',
        MembershipCategory.club => 'Club',
        MembershipCategory.other => 'Other',
      };
}

/// PRD 7.1 / 8.1 — normalising mixed billing cycles into one annual figure.
enum BillingCycle { monthly, quarterly, halfYearly, yearly, weekly, oneTime }

extension BillingCycleX on BillingCycle {
  String get label => switch (this) {
        BillingCycle.monthly => 'Monthly',
        BillingCycle.quarterly => 'Quarterly',
        BillingCycle.halfYearly => 'Half-yearly',
        BillingCycle.yearly => 'Yearly',
        BillingCycle.weekly => 'Weekly',
        BillingCycle.oneTime => 'One time',
      };

  /// How many times this cycle occurs in a year — the single source of truth
  /// for annual-cost and monthly-committed normalisation.
  double get occurrencesPerYear => switch (this) {
        BillingCycle.monthly => 12,
        BillingCycle.quarterly => 4,
        BillingCycle.halfYearly => 2,
        BillingCycle.yearly => 1,
        BillingCycle.weekly => 52,
        BillingCycle.oneTime => 0,
      };

  int get months => switch (this) {
        BillingCycle.monthly => 1,
        BillingCycle.quarterly => 3,
        BillingCycle.halfYearly => 6,
        BillingCycle.yearly => 12,
        BillingCycle.weekly => 0,
        BillingCycle.oneTime => 0,
      };
}

enum BillKind { bill, subscription, emi, creditCard }

extension BillKindX on BillKind {
  String get label => switch (this) {
        BillKind.bill => 'Bill',
        BillKind.subscription => 'Subscription',
        BillKind.emi => 'EMI',
        BillKind.creditCard => 'Credit card',
      };
}

enum DocCategory { identity, insurance, medical, property, vehicle, other }

extension DocCategoryX on DocCategory {
  String get label => switch (this) {
        DocCategory.identity => 'Identity',
        DocCategory.insurance => 'Insurance',
        DocCategory.medical => 'Medical',
        DocCategory.property => 'Property',
        DocCategory.vehicle => 'Vehicle',
        DocCategory.other => 'Other',
      };
}

enum PlannerItemType { habit, event, appointment, task }

extension PlannerItemTypeX on PlannerItemType {
  String get label => switch (this) {
        PlannerItemType.habit => 'Habit',
        PlannerItemType.event => 'Event',
        PlannerItemType.appointment => 'Appt',
        PlannerItemType.task => 'Task',
      };
}

enum VitalKind { bloodPressure, bloodSugar, weight, sleep }

extension VitalKindX on VitalKind {
  String get label => switch (this) {
        VitalKind.bloodPressure => 'Blood pressure',
        VitalKind.bloodSugar => 'Blood sugar',
        VitalKind.weight => 'Weight',
        VitalKind.sleep => 'Sleep',
      };

  String get unit => switch (this) {
        VitalKind.bloodPressure => 'mmHg',
        VitalKind.bloodSugar => 'mg/dL',
        VitalKind.weight => 'kg',
        VitalKind.sleep => 'hrs',
      };
}
