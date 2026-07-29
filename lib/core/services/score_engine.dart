import 'package:flutter/material.dart';

/// One module's contribution to the composite "My Progress" score.
///
/// Implementations wrap an existing store getter — the engine itself has no
/// opinion on where [value] comes from, so adding a new scored module is
/// "write one ScoreProvider", not "touch the formula".
abstract class ScoreProvider {
  String get moduleKey;
  String get label;
  IconData get icon;
  Color get color;

  /// 0..1 adherence for the current period.
  double get value;

  /// Relative weight in the composite. Weights of modules excluded via
  /// [hasData] are dropped from the denominator, not counted as zero.
  double get weight;

  /// Whether this module has any data at all yet.
  bool get hasData;
}

class ScoreResult {
  const ScoreResult(this.score, this.moduleValues);

  /// 0..100 composite.
  final int score;

  /// moduleKey → 0..100, for every module that had data.
  final Map<String, int> moduleValues;
}

/// Computes the weighted-average composite score used by My Progress.
///
/// This is the same formula the screen used to compute inline — moved here
/// verbatim so it has a single, testable home instead of living in a widget.
class ScoreEngine {
  const ScoreEngine._();

  static ScoreResult compute(List<ScoreProvider> providers) {
    final List<ScoreProvider> withData =
        providers.where((ScoreProvider p) => p.hasData).toList();
    final double totalWeight =
        withData.fold<double>(0, (double s, ScoreProvider p) => s + p.weight);
    final int score = totalWeight == 0
        ? 0
        : (withData.fold<double>(
                    0, (double s, ScoreProvider p) => s + p.value * p.weight) /
                totalWeight *
                100)
            .round();
    final Map<String, int> moduleValues = <String, int>{
      for (final ScoreProvider p in withData)
        p.moduleKey: (p.value * 100).round(),
    };
    return ScoreResult(score, moduleValues);
  }
}
