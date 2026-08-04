import 'package:flutter/material.dart';

import '../../core/utils/date_x.dart';
import '../models/enums.dart';
import '../models/health.dart';
import 'persistence.dart';

/// Owns lab reports, vitals and the wellness log (PRD 5.x).
class HealthStore extends ChangeNotifier {
  HealthStore() {
    _load();
  }

  static const String _key = 'health';

  final List<LabReport> _reports = <LabReport>[];
  final List<VitalReading> _vitals = <VitalReading>[];
  final List<WellnessEntry> _wellness = <WellnessEntry>[];

  bool _load() {
    final Map<String, dynamic>? j = Persistence.load(_key);
    if (j == null) return false;
    _reports.addAll((j['reports'] as List<dynamic>)
        .map((dynamic r) => LabReport.fromJson(r as Map<String, dynamic>)));
    _vitals.addAll((j['vitals'] as List<dynamic>)
        .map((dynamic v) => VitalReading.fromJson(v as Map<String, dynamic>)));
    _wellness.addAll((j['wellness'] as List<dynamic>)
        .map((dynamic w) => WellnessEntry.fromJson(w as Map<String, dynamic>)));
    final List<String> extra =
        (j['symptomOptions'] as List<dynamic>? ?? <dynamic>[]).cast<String>();
    for (final String s in extra) {
      if (!symptomOptions.contains(s)) symptomOptions.add(s);
    }
    return true;
  }

  void flush() {
    Persistence.save(_key, <String, dynamic>{
      'reports': _reports.map((LabReport r) => r.toJson()).toList(),
      'vitals': _vitals.map((VitalReading v) => v.toJson()).toList(),
      'wellness': _wellness.map((WellnessEntry w) => w.toJson()).toList(),
      'symptomOptions': symptomOptions,
    });
  }

  @override
  void notifyListeners() {
    flush();
    super.notifyListeners();
  }

  /// User-extensible symptom vocabulary (PRD 5.3 FR2).
  final List<String> symptomOptions = <String>[
    'Headache',
    'Fatigue',
    'Nausea',
    'Dizziness',
    'Chest pain',
    'Blurred vision',
    'Joint pain',
  ];

  List<LabReport> get reports {
    final List<LabReport> list = List<LabReport>.from(_reports);
    list.sort((LabReport a, LabReport b) => b.date.compareTo(a.date));
    return list;
  }

  List<WellnessEntry> get wellnessEntries {
    final List<WellnessEntry> list = List<WellnessEntry>.from(_wellness);
    list.sort((WellnessEntry a, WellnessEntry b) => b.date.compareTo(a.date));
    return list;
  }

  LabReport? reportById(String id) {
    for (final LabReport r in _reports) {
      if (r.id == id) return r;
    }
    return null;
  }

  int get reportCount => _reports.length;

  /// Distinct markers tracked across all reports.
  int get trackedMarkerCount =>
      _reports.expand((LabReport r) => r.markers).map((LabMarker m) => m.name).toSet().length;

  /// PRD 5.1 AC3 — "Nd ago", including "Today".
  String lastScanLabel(DateTime now) {
    if (_reports.isEmpty) return 'No scans';
    final DateTime latest = reports.first.date;
    final int d = dayKey(now).difference(dayKey(latest)).inDays;
    if (d <= 0) return 'Today';
    if (d == 1) return '1d';
    return '${d}d';
  }

  /// Historical series for one marker name, oldest first (PRD 5.1/5.2).
  List<MapEntry<DateTime, LabMarker>> markerHistory(String name) {
    final List<MapEntry<DateTime, LabMarker>> out =
        <MapEntry<DateTime, LabMarker>>[];
    for (final LabReport r in _reports) {
      for (final LabMarker m in r.markers) {
        if (m.name == name) {
          out.add(MapEntry<DateTime, LabMarker>(r.date, m));
        }
      }
    }
    out.sort((MapEntry<DateTime, LabMarker> a, MapEntry<DateTime, LabMarker> b) =>
        a.key.compareTo(b.key));
    return out;
  }

