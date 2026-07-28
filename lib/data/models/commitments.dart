import 'enums.dart';

class RenewalEntry {
  RenewalEntry({
    required this.date,
    required this.amountPaise,
    required this.paid,
    this.method = 'UPI',
    this.note = '',
  });

  final DateTime date;
  final int amountPaise;
  final bool paid;
  final String method;
  final String note;

  double get amount => amountPaise / 100.0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date.toIso8601String(),
        'amountPaise': amountPaise,
        'paid': paid,
        'method': method,
        'note': note,
      };

  factory RenewalEntry.fromJson(Map<String, dynamic> j) => RenewalEntry(
        date: DateTime.parse(j['date'] as String),
        amountPaise: j['amountPaise'] as int,
        paid: j['paid'] as bool,
        method: j['method'] as String? ?? 'UPI',
        note: j['note'] as String? ?? '',
      );
}

/// Gym / health plan / club membership (PRD 7.1-7.3).
class Membership {
  Membership({
    required this.id,
    required this.name,
    required this.category,
    required this.costPaise,
    required this.cycle,
    required this.startDate,
    required this.expiryDate,
    this.location = '',
    this.reminderLeadDays = 7,
    this.alertType = AlertType.alarm,
    this.reminderEnabled = true,
    this.active = true,
    this.linkedExpenseId,
    this.note = '',
    this.forceConfirmIntervalMinutes = 2,
    this.remindLaterUntil,
    this.cardImagePath,
    List<RenewalEntry>? history,
  }) : history = history ?? <RenewalEntry>[];

  final String id;
  String name;
  MembershipCategory category;
  int costPaise;
  BillingCycle cycle;
  DateTime startDate;
  DateTime expiryDate;
  String location;
  int reminderLeadDays;
  AlertType alertType;
  bool reminderEnabled;
  bool active;
  String? linkedExpenseId;
  String note;
  int forceConfirmIntervalMinutes;

  /// "Remind later" from the Alerts screen suppresses the alert until then.
  DateTime? remindLaterUntil;

  /// Photo of the physical membership card, stored in app documents.
  String? cardImagePath;
  final List<RenewalEntry> history;

  double get cost => costPaise / 100.0;

  /// PRD 7.1 AC1 — mixed cycles normalise into one annual figure.
  double get annualCost => cost * cycle.occurrencesPerYear;

  /// PRD 7.2 AC1 — only paid entries count toward total paid.
  double get totalPaid => history
      .where((RenewalEntry e) => e.paid)
      .fold<double>(0, (double sum, RenewalEntry e) => sum + e.amount);

  int daysLeftFrom(DateTime now) =>
      expiryDate.difference(DateTime(now.year, now.month, now.day)).inDays;

