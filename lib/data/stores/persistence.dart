import 'dart:convert';

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