  /// PRD 5.1 AC2 — a trend warning needs >= 3 points moving consistently in
  /// one direction, so a single noisy report cannot trigger a false alarm.
  bool hasConcerningTrend(String markerName) {
    final List<MapEntry<DateTime, LabMarker>> h = markerHistory(markerName);
    if (h.length < 3) return false;
    bool rising = true;
    for (int i = 1; i < h.length; i++) {
      if (h[i].value.value <= h[i - 1].value.value) {
        rising = false;
        break;
      }
    }
    final MarkerStatus last = h.last.value.status;
    return rising && last != MarkerStatus.normal;
  }

  List<String> get markerNames => _reports
      .expand((LabReport r) => r.markers)
      .map((LabMarker m) => m.name)
      .toSet()
      .toList();

  // ---- vitals ----------------------------------------------------------

  VitalReading? latestVital(VitalKind k) {
    final List<VitalReading> list =
        _vitals.where((VitalReading v) => v.kind == k).toList();
    if (list.isEmpty) return null;
    list.sort((VitalReading a, VitalReading b) => b.takenAt.compareTo(a.takenAt));
    return list.first;
  }

  List<VitalReading> vitalHistory(VitalKind k, {int days = 7}) {
    final DateTime cutoff = DateTime.now().subtract(Duration(days: days));
    final List<VitalReading> list = _vitals
        .where((VitalReading v) => v.kind == k && v.takenAt.isAfter(cutoff))
        .toList();
    list.sort((VitalReading a, VitalReading b) => a.takenAt.compareTo(b.takenAt));
    return list;
  }

  /// PRD 5.4 AC2 — delta is vs. the immediately prior reading.
  double? deltaFromPrevious(VitalKind k) {
    final List<VitalReading> list =
        _vitals.where((VitalReading v) => v.kind == k).toList();
    if (list.length < 2) return null;
    list.sort((VitalReading a, VitalReading b) => b.takenAt.compareTo(a.takenAt));
    return list[0].value - list[1].value;
  }

  bool vitalTrendRising(VitalKind k) {
    final List<VitalReading> h = vitalHistory(k);
    if (h.length < 3) return false;
    return h.last.value > h.first.value &&
        h.last.status != MarkerStatus.normal;
  }

  void addVital(VitalReading v) {
    _vitals.add(v);
    notifyListeners();
  }

  // ---- wellness log -----------------------------------------------------

  WellnessEntry? entryOn(DateTime date) {
    for (final WellnessEntry e in _wellness) {
      if (isSameDay(e.date, date)) return e;
    }
    return null;
  }

  bool hasEntryToday(DateTime now) => entryOn(now) != null;

  /// PRD 5.3 FR3 / AC2 — resolves the ambiguity explicitly: saving again for a
  /// day that already has an entry UPDATES it (the UI asks for confirmation).
  void saveWellness(WellnessEntry entry) {
    final int i =
        _wellness.indexWhere((WellnessEntry e) => isSameDay(e.date, entry.date));
    if (i >= 0) {
      _wellness[i] = entry;
    } else {
      _wellness.add(entry);
    }
    notifyListeners();
  }

  void addSymptomOption(String s) {
    final String v = s.trim();
    if (v.isEmpty) return;
    if (!symptomOptions.any((String x) => x.toLowerCase() == v.toLowerCase())) {
      symptomOptions.add(v);
      notifyListeners();
    }
  }

  void addReport(LabReport r) {
    _reports.add(r);
    notifyListeners();
  }

  void updateReport(LabReport r) {
    final int i = _reports.indexWhere((LabReport x) => x.id == r.id);
    if (i >= 0) _reports[i] = r;
    notifyListeners();
  }

  void deleteReport(String id) {
    _reports.removeWhere((LabReport r) => r.id == id);
    notifyListeners();
  }

