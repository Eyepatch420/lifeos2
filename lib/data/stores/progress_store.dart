import 'package:flutter/foundation.dart';

import 'persistence.dart';

/// Persists one wellness score per month so "vs last month" is a real
/// historical comparison (PRD 1.3).
///
/// Previously the comparison recomputed today's numbers with a past date,
/// which mostly reproduced the current score — the delta was near-meaningless.
class ProgressStore extends ChangeNotifier {
  ProgressStore() {
    _load();
  }

  static const String _key = 'progress_snapshots';

  /// 'YYYY-MM' → score 0..100.
  final Map<String, int> _snapshots = <String, int>{};

  static String monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  void _load() {
    final Map<String, dynamic>? j = Persistence.load(_key);
    if (j == null) return;
    (j['snapshots'] as Map<String, dynamic>? ?? <String, dynamic>{})
        .forEach((String k, dynamic v) => _snapshots[k] = v as int);
  }

  void flush() {
    Persistence.save(_key, <String, dynamic>{'snapshots': _snapshots});
  }

  @override
  void notifyListeners() {
    flush();
    super.notifyListeners();
  }

  /// Records this month's score. Called whenever the progress screen computes
  /// one, so history accumulates naturally as the app is used.
  void record(DateTime month, int score) {
    final String key = monthKey(month);
    if (_snapshots[key] == score) return; // no churn
    _snapshots[key] = score;
    notifyListeners();
  }

  int? scoreFor(DateTime month) => _snapshots[monthKey(month)];

  /// The previous month's recorded score, or null when we have no history yet
  /// — the UI must say "no comparison yet" rather than invent a delta.
  int? previousMonthScore(DateTime now) =>
      scoreFor(DateTime(now.year, now.month - 1, 1));

  /// Oldest-first history, for a trend sparkline.
  List<(String, int)> get history {
    final List<String> keys = _snapshots.keys.toList()..sort();
    return keys.map((String k) => (k, _snapshots[k]!)).toList();
  }

  int get monthsTracked => _snapshots.length;
}
