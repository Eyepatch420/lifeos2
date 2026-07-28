import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../../data/stores/persistence.dart';

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

  static String buildBackup() {
    final Map<String, dynamic> data = <String, dynamic>{};
    for (final String key in storeKeys) {
      final Map<String, dynamic>? blob = Persistence.load(key);
      if (blob != null) data[key] = blob;
    }
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'app': 'LifeOS',
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': data,
    });
  }

  static String suggestedFileName() {
    final DateTime now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'lifeos-backup-${now.year}-${two(now.month)}-${two(now.day)}.json';
  }

  /// Reads a backup file the user picks and writes its contents back into
  /// storage. Returns a human-readable result for the UI to show.
  ///
  /// Restore deliberately does NOT mutate the live stores — they are rebuilt
  /// from storage at startup, so the app must be relaunched afterwards. That
  /// keeps restore all-or-nothing instead of half-applied.
  static Future<RestoreResult> restoreFromFile() async {
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

      if (parsed['app'] != 'LifeOS') {
        return const RestoreResult.failed("That file isn't a LifeOS backup.");
      }
      final int version = parsed['formatVersion'] as int? ?? 0;
      if (version > formatVersion) {
        return const RestoreResult.failed(
            'That backup was made by a newer version of LifeOS.');
      }

      final Map<String, dynamic>? data =
          parsed['data'] as Map<String, dynamic>?;
      if (data == null || data.isEmpty) {
        return const RestoreResult.failed('That backup is empty.');
      }

      int restored = 0;
      for (final String key in storeKeys) {
        final Object? blob = data[key];
        if (blob is Map<String, dynamic>) {
          Persistence.save(key, blob);
          restored++;
        }
      }
      return RestoreResult.success(restored);
    } on FormatException {
      return const RestoreResult.failed('That file is not valid JSON.');
    } catch (e) {
      return RestoreResult.failed('Could not read that file: $e');
    }
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