  /// PRD 5.2 AC3 — a mis-extracted value must be correctable in place.
  void updateMarker(LabReport report, int index, LabMarker corrected) {
    if (index < 0 || index >= report.markers.length) return;
    report.markers[index] = corrected;
    notifyListeners();
  }

  // ---- vitals editing ----------------------------------------------------

  void deleteVital(VitalReading v) {
    _vitals.remove(v);
    notifyListeners();
  }

  void replaceVital(VitalReading old, VitalReading updated) {
    final int i = _vitals.indexOf(old);
    if (i >= 0) {
      _vitals[i] = updated;
      notifyListeners();
    }
  }

  /// Health-tracking adherence for the wellness composite (PRD 1.3).
  double trackingAdherence(DateTime now) {
    final DateTime monthStart = startOfMonth(now);
    final int daysSoFar = now.difference(monthStart).inDays + 1;
    final int logged = _wellness
        .where((WellnessEntry e) => !e.date.isBefore(monthStart))
        .length;
    if (daysSoFar <= 0) return 0;
    return (logged / daysSoFar).clamp(0.0, 1.0);
  }

  /// PRD 5.4 FR3 — doctor-ready export of symptoms + vitals for a period.
  String exportDoctorReport(DateTime now, {int days = 30}) {
    final DateTime from = dayKey(now.subtract(Duration(days: days)));
    final StringBuffer b = StringBuffer()
      ..writeln('DigiDaily wellness summary')
      ..writeln('Period: ${fmtShortDate.format(from)} - ${fmtShortDate.format(now)}')
      ..writeln('')
      ..writeln('SYMPTOM & MOOD LOG');
    for (final WellnessEntry e in wellnessEntries) {
      if (e.date.isBefore(from)) continue;
      b.writeln('${fmtShortDate.format(e.date)} | Mood: ${e.mood.label} | '
          '${e.symptomSummary} | Energy: ${e.energy}'
          '${e.sleepHours != null ? ' | Sleep: ${e.sleepHours}h' : ''}'
          '${e.note.isNotEmpty ? ' | Note: ${e.note}' : ''}');
    }
    b..writeln('')..writeln('VITALS');
    for (final VitalKind k in VitalKind.values) {
      final VitalReading? v = latestVital(k);
      if (v == null) continue;
      b.writeln('${k.label}: ${v.display} ${k.unit} '
          '(${v.statusLabel}) on ${fmtShortDate.format(v.takenAt)}');
    }
    b..writeln('')..writeln('LAB REPORTS');
    for (final LabReport r in reports) {
      if (r.date.isBefore(from)) continue;
      b.writeln('${fmtShortDate.format(r.date)} ${r.name} (${r.lab}): ${r.summaryBadge}');
    }
    return b.toString();
  }

