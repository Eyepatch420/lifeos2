import 'package:flutter/material.dart';

import '../../core/utils/date_x.dart';
import '../models/commitments.dart';
import '../models/enums.dart';
import 'persistence.dart';

/// Owns memberships, bills/subscriptions/EMIs and stored documents
/// (PRD 7.x, 8.x, 9.x). They share expiry/renewal mechanics so they live
/// together and stay consistent.
class CommitmentsStore extends ChangeNotifier {
  CommitmentsStore() {
    _load();
  }

  static const String _key = 'commitments';

  final List<Membership> _memberships = <Membership>[];
  final List<Bill> _bills = <Bill>[];
  final List<StoredDocument> _documents = <StoredDocument>[];

  bool _load() {
    final Map<String, dynamic>? j = Persistence.load(_key);
    if (j == null) return false;
    _memberships.addAll((j['memberships'] as List<dynamic>)
        .map((dynamic m) => Membership.fromJson(m as Map<String, dynamic>)));
    _bills.addAll((j['bills'] as List<dynamic>)
        .map((dynamic b) => Bill.fromJson(b as Map<String, dynamic>)));
    _documents.addAll((j['documents'] as List<dynamic>)
        .map((dynamic d) => StoredDocument.fromJson(d as Map<String, dynamic>)));
    return true;
  }

  void flush() {
    Persistence.save(_key, <String, dynamic>{
      'memberships': _memberships.map((Membership m) => m.toJson()).toList(),
      'bills': _bills.map((Bill b) => b.toJson()).toList(),
      'documents': _documents.map((StoredDocument d) => d.toJson()).toList(),
    });
  }

  @override
  void notifyListeners() {
    flush();
    super.notifyListeners();
  }

  // ---- memberships ------------------------------------------------------

  List<Membership> get memberships =>
      List<Membership>.unmodifiable(_memberships);

  List<Membership> get activeMemberships =>
      _memberships.where((Membership m) => m.active).toList();

  Membership? membershipById(String id) {
    for (final Membership m in _memberships) {
      if (m.id == id) return m;
    }
    return null;
  }

  List<Membership> membershipsIn(MembershipCategory? c) => c == null
      ? activeMemberships
      : activeMemberships.where((Membership m) => m.category == c).toList();

  List<Membership> expiringMemberships(DateTime now) {
    final List<Membership> list = activeMemberships
        .where((Membership m) => m.isExpiringSoon(now))
        .toList();
    list.sort((Membership a, Membership b) => a.expiryDate.compareTo(b.expiryDate));
    return list;
  }

  double get totalAnnualCost => activeMemberships
      .fold<double>(0, (double s, Membership m) => s + m.annualCost);

  /// Fraction of logged renewals that were actually paid (not missed), across
  /// all active memberships with any renewal history. Feeds [ScoreEngine] —
  /// see `score_engine.dart`.
  double get renewalAdherence {
    final List<RenewalEntry> entries = activeMemberships
        .expand((Membership m) => m.history)
        .toList();
    if (entries.isEmpty) return 1;
    final int paid = entries.where((RenewalEntry e) => e.paid).length;
    return paid / entries.length;
  }

  bool get hasRenewalHistory =>
      activeMemberships.any((Membership m) => m.history.isNotEmpty);

  void addMembership(Membership m) {
    _memberships.add(m);
    notifyListeners();
  }

  void updateMembership(Membership m) {
    final int i = _memberships.indexWhere((Membership x) => x.id == m.id);
    if (i >= 0) _memberships[i] = m;
    notifyListeners();
  }

  /// PRD 7.2 AC2 — advance expiry by exactly one cycle and log a paid entry.
  void markRenewed(Membership m, DateTime now) {
    final int months = m.cycle.months;
    final DateTime from = m.expiryDate;
    final DateTime next = months > 0
        ? DateTime(from.year, from.month + months, from.day)
        : from.add(const Duration(days: 7));
    m.history.insert(
      0,
      RenewalEntry(date: dayKey(now), amountPaise: m.costPaise, paid: true),
    );
    m.startDate = from;
    m.expiryDate = next;
    notifyListeners();
  }

  /// PRD 7.2 AC3 — cancelling retains history.
  void cancelMembership(Membership m) {
    m.active = false;
    notifyListeners();
  }

  void deleteMembership(String id) {
    _memberships.removeWhere((Membership m) => m.id == id);
    notifyListeners();
  }

  // ---- bills ------------------------------------------------------------

  List<Bill> get bills => List<Bill>.unmodifiable(_bills);
  List<Bill> get activeBills => _bills.where((Bill b) => b.active).toList();