  /// Elapsed fraction of the current validity period, for the progress bar.
  double progressFrom(DateTime now) {
    final int total = expiryDate.difference(startDate).inDays;
    if (total <= 0) return 1;
    final int elapsed = now.difference(startDate).inDays;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  /// PRD 7.1 AC2 — explicit day-range thresholds.
  String statusChip(DateTime now) {
    if (!active) return 'Cancelled';
    final int d = daysLeftFrom(now);
    if (d < 0) return 'Expired';
    if (d <= 7) return 'Urgent';
    if (d <= 21) return 'Soon';
    return 'Active';
  }

  bool isExpiringSoon(DateTime now) {
    final int d = daysLeftFrom(now);
    if (remindLaterUntil != null && now.isBefore(remindLaterUntil!)) {
      return false;
    }
    return active && d >= 0 && d <= 21;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'category': category.index,
        'costPaise': costPaise,
        'cycle': cycle.index,
        'startDate': startDate.toIso8601String(),
        'expiryDate': expiryDate.toIso8601String(),
        'location': location,
        'reminderLeadDays': reminderLeadDays,
        'alertType': alertType.index,
        'reminderEnabled': reminderEnabled,
        'active': active,
        'linkedExpenseId': linkedExpenseId,
        'note': note,
        'forceConfirmIntervalMinutes': forceConfirmIntervalMinutes,
        'remindLaterUntil': remindLaterUntil?.toIso8601String(),
        'cardImagePath': cardImagePath,
        'history': history.map((RenewalEntry e) => e.toJson()).toList(),
      };

  factory Membership.fromJson(Map<String, dynamic> j) => Membership(
        id: j['id'] as String,
        name: j['name'] as String,
        category: MembershipCategory.values[j['category'] as int],
        costPaise: j['costPaise'] as int,
        cycle: BillingCycle.values[j['cycle'] as int],
        startDate: DateTime.parse(j['startDate'] as String),
        expiryDate: DateTime.parse(j['expiryDate'] as String),
        location: j['location'] as String? ?? '',
        reminderLeadDays: j['reminderLeadDays'] as int? ?? 7,
        alertType: AlertType.values[j['alertType'] as int? ?? 1],
        reminderEnabled: j['reminderEnabled'] as bool? ?? true,
        active: j['active'] as bool? ?? true,
        linkedExpenseId: j['linkedExpenseId'] as String?,
        note: j['note'] as String? ?? '',
        forceConfirmIntervalMinutes:
            j['forceConfirmIntervalMinutes'] as int? ?? 2,
        remindLaterUntil: j['remindLaterUntil'] == null
            ? null
            : DateTime.parse(j['remindLaterUntil'] as String),
        cardImagePath: j['cardImagePath'] as String?,
        history: (j['history'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) => RenewalEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Bill / subscription / EMI / credit card (PRD 8.1-8.2).
class Bill {
  Bill({
    required this.id,
    required this.name,
    required this.kind,
    required this.amountPaise,
    required this.cycle,
    required this.dueDate,
    this.dayOfMonth,
    this.autoPay = false,
    this.reminderLeadDays = 3,
    this.alertType = AlertType.alarm,
    this.active = true,
    this.installmentsPaid = 0,
    this.installmentsTotal,
    this.linkedCategoryId,
    this.lastPaidOn,
    this.forceConfirmIntervalMinutes = 2,
    this.snoozedUntil,
  });

  final String id;
  String name;
  BillKind kind;
  int amountPaise;
  BillingCycle cycle;
  DateTime dueDate;

  /// "Nth of every month" pattern. PRD 8.2 FR3 — if a month is shorter than
  /// this day, the due date clamps to that month's last day.
  int? dayOfMonth;
  bool autoPay;
  int reminderLeadDays;
  AlertType alertType;
  bool active;

  /// EMI only (closes PRD Gap: EMI fields were underspecified).
  int installmentsPaid;
  int? installmentsTotal;
  String? linkedCategoryId;
  DateTime? lastPaidOn;
  int forceConfirmIntervalMinutes;

  /// "Snooze" from the Alerts screen suppresses the overdue alert until then.
  DateTime? snoozedUntil;

  double get amount => amountPaise / 100.0;

  /// Normalised monthly equivalent, used by "Monthly committed" (PRD 8.1 AC1).
  double get monthlyEquivalent => amount * cycle.occurrencesPerYear / 12.0;

  double get remainingBalance {
    if (kind != BillKind.emi || installmentsTotal == null) return 0;
    final int left = (installmentsTotal! - installmentsPaid).clamp(0, 1 << 30);
    return amount * left;
  }

  double get emiProgress {
    if (installmentsTotal == null || installmentsTotal == 0) return 0;
    return (installmentsPaid / installmentsTotal!).clamp(0.0, 1.0);
  }

  int daysUntilDue(DateTime now) =>
      dueDate.difference(DateTime(now.year, now.month, now.day)).inDays;

  /// PRD 8.1 AC2 — overdue starts the day AFTER the due date passes unpaid.
  bool isOverdue(DateTime now) {
    if (snoozedUntil != null && now.isBefore(snoozedUntil!)) return false;
    return active && !autoPay && daysUntilDue(now) < 0;
  }

  bool isDueThisWeek(DateTime now) {
    final int d = daysUntilDue(now);
    return active && d >= 0 && d <= 7;
  }

  int daysLate(DateTime now) {
    final int d = daysUntilDue(now);
    return d < 0 ? -d : 0;
  }

  /// Advance to the next due date, clamping for short months.
  DateTime nextDueDate() {
    final int months = cycle.months;
    if (months == 0) return dueDate.add(const Duration(days: 7));
    final int targetDay = dayOfMonth ?? dueDate.day;
    int y = dueDate.year;
    int m = dueDate.month + months;
    while (m > 12) {
      m -= 12;
      y += 1;
    }
    final int lastDay = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, targetDay > lastDay ? lastDay : targetDay);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'kind': kind.index,
        'amountPaise': amountPaise,
        'cycle': cycle.index,
        'dueDate': dueDate.toIso8601String(),
        'dayOfMonth': dayOfMonth,
        'autoPay': autoPay,
        'reminderLeadDays': reminderLeadDays,
        'alertType': alertType.index,
        'active': active,
        'installmentsPaid': installmentsPaid,
        'installmentsTotal': installmentsTotal,
        'linkedCategoryId': linkedCategoryId,
        'lastPaidOn': lastPaidOn?.toIso8601String(),
        'forceConfirmIntervalMinutes': forceConfirmIntervalMinutes,
        'snoozedUntil': snoozedUntil?.toIso8601String(),
      };

  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: BillKind.values[j['kind'] as int],
        amountPaise: j['amountPaise'] as int,
        cycle: BillingCycle.values[j['cycle'] as int],
        dueDate: DateTime.parse(j['dueDate'] as String),
        dayOfMonth: j['dayOfMonth'] as int?,
        autoPay: j['autoPay'] as bool? ?? false,
        reminderLeadDays: j['reminderLeadDays'] as int? ?? 3,
        alertType: AlertType.values[j['alertType'] as int? ?? 1],
        active: j['active'] as bool? ?? true,
        installmentsPaid: j['installmentsPaid'] as int? ?? 0,
        installmentsTotal: j['installmentsTotal'] as int?,
        linkedCategoryId: j['linkedCategoryId'] as String?,
        lastPaidOn: j['lastPaidOn'] == null
            ? null
            : DateTime.parse(j['lastPaidOn'] as String),
        forceConfirmIntervalMinutes:
            j['forceConfirmIntervalMinutes'] as int? ?? 2,
        snoozedUntil: j['snoozedUntil'] == null
            ? null
            : DateTime.parse(j['snoozedUntil'] as String),
      );
}

/// Stored document with expiry tracking + optional per-document lock
/// (PRD 9.1-9.2, closing Gaps 2 and 3).
class StoredDocument {
  StoredDocument({
    required this.id,
    required this.name,
    required this.category,
    this.issueDate,
    this.expiryDate,
    this.reminderLeadMonths = 3,
    this.alertType = AlertType.notification,
    this.filePath,
    this.fileExtension,
    this.locked = false,
    this.redactSensitiveNumbers = false,
    this.note = '',
    this.linkedModule,
    this.linkedLabel,
    this.dismissedUntil,
  });

  final String id;
  String name;
  DocCategory category;
  DateTime? issueDate;

  /// Null = permanent document with no expiry (PRD 9.1 AC1).
  DateTime? expiryDate;
  int reminderLeadMonths;
  AlertType alertType;
  String? filePath;

  /// Any file type is supported, not just image/PDF (closes PRD Gap 3).
  String? fileExtension;

  /// Per-document biometric/PIN lock (closes PRD Gap 2).
  bool locked;
  bool redactSensitiveNumbers;
  String note;
  String? linkedModule;
  String? linkedLabel;

  /// "Dismiss" from the Alerts screen suppresses the expiry alert until then.
  DateTime? dismissedUntil;

  bool get hasExpiry => expiryDate != null;

  int? daysLeftFrom(DateTime now) =>
      expiryDate?.difference(DateTime(now.year, now.month, now.day)).inDays;

  String statusChip(DateTime now) {
    final int? d = daysLeftFrom(now);
    if (d == null) return 'No expiry';
    if (d < 0) return 'Expired';
    if (d <= 30) return 'Urgent';
    if (d <= 90) return 'Renew soon';
    return 'Valid';
  }

  bool isExpiringSoon(DateTime now) {
    if (dismissedUntil != null && now.isBefore(dismissedUntil!)) return false;
    final int? d = daysLeftFrom(now);
    return d != null && d >= 0 && d <= 90;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'category': category.index,
        'issueDate': issueDate?.toIso8601String(),
        'expiryDate': expiryDate?.toIso8601String(),
        'reminderLeadMonths': reminderLeadMonths,
        'alertType': alertType.index,
        'filePath': filePath,
        'fileExtension': fileExtension,
        'locked': locked,
        'redactSensitiveNumbers': redactSensitiveNumbers,
        'note': note,
        'linkedModule': linkedModule,
        'linkedLabel': linkedLabel,
        'dismissedUntil': dismissedUntil?.toIso8601String(),
      };

  factory StoredDocument.fromJson(Map<String, dynamic> j) => StoredDocument(
        id: j['id'] as String,
        name: j['name'] as String,
        category: DocCategory.values[j['category'] as int],
        issueDate: j['issueDate'] == null
            ? null
            : DateTime.parse(j['issueDate'] as String),
        expiryDate: j['expiryDate'] == null
            ? null
            : DateTime.parse(j['expiryDate'] as String),
        reminderLeadMonths: j['reminderLeadMonths'] as int? ?? 3,
        alertType: AlertType.values[j['alertType'] as int? ?? 0],
        filePath: j['filePath'] as String?,
        fileExtension: j['fileExtension'] as String?,
        locked: j['locked'] as bool? ?? false,
        redactSensitiveNumbers: j['redactSensitiveNumbers'] as bool? ?? false,
        note: j['note'] as String? ?? '',
        linkedModule: j['linkedModule'] as String?,
        linkedLabel: j['linkedLabel'] as String?,
        dismissedUntil: j['dismissedUntil'] == null
            ? null
            : DateTime.parse(j['dismissedUntil'] as String),
      );
}