  void seed() {
    final DateTime now = DateTime.now();

    _reports.addAll(<LabReport>[
      LabReport(
        id: 'rep_cbc',
        name: 'CBC Panel',
        lab: 'SRL Diagnostics',
        date: now.subtract(const Duration(days: 3)),
        markers: <LabMarker>[
          LabMarker(name: 'Haemoglobin', value: 13.8, unit: 'g/dL', normalLow: 12, normalHigh: 17),
          LabMarker(name: 'Platelets', value: 1.4, unit: 'L/uL', normalLow: 1.5, normalHigh: 4.5),
          LabMarker(name: 'WBC count', value: 12.4, unit: 'K/uL', normalLow: 4, normalHigh: 11),
          LabMarker(name: 'RBC count', value: 4.9, unit: 'M/uL', normalLow: 4.5, normalHigh: 5.5),
          LabMarker(name: 'HbA1c', value: 6.8, unit: '%', normalLow: 4, normalHigh: 5.6),
        ],
      ),
      LabReport(
        id: 'rep_lipid',
        name: 'Lipid profile',
        lab: 'Dr. Lal PathLabs',
        date: now.subtract(const Duration(days: 28)),
        markers: <LabMarker>[
          LabMarker(name: 'Haemoglobin', value: 13.4, unit: 'g/dL', normalLow: 12, normalHigh: 17),
          LabMarker(name: 'WBC count', value: 11.0, unit: 'K/uL', normalLow: 4, normalHigh: 11),
          LabMarker(name: 'HbA1c', value: 6.4, unit: '%', normalLow: 4, normalHigh: 5.6),
          LabMarker(name: 'Cholesterol', value: 205, unit: 'mg/dL', normalLow: 125, normalHigh: 200),
        ],
      ),
      LabReport(
        id: 'rep_hba1c',
        name: 'HbA1c + Glucose',
        lab: 'Thyrocare',
        date: now.subtract(const Duration(days: 70)),
        markers: <LabMarker>[
          LabMarker(name: 'HbA1c', value: 6.1, unit: '%', normalLow: 4, normalHigh: 5.6),
          LabMarker(name: 'WBC count', value: 10.2, unit: 'K/uL', normalLow: 4, normalHigh: 11),
          LabMarker(name: 'Haemoglobin', value: 13.2, unit: 'g/dL', normalLow: 12, normalHigh: 17),
        ],
      ),
      LabReport(
        id: 'rep_jan',
        name: 'Annual panel',
        lab: 'SRL Diagnostics',
        date: now.subtract(const Duration(days: 150)),
        markers: <LabMarker>[
          LabMarker(name: 'HbA1c', value: 5.9, unit: '%', normalLow: 4, normalHigh: 5.6),
          LabMarker(name: 'WBC count', value: 9.1, unit: 'K/uL', normalLow: 4, normalHigh: 11),
          LabMarker(name: 'Haemoglobin', value: 13.0, unit: 'g/dL', normalLow: 12, normalHigh: 17),
        ],
      ),
    ]);

    for (int i = 6; i >= 0; i--) {
      _vitals.add(VitalReading(
        kind: VitalKind.bloodPressure,
        value: 120 + (6 - i) * 1.4,
        secondaryValue: 78 + (6 - i) * 0.7,
        takenAt: now.subtract(Duration(days: i, hours: 2)),
        context: 'Morning',
      ));
    }
    _vitals.addAll(<VitalReading>[
      VitalReading(
          kind: VitalKind.bloodSugar,
          value: 104,
          takenAt: now.subtract(const Duration(hours: 6)),
          context: 'Fasting'),
      VitalReading(
          kind: VitalKind.bloodSugar,
          value: 99,
          takenAt: now.subtract(const Duration(days: 3)),
          context: 'Fasting'),
      VitalReading(
          kind: VitalKind.weight,
          value: 74.2,
          takenAt: now.subtract(const Duration(days: 1)),
          context: 'Morning'),
      VitalReading(
          kind: VitalKind.weight,
          value: 74.5,
          takenAt: now.subtract(const Duration(days: 8)),
          context: 'Morning'),
      VitalReading(
          kind: VitalKind.sleep,
          value: 6.5,
          takenAt: now.subtract(const Duration(hours: 8)),
          context: '11 PM - 5:30 AM'),
      VitalReading(
          kind: VitalKind.sleep,
          value: 7.2,
          takenAt: now.subtract(const Duration(days: 1, hours: 8)),
          context: '11 PM - 6:12 AM'),
    ]);

    _wellness.addAll(<WellnessEntry>[
      WellnessEntry(
        date: dayKey(now.subtract(const Duration(days: 1))),
        mood: Mood.good,
        energy: 'High',
        sleepHours: 7,
      ),
      WellnessEntry(
        date: dayKey(now.subtract(const Duration(days: 2))),
        mood: Mood.low,
        symptoms: <String>['Headache', 'Fatigue'],
        energy: 'Low',
        sleepHours: 5,
        note: 'Long day at work, skipped lunch.',
      ),
      WellnessEntry(
        date: dayKey(now.subtract(const Duration(days: 3))),
        mood: Mood.okay,
        symptoms: <String>['Dizziness'],
        energy: 'Medium',
        sleepHours: 6.5,
      ),
    ]);
  }
}
