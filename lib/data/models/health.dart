import 'enums.dart';

/// One measured value inside a lab report (PRD 5.2).
class LabMarker {
  LabMarker({
    required this.name,
    required this.value,
    required this.unit,
    required this.normalLow,
    required this.normalHigh,
    this.borderlineTolerance = 0.1,
  });

  // Mutable so extraction errors can be corrected in-place (PRD 5.2 AC3).
  String name;
  double value;
  String unit;
  double normalLow;
  double normalHigh;

  /// Fraction beyond the normal range still treated as "borderline" rather
  /// than outright abnormal. PRD 5.2 AC2 requires an explicit boundary rule:
  /// range bounds are INCLUSIVE, so a value equal to normalLow/normalHigh is
  /// Normal.
  final double borderlineTolerance;

  MarkerStatus get status {
    if (value >= normalLow && value <= normalHigh) return MarkerStatus.normal;
    final double span = (normalHigh - normalLow).abs();
    final double slack = span * borderlineTolerance;
    if (value < normalLow && value >= normalLow - slack) {
      return MarkerStatus.borderline;
    }
    if (value > normalHigh && value <= normalHigh + slack) {
      return MarkerStatus.borderline;
    }
    return MarkerStatus.abnormal;
  }

  String get rangeLabel =>
      'Normal: ${_fmt(normalLow)}–${_fmt(normalHigh)} $unit';

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'value': value,
        'unit': unit,
        'normalLow': normalLow,
        'normalHigh': normalHigh,
        'borderlineTolerance': borderlineTolerance,
      };

  factory LabMarker.fromJson(Map<String, dynamic> j) => LabMarker(
        name: j['name'] as String,
        value: (j['value'] as num).toDouble(),
        unit: j['unit'] as String,
        normalLow: (j['normalLow'] as num).toDouble(),
        normalHigh: (j['normalHigh'] as num).toDouble(),
        borderlineTolerance:
            (j['borderlineTolerance'] as num?)?.toDouble() ?? 0.1,
      );
}

/// A scanned lab report (PRD 5.1/5.2).
class LabReport {
  LabReport({
    required this.id,
    required this.name,
    required this.lab,
    required this.date,
    required this.markers,
    this.autoExtracted = true,
  });

  final String id;
  String name;
  String lab;
  DateTime date;
  List<LabMarker> markers;

  /// Drives the persistent "values extracted automatically" disclaimer.
  bool autoExtracted;

  int countOf(MarkerStatus s) =>
      markers.where((LabMarker m) => m.status == s).length;

  /// Severity badge shown on the reports list (PRD 5.1 AC1).
  String get summaryBadge {
    final int abnormal = countOf(MarkerStatus.abnormal);
    final int borderline = countOf(MarkerStatus.borderline);
    if (abnormal > 0) return '$abnormal high';
    if (borderline > 0) return '$borderline borderline';
    return 'All normal';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'lab': lab,
        'date': date.toIso8601String(),
        'markers': markers.map((LabMarker m) => m.toJson()).toList(),
        'autoExtracted': autoExtracted,
      };

  factory LabReport.fromJson(Map<String, dynamic> j) => LabReport(
        id: j['id'] as String,
        name: j['name'] as String,
        lab: j['lab'] as String,
        date: DateTime.parse(j['date'] as String),
        markers: (j['markers'] as List<dynamic>)
            .map((dynamic m) => LabMarker.fromJson(m as Map<String, dynamic>))
            .toList(),
        autoExtracted: j['autoExtracted'] as bool? ?? true,
      );
}

/// A single vitals reading (PRD 5.4).
class VitalReading {
  VitalReading({
    required this.kind,
    required this.value,
    required this.takenAt,
    this.secondaryValue,
    this.context = '',
  });

  final VitalKind kind;

  /// Systolic for BP; the single value otherwise.
  final double value;

  /// Diastolic for BP; null otherwise.
  final double? secondaryValue;
  final DateTime takenAt;
  final String context;

  String get display => kind == VitalKind.bloodPressure
      ? '${value.toStringAsFixed(0)}/${secondaryValue?.toStringAsFixed(0) ?? '-'}'
      : value.toStringAsFixed(kind == VitalKind.weight ? 1 : 1);

  /// PRD 5.4 AC1 — thresholds are declared once per vital, never per reading.
  MarkerStatus get status {
    switch (kind) {
      case VitalKind.bloodPressure:
        final double sys = value;
        final double dia = secondaryValue ?? 0;
        if (sys >= 140 || dia >= 90) return MarkerStatus.abnormal;
        if (sys >= 130 || dia >= 80) return MarkerStatus.borderline;
        return MarkerStatus.normal;
      case VitalKind.bloodSugar:
        if (value >= 126) return MarkerStatus.abnormal;
        if (value >= 100) return MarkerStatus.borderline;
        return MarkerStatus.normal;
      case VitalKind.weight:
        return MarkerStatus.normal;
      case VitalKind.sleep:
        if (value < 6) return MarkerStatus.abnormal;
        if (value < 7) return MarkerStatus.borderline;
        return MarkerStatus.normal;
    }
  }

  String get statusLabel {
    if (kind == VitalKind.sleep) {
      return status == MarkerStatus.normal ? 'On goal' : 'Below goal';
    }
    if (kind == VitalKind.weight) return 'Logged';
    return status.label;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.index,
        'value': value,
        'secondaryValue': secondaryValue,
        'takenAt': takenAt.toIso8601String(),
        'context': context,
      };

  factory VitalReading.fromJson(Map<String, dynamic> j) => VitalReading(
        kind: VitalKind.values[j['kind'] as int],
        value: (j['value'] as num).toDouble(),
        secondaryValue: (j['secondaryValue'] as num?)?.toDouble(),
        takenAt: DateTime.parse(j['takenAt'] as String),
        context: j['context'] as String? ?? '',
      );
}

/// A daily subjective mood + symptom entry (PRD 5.3).
class WellnessEntry {
  WellnessEntry({
    required this.date,
    required this.mood,
    this.symptoms = const <String>[],
    this.note = '',
    this.energy = 'Medium',
    this.sleepHours,
  });

  final DateTime date;
  Mood mood;
  List<String> symptoms;
  String note;
  String energy;
  double? sleepHours;

  String get symptomSummary =>
      symptoms.isEmpty ? 'No symptoms' : symptoms.join(', ');

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date.toIso8601String(),
        'mood': mood.index,
        'symptoms': symptoms,
        'note': note,
        'energy': energy,
        'sleepHours': sleepHours,
      };

  factory WellnessEntry.fromJson(Map<String, dynamic> j) => WellnessEntry(
        date: DateTime.parse(j['date'] as String),
        mood: Mood.values[j['mood'] as int],
        symptoms:
            (j['symptoms'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
        note: j['note'] as String? ?? '',
        energy: j['energy'] as String? ?? 'Medium',
        sleepHours: (j['sleepHours'] as num?)?.toDouble(),
      );
}
