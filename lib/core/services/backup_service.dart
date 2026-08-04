import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/stores/persistence.dart';

enum RestoreMode { overwrite, merge }

/// Exposes [BackupService]'s otherwise-private validation/merge logic for
/// unit testing without going through the file-picker UI flow.
@visibleForTesting
class BackupServiceTestHooks {
  const BackupServiceTestHooks._();

  static String? validate(Map<String, dynamic> parsed) =>
      BackupService._validate(parsed);

  static Map<String, dynamic> merge(
    String key,
    Map<String, dynamic>? current,
    Map<String, dynamic> incoming,
  ) =>
      BackupService._merge(key, current, incoming);
}

/// Full-app backup and restore (PRD 10.1).
///
/// Every store already persists itself as one JSON blob, so a backup is just
/// those blobs in a versioned envelope. Restore writes them back and the app
/// reloads on next launch.
class BackupService {
  const BackupService._();

  /// Bump when the on-disk shape changes so old files can be rejected.
  static const int formatVersion = 1;

  /// Keys written by the stores — must stay in sync with their `_key`s.
  static const List<String> storeKeys = <String>[
    'settings',
    'reminders',
    'planner',
    'alarms',
    'expenses',
    'health',
    'commitments',
    'lists_notes',
    'progress_snapshots',
  ];

  /// The blob fields, per store key, that are `List<Map>` of records with a
  /// stable `id` — these are what merge-restore unions by id. Any field not
  /// listed here (settings, water config/log, month-keyed maps, etc.) simply
  /// takes the incoming value wholesale during a merge, same as overwrite.
  static const Map<String, List<String>> _mergeableArrayFields =
      <String, List<String>>{
    'reminders': <String>['reminders'],
    'planner': <String>['habits', 'events'],
    'alarms': <String>['alarms'],
    'expenses': <String>['txns', 'categories'],
    'health': <String>['reports', 'vitals', 'wellness'],
    'commitments': <String>['memberships', 'bills', 'documents'],
    'lists_notes': <String>['lists', 'notes'],
  };

  static Future<String> buildBackup() async {
    final Map<String, dynamic> data = <String, dynamic>{};
    for (final String key in storeKeys) {
      final Map<String, dynamic>? blob = Persistence.load(key);
      if (blob != null) data[key] = blob;
    }
    String appVersion = 'unknown';
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      // Platform channel unavailable (e.g. some test harnesses) — non-fatal,
      // the backup is still valid without it.
    }
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'app': 'DigiDaily',
      'formatVersion': formatVersion,
      'appVersion': appVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': data,
    });
  }

  static String suggestedFileName() {
    final DateTime now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'digidaily-backup-${now.year}-${two(now.month)}-${two(now.day)}.json';
  }

  /// Validates a parsed backup envelope's structure without writing anything.
  /// Returns an error message, or null if the envelope is well-formed enough
  /// to restore from.
  static String? _validate(Map<String, dynamic> parsed) {
    if (parsed['app'] != 'DigiDaily' &&
        parsed['app'] != 'DigiLife' &&
        parsed['app'] != 'LifeOS') {
      return "That file isn't a DigiDaily backup.";
    }
    final int version = parsed['formatVersion'] as int? ?? 0;
    if (version > formatVersion) {
      return 'That backup was made by a newer version of DigiDaily.';
    }
    final Object? data = parsed['data'];
    if (data is! Map<String, dynamic> || data.isEmpty) {
      return 'That backup is empty.';
    }
    // Per-key structural check: every recognised key must itself be a map,
    // and any declared mergeable array field inside it must actually be a
    // list — catches truncated/hand-edited files before anything is written.
    for (final MapEntry<String, dynamic> e in data.entries) {
      if (!storeKeys.contains(e.key)) continue; // ignore unknown future keys
      if (e.value is! Map<String, dynamic>) {
        return 'Module "${e.key}" in that backup is corrupted.';
      }
      final Map<String, dynamic> blob = e.value as Map<String, dynamic>;
      for (final String field
          in _mergeableArrayFields[e.key] ?? const <String>[]) {
        if (blob.containsKey(field) && blob[field] is! List) {
          return 'Module "${e.key}" in that backup is corrupted.';
        }
      }
    }
    return null;
  }

  /// Reads a backup file the user picks and writes its contents back into
  /// storage. Returns a human-readable result for the UI to show.
  ///
  /// Restore deliberately does NOT mutate the live stores — they are rebuilt
  /// from storage at startup, so the app must be relaunched afterwards. That
  /// keeps restore all-or-nothing instead of half-applied.
  ///
  /// [mode] is [RestoreMode.overwrite] (replace each store's data wholesale,
  /// the original and still-default behaviour) or [RestoreMode.merge] (union
  /// list-of-record fields by id, incoming wins on conflict; everything else
  /// takes the incoming value same as overwrite).
  static Future<RestoreResult> restoreFromFile(
      {RestoreMode mode = RestoreMode.overwrite}) async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['json'],
    );
    final String? path = picked?.files.single.path;
    if (path == null) return const RestoreResult.cancelled();

    try {
      final String raw = await File(path).readAsString();
      final Map<String, dynamic> parsed =
          jsonDecode(raw) as Map<String, dynamic>;

      final String? error = _validate(parsed);
      if (error != null) return RestoreResult.failed(error);

      final Map<String, dynamic> data = parsed['data'] as Map<String, dynamic>;

      int restored = 0;
      for (final String key in storeKeys) {
        final Object? blob = data[key];
        if (blob is! Map<String, dynamic>) continue;
        final Map<String, dynamic> toSave = mode == RestoreMode.merge
            ? _merge(key, Persistence.load(key), blob)
            : blob;
        Persistence.save(key, toSave);
        restored++;
      }
      return RestoreResult.success(restored);
    } on FormatException {
      return const RestoreResult.failed('That file is not valid JSON.');
    } catch (e) {
      return RestoreResult.failed('Could not read that file: $e');
    }
  }

  /// Unions [current] and [incoming] for one store's blob: every declared
  /// array-of-records field is merged by `id` (incoming wins on conflict);
  /// any other field takes the incoming value wholesale (or falls back to
  /// current if incoming didn't include it).
  static Map<String, dynamic> _merge(
    String key,
    Map<String, dynamic>? current,
    Map<String, dynamic> incoming,
  ) {
    if (current == null) return incoming;
    final Map<String, dynamic> merged = <String, dynamic>{
      ...current,
      ...incoming
    };
    for (final String field in _mergeableArrayFields[key] ?? const <String>[]) {
      final List<dynamic> a = (current[field] as List<dynamic>?) ?? <dynamic>[];
      final List<dynamic> b =
          (incoming[field] as List<dynamic>?) ?? <dynamic>[];
      final Map<String, dynamic> byId = <String, dynamic>{};
      for (final dynamic item in a) {
        if (item is Map<String, dynamic> && item['id'] is String) {
          byId[item['id'] as String] = item;
        }
      }
      for (final dynamic item in b) {
        if (item is Map<String, dynamic> && item['id'] is String) {
          byId[item['id'] as String] = item; // incoming wins
        }
      }
      merged[field] = byId.values.toList();
    }
    return merged;
  }
}

class RestoreResult {
  const RestoreResult.success(this.sectionsRestored)
      : cancelled = false,
        error = null;
  const RestoreResult.failed(this.error)
      : cancelled = false,
        sectionsRestored = 0;
  const RestoreResult.cancelled()
      : cancelled = true,
        sectionsRestored = 0,
        error = null;

  final int sectionsRestored;
  final String? error;
  final bool cancelled;

  bool get isSuccess => !cancelled && error == null;
}
