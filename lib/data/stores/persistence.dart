import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tiny JSON persistence helper shared by all stores.
///
/// Each store saves its whole state under one key. Loads happen once at
/// startup; a missing/corrupt payload falls back to the seed data.
class Persistence {
  const Persistence._();

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Drops the cached handle so the next [init] re-reads storage.
  ///
  /// Needed by tests (SharedPreferences.setMockInitialValues does not clear
  /// an already-cached instance, so state leaks between cases) and by any
  /// future "reset app data" action.
  @visibleForTesting
  static Future<void> reset() async {
    _prefs = null;
    await init();
  }

  static Map<String, dynamic>? load(String key) {
    final String? raw = _prefs?.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static void save(String key, Map<String, dynamic> data) {
    _prefs?.setString(key, jsonEncode(data));
  }
}
