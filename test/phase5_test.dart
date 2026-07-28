import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/data/stores/persistence.dart';
import 'package:lifeos/data/stores/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Persistence.reset();
  });

  group('the month-on-month delta is real, not recomputed', () {
    test('there is no comparison until history exists', () {
      final ProgressStore store = ProgressStore();
      // The old code always produced a number here by recomputing today's
      // figures with a past date, so the delta looked meaningful but wasn't.
      expect(store.previousMonthScore(DateTime(2026, 7, 28)), isNull);
    });

    test('last month is read back from what was actually recorded', () {
      final ProgressStore store = ProgressStore();
      store.record(DateTime(2026, 6, 10), 71);
      expect(store.previousMonthScore(DateTime(2026, 7, 28)), 71);
    });

    test('a score recorded in June is not confused with July', () {
      final ProgressStore store = ProgressStore();
      store.record(DateTime(2026, 6, 10), 71);
      store.record(DateTime(2026, 7, 5), 84);
      expect(store.scoreFor(DateTime(2026, 6, 1)), 71);
      expect(store.scoreFor(DateTime(2026, 7, 1)), 84);
      expect(store.previousMonthScore(DateTime(2026, 7, 20)), 71);
    });

    test('re-recording the same month overwrites rather than duplicates', () {
      final ProgressStore store = ProgressStore();
      store.record(DateTime(2026, 7, 1), 60);
      store.record(DateTime(2026, 7, 28), 65);
      expect(store.monthsTracked, 1);
      expect(store.scoreFor(DateTime(2026, 7, 15)), 65);
    });

    test('the December to January boundary rolls back a year', () {
      final ProgressStore store = ProgressStore();
      store.record(DateTime(2025, 12, 20), 55);
      expect(store.previousMonthScore(DateTime(2026, 1, 10)), 55);
    });

    test('snapshots survive a reload', () {
      ProgressStore()
        ..record(DateTime(2026, 6, 10), 71)
        ..flush();
      expect(ProgressStore().scoreFor(DateTime(2026, 6, 1)), 71);
    });

    test('history comes back oldest first', () {
      final ProgressStore store = ProgressStore();
      store.record(DateTime(2026, 7, 1), 84);
      store.record(DateTime(2026, 5, 1), 62);
      store.record(DateTime(2026, 6, 1), 71);
      expect(
        store.history.map(((String, int) e) => e.$2).toList(),
        <int>[62, 71, 84],
      );
    });
  });
}