  Bill? billById(String id) {
    for (final Bill b in _bills) {
      if (b.id == id) return b;
    }
    return null;
  }

  List<Bill> billsOfKind(BillKind? k) =>
      k == null ? activeBills : activeBills.where((Bill b) => b.kind == k).toList();

  List<Bill> overdueBills(DateTime now) {
    final List<Bill> list =
        activeBills.where((Bill b) => b.isOverdue(now)).toList();
    list.sort((Bill a, Bill b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  List<Bill> dueThisWeek(DateTime now) {
    final List<Bill> list =
        activeBills.where((Bill b) => b.isDueThisWeek(now)).toList();
    list.sort((Bill a, Bill b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  /// PRD 8.1 AC1 — normalised across all cycles.
  double get monthlyCommitted => activeBills
      .fold<double>(0, (double s, Bill b) => s + b.monthlyEquivalent);

  double dueThisWeekTotal(DateTime now) => dueThisWeek(now)
      .fold<double>(0, (double s, Bill b) => s + b.amount);

  double overdueTotal(DateTime now) => overdueBills(now)
      .fold<double>(0, (double s, Bill b) => s + b.amount);

  /// Fraction of active, non-autopay bills that are currently NOT overdue.
  /// Feeds [ScoreEngine] — see `score_engine.dart`.
  double paymentAdherence(DateTime now) {
    final List<Bill> tracked =
        activeBills.where((Bill b) => !b.autoPay).toList();
    if (tracked.isEmpty) return 1;
    final int onTime =
        tracked.where((Bill b) => !b.isOverdue(now)).length;
    return onTime / tracked.length;
  }

  bool get hasBillsTracked => activeBills.isNotEmpty;

  void addBill(Bill b) {
    _bills.add(b);
    notifyListeners();
  }

  void updateBill(Bill b) {
    final int i = _bills.indexWhere((Bill x) => x.id == b.id);
    if (i >= 0) _bills[i] = b;
    notifyListeners();
  }

  void deleteBill(String id) {
    _bills.removeWhere((Bill b) => b.id == id);
    notifyListeners();
  }

  /// PRD 8.1 AC4 — paying an EMI installment advances progress and balance.
  void markBillPaid(Bill b, DateTime now) {
    b.lastPaidOn = dayKey(now);
    if (b.kind == BillKind.emi && b.installmentsTotal != null) {
      if (b.installmentsPaid < b.installmentsTotal!) b.installmentsPaid++;
    }
    b.dueDate = b.nextDueDate();
    notifyListeners();
  }

  /// PRD 8.1 AC3 — toggling auto-renew off keeps the record and history.
  void toggleAutoPay(Bill b) {
    b.autoPay = !b.autoPay;
    notifyListeners();
  }

  void setBillActive(Bill b, bool value) {
    b.active = value;
    notifyListeners();
  }

  // ---- documents --------------------------------------------------------

  List<StoredDocument> get documents =>
      List<StoredDocument>.unmodifiable(_documents);

  StoredDocument? documentById(String id) {
    for (final StoredDocument d in _documents) {
      if (d.id == id) return d;
    }
    return null;
  }

  List<StoredDocument> documentsIn(DocCategory? c) => c == null
      ? documents
      : _documents.where((StoredDocument d) => d.category == c).toList();

  List<StoredDocument> expiringDocuments(DateTime now) {
    final List<StoredDocument> list = _documents
        .where((StoredDocument d) => d.isExpiringSoon(now))
        .toList();
    list.sort((StoredDocument a, StoredDocument b) =>
        a.expiryDate!.compareTo(b.expiryDate!));
    return list;
  }

  void addDocument(StoredDocument d) {
    _documents.add(d);
    notifyListeners();
  }

  void updateDocument(StoredDocument d) {
    final int i = _documents.indexWhere((StoredDocument x) => x.id == d.id);
    if (i >= 0) _documents[i] = d;
    notifyListeners();
  }

  void deleteDocument(String id) {
    _documents.removeWhere((StoredDocument d) => d.id == id);
    notifyListeners();
  }

  void toggleDocumentLock(StoredDocument d) {
    d.locked = !d.locked;
    notifyListeners();
  }

  // ---- alert suppression (Alerts screen secondary actions) ---------------

  /// Hides an overdue bill's alert for [minutes] without marking it paid.
  void snoozeBill(Bill b, int minutes) {
    b.snoozedUntil = DateTime.now().add(Duration(minutes: minutes));
    notifyListeners();
  }

  /// "Remind later" — suppresses the expiry alert until tomorrow.
  void remindMembershipLater(Membership m, {int days = 1}) {
    m.remindLaterUntil = DateTime.now().add(Duration(days: days));
    notifyListeners();
  }

  /// "Dismiss" — suppresses a document expiry alert until tomorrow.
  void dismissDocumentAlert(StoredDocument d, {int days = 1}) {
    d.dismissedUntil = DateTime.now().add(Duration(days: days));
    notifyListeners();
  }

  void seed() {
    final DateTime now = DateTime.now();
    final DateTime today = dayKey(now);

    _memberships.addAll(<Membership>[
      Membership(
        id: 'mem_cult',
        name: 'Cult.fit gym',
        category: MembershipCategory.fitness,
        costPaise: 250000,
        cycle: BillingCycle.monthly,
        location: 'Andheri West',
        startDate: today.subtract(const Duration(days: 22)),
        expiryDate: today.add(const Duration(days: 8)),
        reminderLeadDays: 7,
        alertType: AlertType.alarm,
        history: <RenewalEntry>[
          RenewalEntry(
              date: today.subtract(const Duration(days: 22)),
              amountPaise: 250000,
              paid: true),
          RenewalEntry(
              date: today.subtract(const Duration(days: 52)),
              amountPaise: 250000,
              paid: true),
          RenewalEntry(
              date: today.subtract(const Duration(days: 112)),
              amountPaise: 250000,
              paid: false,
              note: 'Missed renewal · 3 day gap'),
        ],
      ),
      Membership(
        id: 'mem_yoga',
        name: 'Yoga studio — quarterly',
        category: MembershipCategory.fitness,
        costPaise: 360000,
        cycle: BillingCycle.quarterly,
        location: 'Goregaon',
        startDate: today.subtract(const Duration(days: 21)),
        expiryDate: today.add(const Duration(days: 69)),
      ),
      Membership(
        id: 'mem_swim',
        name: 'Swimming pool — annual',
        category: MembershipCategory.fitness,
        costPaise: 800000,
        cycle: BillingCycle.yearly,
        location: 'Society pool',
        startDate: today.subtract(const Duration(days: 60)),
        expiryDate: today.add(const Duration(days: 305)),
      ),
      Membership(
        id: 'mem_apollo',
        name: 'Apollo 247 health plan',
        category: MembershipCategory.health,
        costPaise: 199900,
        cycle: BillingCycle.yearly,
        location: 'Unlimited teleconsult',
        startDate: today.subtract(const Duration(days: 180)),
        expiryDate: today.add(const Duration(days: 185)),
      ),
      Membership(
        id: 'mem_thyro',
        name: 'Thyrocare annual package',
        category: MembershipCategory.health,
        costPaise: 150000,
        cycle: BillingCycle.yearly,
        location: '6 test panels',
        startDate: today.subtract(const Duration(days: 270)),
        expiryDate: today.add(const Duration(days: 95)),
      ),
      Membership(
        id: 'mem_library',
        name: 'Society library',
        category: MembershipCategory.club,
        costPaise: 50000,
        cycle: BillingCycle.yearly,
        location: 'Goregaon West',
        startDate: today.subtract(const Duration(days: 346)),
        expiryDate: today.add(const Duration(days: 19)),
      ),
      Membership(
        id: 'mem_cci',
        name: 'CCI club — annual',
        category: MembershipCategory.club,
        costPaise: 1200000,
        cycle: BillingCycle.yearly,
        location: 'Churchgate',
        startDate: today.subtract(const Duration(days: 120)),
        expiryDate: today.add(const Duration(days: 245)),
      ),
    ]);

    _bills.addAll(<Bill>[
      Bill(
        id: 'bill_hdfc',
        name: 'HDFC credit card minimum',
        kind: BillKind.creditCard,
        amountPaise: 80000,
        cycle: BillingCycle.monthly,
        dueDate: today.subtract(const Duration(days: 2)),
        dayOfMonth: 10,
      ),
      Bill(
        id: 'bill_rent',
        name: 'Rent',
        kind: BillKind.bill,
        amountPaise: 900000,
        cycle: BillingCycle.monthly,
        dueDate: today.add(const Duration(days: 3)),
        dayOfMonth: 15,
        linkedCategoryId: 'cat_housing',
      ),
      Bill(
        id: 'bill_airtel',
        name: 'Airtel postpaid',
        kind: BillKind.bill,
        amountPaise: 59900,
        cycle: BillingCycle.monthly,
        dueDate: today.add(const Duration(days: 4)),
        dayOfMonth: 16,
      ),
      Bill(
        id: 'bill_netflix',
        name: 'Netflix',
        kind: BillKind.subscription,
        amountPaise: 64900,
        cycle: BillingCycle.monthly,
        dueDate: today.add(const Duration(days: 5)),
        dayOfMonth: 17,
        autoPay: true,
      ),
      Bill(
        id: 'bill_spotify',
        name: 'Spotify Premium',
        kind: BillKind.subscription,
        amountPaise: 11900,
        cycle: BillingCycle.monthly,
        dueDate: today.add(const Duration(days: 10)),
        dayOfMonth: 22,
        autoPay: true,
      ),
      Bill(
        id: 'bill_hotstar',
        name: 'Hotstar',
        kind: BillKind.subscription,
        amountPaise: 29900,
        cycle: BillingCycle.monthly,
        dueDate: today.add(const Duration(days: 16)),
        dayOfMonth: 28,
        autoPay: true,
      ),
      Bill(
        id: 'bill_icloud',
        name: 'iCloud 200GB',
        kind: BillKind.subscription,
        amountPaise: 7500,
        cycle: BillingCycle.monthly,
        dueDate: today.add(const Duration(days: 18)),
        dayOfMonth: 30,
      ),
      Bill(
        id: 'bill_macbook',
        name: 'MacBook EMI',
        kind: BillKind.emi,
        amountPaise: 420000,
        cycle: BillingCycle.monthly,
        dueDate: today.add(const Duration(days: 8)),
        dayOfMonth: 20,
        installmentsPaid: 6,
        installmentsTotal: 12,
      ),
      Bill(
        id: 'bill_home',
        name: 'Home loan EMI',
        kind: BillKind.emi,
        amountPaise: 2200000,
        cycle: BillingCycle.monthly,
        dueDate: today.add(const Duration(days: 12)),
        dayOfMonth: 5,
        installmentsPaid: 36,
        installmentsTotal: 240,
        autoPay: true,
      ),
    ]);

    _documents.addAll(<StoredDocument>[
      StoredDocument(
        id: 'doc_aadhaar',
        name: 'Aadhaar card',
        category: DocCategory.identity,
        note: 'Stored with number redacted',
        redactSensitiveNumbers: true,
        locked: true,
        fileExtension: 'pdf',
      ),
      StoredDocument(
        id: 'doc_pan',
        name: 'PAN card',
        category: DocCategory.identity,
        note: 'Identity · Financial',
        locked: true,
        fileExtension: 'jpg',
      ),
      StoredDocument(
        id: 'doc_passport',
        name: 'Passport',
        category: DocCategory.identity,
        issueDate: today.subtract(const Duration(days: 1500)),
        expiryDate: today.add(const Duration(days: 2080)),
        fileExtension: 'pdf',
      ),
      StoredDocument(
        id: 'doc_dl',
        name: 'Driving licence',
        category: DocCategory.identity,
        issueDate: today.subtract(const Duration(days: 5400)),
        expiryDate: today.add(const Duration(days: 18)),
        reminderLeadMonths: 3,
        fileExtension: 'pdf',
      ),
      StoredDocument(
        id: 'doc_starhealth',
        name: 'Star Health insurance',
        category: DocCategory.insurance,
        expiryDate: today.add(const Duration(days: 210)),
        note: 'Rs 12,400/yr',
        fileExtension: 'pdf',
      ),
      StoredDocument(
        id: 'doc_vehins',
        name: 'Vehicle insurance',
        category: DocCategory.insurance,
        expiryDate: today.add(const Duration(days: 33)),
        fileExtension: 'pdf',
      ),
      StoredDocument(
        id: 'doc_itr',
        name: 'ITR 2024–25',
        category: DocCategory.insurance,
        issueDate: today.subtract(const Duration(days: 120)),
        note: 'Filed · Verified',
        locked: true,
        fileExtension: 'pdf',
      ),
      StoredDocument(
        id: 'doc_deed',
        name: 'Flat registration deed',
        category: DocCategory.property,
        note: 'Property · Goregaon West',
        locked: true,
        fileExtension: 'pdf',
      ),
      StoredDocument(
        id: 'doc_rc',
        name: 'Vehicle RC — MH02 AB 1234',
        category: DocCategory.vehicle,
        expiryDate: today.add(const Duration(days: 3200)),
        note: 'Maruti Swift',
        fileExtension: 'jpg',
      ),
      StoredDocument(
        id: 'doc_prescription',
        name: 'Metformin prescription',
        category: DocCategory.medical,
        expiryDate: today.add(const Duration(days: 160)),
        note: 'Dr. Mehta',
        linkedModule: 'Reminders',
        linkedLabel: 'Metformin 500mg',
        fileExtension: 'pdf',
      ),
    ]);
  }
}
