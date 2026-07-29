import 'package:flutter/foundation.dart';

/// One migration step for a store: given the blob at [fromVersion], return
/// the blob shaped for [fromVersion] + 1.
typedef Migration = Map<String, dynamic> Function(Map<String, dynamic> blob);

/// Applies a store's registered migrations in order so on-disk data written
/// by an older app version keeps loading correctly instead of falling back
/// to seed data every time the shape changes.
///
/// Registration is per store key; a store with no migrations registered is
/// simply returned as-is (new stores don't need to opt in to anything).
class MigrationRunner {
  const MigrationRunner._();

  static final Map<String, Map<int, Migration>> _migrations =
      <String, Map<int, Migration>>{};

  /// Registers the migration that turns a [key] blob at [fromVersion] into
  /// one at `fromVersion + 1`.
  static void register(String key, int fromVersion, Migration migration) {
    (_migrations[key] ??= <int, Migration>{})[fromVersion] = migration;
  }

  @visibleForTesting
  static void clearForTest() => _migrations.clear();

  /// Runs every registered migration for [key] starting at the version
  /// stored in [raw]'s `_v` field (missing means version 1, i.e. pre-versioning
  /// data) up to [currentVersion].
  ///
  /// A failing step logs and returns [seedFallback] instead of throwing, so a
  /// corrupted or unexpectedly-shaped blob can never crash startup.
  static Map<String, dynamic> run(
    String key,
    Map<String, dynamic> raw, {
    required int currentVersion,
    required Map<String, dynamic> Function() seedFallback,
  }) {
    try {
      Map<String, dynamic> blob = raw;
      int version = raw['_v'] as int? ?? 1;
      final Map<int, Migration> steps =
          _migrations[key] ?? const <int, Migration>{};
      while (version < currentVersion) {
        final Migration? step = steps[version];
        if (step == null) break; // no further migration registered — stop here
        blob = step(blob);
        version++;
      }
      return blob;
    } catch (_) {
      return seedFallback();
    }
  }
}
