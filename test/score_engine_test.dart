import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digilife/core/services/score_engine.dart';
import 'package:digilife/data/stores/persistence.dart';
import 'package:digilife/data/stores/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeProvider implements ScoreProvider {
  _FakeProvider(this.moduleKey, this.value, this.weight, {this.hasData = true});

  @override
  final String moduleKey;
  @override
  final double value;
  @override
  final double weight;
  @override
  final bool hasData;
  @override
  String get label => moduleKey;
  @override
  IconData get icon => Icons.circle;
  @override
  Color get color => Colors.black;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Persistence.reset();
  });

  test('weighted average matches the original hand-rolled formula', () {
    // Reminders 0.3 @ 0.8, Planner 0.3 @ 0.6, Budget 0.2 @ 1.0, Health 0.2 @ 0.5
    // -> (0.8*0.3 + 0.6*0.3 + 1.0*0.2 + 0.5*0.2) / 1.0 * 100 = 72
    final ScoreResult r = ScoreEngine.compute(<ScoreProvider>[
      _FakeProvider('Reminders', 0.8, 0.3),
      _FakeProvider('Planner', 0.6, 0.3),
      _FakeProvider('Budget', 1.0, 0.2),
      _FakeProvider('Health', 0.5, 0.2),
    ]);
    expect(r.score, 72);
  });

  test('a module with no data is excluded from both numerator and denominator', () {
    // Only Reminders (weight 0.3) has data at value 1.0 -> composite should be 100,
    // not (1.0*0.3)/(0.3+0.3+0.2+0.2)*100 which would incorrectly count no-data
    // modules as zero.
    final ScoreResult r = ScoreEngine.compute(<ScoreProvider>[
      _FakeProvider('Reminders', 1.0, 0.3),
      _FakeProvider('Planner', 0, 0.3, hasData: false),
      _FakeProvider('Budget', 0, 0.2, hasData: false),
      _FakeProvider('Health', 0, 0.2, hasData: false),
    ]);
    expect(r.score, 100);
  });

  test('no modules with data yields a score of 0, not a crash', () {
    final ScoreResult r = ScoreEngine.compute(<ScoreProvider>[
      _FakeProvider('Reminders', 0, 0.3, hasData: false),
    ]);
    expect(r.score, 0);
    expect(r.moduleValues, isEmpty);
  });

  test('moduleValues contains every scored module at 0..100', () {
    final ScoreResult r = ScoreEngine.compute(<ScoreProvider>[
      _FakeProvider('Reminders', 0.5, 0.5),
      _FakeProvider('Lists', 0.25, 0.5),
    ]);
    expect(r.moduleValues['Reminders'], 50);
    expect(r.moduleValues['Lists'], 25);
  });

  test('ProgressStore persists per-module snapshot breakdown and reads it back', () {
    final ProgressStore store = ProgressStore();
    final DateTime month = DateTime(2026, 3, 1);
    store.record(month, 72, <String, int>{'Reminders': 80, 'Lists': 60});

    final ProgressStore reloaded = ProgressStore();
    expect(reloaded.scoreFor(month), 72);
    expect(reloaded.moduleScoresFor(month), <String, int>{'Reminders': 80, 'Lists': 60});
  });

  test('old-shape {month: score} data migrates cleanly to the new schema', () {
    // Simulate a pre-migration blob written directly to storage.
    Persistence.save('progress_snapshots',
        <String, dynamic>{'snapshots': <String, dynamic>{'2026-01': 55}});

    final ProgressStore store = ProgressStore();
    expect(store.scoreFor(DateTime(2026, 1, 1)), 55);
    // No per-module breakdown existed pre-migration.
    expect(store.moduleScoresFor(DateTime(2026, 1, 1)), isNull);
  });

  test('record() does not churn (no-op) when nothing actually changed', () {
    final ProgressStore store = ProgressStore();
    final DateTime month = DateTime(2026, 4, 1);
    store.record(month, 50, <String, int>{'Reminders': 50});
    final int before = store.monthsTracked;
    store.record(month, 50, <String, int>{'Reminders': 50});
    expect(store.monthsTracked, before);
  });
}
