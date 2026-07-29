import 'package:flutter/foundation.dart';

import 'migration_runner.dart';
import 'persistence.dart';

/// Persists one wellness score per month so "vs last month" is a real
/// historical comparison (PRD 1.3).
///
/// Previously the comparison recomputed today's numbers with a past date,
/// which mostly reproduced the current score — the delta was near-meaningless.
class ProgressStore extends ChangeNotifier {
  ProgressStore() {
    _registerMigrations();
    _load();
  }

  static const String _key = 'progress_snapshots';

  /// v1: `{month: score}`. v2: `{month: {composite: score, modules: {key: value}}}`
  /// so each module's contribution survives independently of the composite —
  /// see [ScoreEngine].
  static const int _schemaVersion = 2;

  /// 'YYYY-MM' → composite score 0..100.
  final Map<String, int> _snapshots = <String, int>{};

  /// 'YYYY-MM' → per-module score 0..100, only populated from v2 onward.
  final Map<String, Map<String, int>> _moduleSnapshots =
      <String, Map<String, int>>{};

  static String monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static bool _migrationsRegistered = false;

  static void _registerMigrations() {
    if (_migrationsRegistered) return;
    _migrationsRegistered = true;
    MigrationRunner.register(_key, 1, (Map<String, dynamic> blob) {
      final Map<String, dynamic> oldSnapshots =
          blob['snapshots'] as Map<String, dynamic>? ?? <String, dynamic>{};
      return <String, dynamic>{
        'snapshots': oldSnapshots.map((String k, dynamic v) =>
            MapEntry<String, dynamic>(k, <String, dynamic>{'composite': v})),
      };
    });
  }

  void _load() {
    final Map<String, dynamic>? raw = Persistence.load(_key);
    if (raw == null) return;
    final Map<String, dynamic> j = MigrationRunner.run(
      _key,
      raw,
      currentVersion: _schemaVersion,
      seedFallback: () => <String, dynamic>{'snapshots': <String, dynamic>{}},
    );
    (j['snapshots'] as Map<String, dynamic>? ?? <String, dynamic>{})
        .forEach((String k, dynamic v) {
      if (v is int) {
        // Pre-migration shape slipped through (shouldn't happen, defensive).
        _snapshots[k] = v;
      } else {
        final Map<String, dynamic> entry = v as Map<String, dynamic>;
        _snapshots[k] = entry['composite'] as int;
        final Map<String, dynamic>? modules =
            entry['modules'] as Map<String, dynamic>?;
        if (modules != null) {
          _moduleSnapshots[k] = modules
              .map((String mk, dynamic mv) => MapEntry<String, int>(mk, mv as int));
        }
      }
    });
  }

  void flush() {
    Persistence.save(
      _key,
      <String, dynamic>{
        'snapshots': _snapshots.map((String k, int v) => MapEntry<String, dynamic>(
              k,
              <String, dynamic>{
                'composite': v,
                if (_moduleSnapshots[k] != null) 'modules': _moduleSnapshots[k],
              },
            )),
      },
      version: _schemaVersion,
    );
  }

  @override
  void notifyListeners() {
    flush();
    super.notifyListeners();
  }

  /// Records this month's composite score plus each module's individual
  /// contribution, so a future redesign of the weighting can be re-derived
  /// from history instead of only ever seeing the blended number.
  void record(DateTime month, int score, [Map<String, int>? moduleScores]) {
    final String key = monthKey(month);
    final bool sameComposite = _snapshots[key] == score;
    final bool sameModules = moduleScores == null ||
        _mapsEqual(_moduleSnapshots[key], moduleScores);
    if (sameComposite && sameModules) return; // no churn
    _snapshots[key] = score;
    if (moduleScores != null) _moduleSnapshots[key] = moduleScores;
    notifyListeners();
  }

  static bool _mapsEqual(Map<String, int>? a, Map<String, int> b) {
    if (a == null || a.length != b.length) return false;
    for (final MapEntry<String, int> e in b.entries) {
      if (a[e.key] != e.value) return false;
    }
    return true;
  }

  int? scoreFor(DateTime month) => _snapshots[monthKey(month)];

  Map<String, int>? moduleScoresFor(DateTime month) =>
      _moduleSnapshots[monthKey(month)];

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
