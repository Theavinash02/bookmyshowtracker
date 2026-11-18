import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Persistent storage. Uses [SharedPreferencesAsync] (no in-memory cache),
/// so the UI and the background service always see each other's writes.
class Storage {
  static final _p = SharedPreferencesAsync();

  static const _kConfig = 'config_v1';
  static const _kRunning = 'tracking_running';
  static const _kAlerted = 'alerted_keys';
  static const _kStatus = 'last_status';

  static Future<TrackerConfig> loadConfig() async {
    final s = await _p.getString(_kConfig);
    if (s == null) return defaultConfig();
    try {
      return TrackerConfig.fromJson(s);
    } catch (_) {
      return defaultConfig();
    }
  }

  static Future<void> saveConfig(TrackerConfig c) =>
      _p.setString(_kConfig, c.toJson());

  static Future<bool> isRunning() async =>
      (await _p.getBool(_kRunning)) ?? false;

  static Future<void> setRunning(bool v) => _p.setBool(_kRunning, v);

  static Future<Set<String>> alertedKeys() async =>
      ((await _p.getStringList(_kAlerted)) ?? []).toSet();

  static Future<void> addAlertedKeys(Iterable<String> keys) async {
    final s = await alertedKeys()..addAll(keys);
    await _p.setStringList(_kAlerted, s.toList());
  }

  static Future<void> clearAlerted() => _p.remove(_kAlerted);

  static const _kAlarmLog = 'alarm_log';

  /// Most recent alarms the tracker rang, newest first: `millis|text`.
  static Future<List<(DateTime, String)>> alarmLog() async {
    final raw = (await _p.getStringList(_kAlarmLog)) ?? [];
    return raw.map((e) {
      final i = e.indexOf('|');
      final t = int.tryParse(i > 0 ? e.substring(0, i) : '') ?? 0;
      return (DateTime.fromMillisecondsSinceEpoch(t), i > 0 ? e.substring(i + 1) : e);
    }).toList();
  }

  static Future<void> logAlarm(String text) async {
    final raw = (await _p.getStringList(_kAlarmLog)) ?? [];
    raw.insert(0, '${DateTime.now().millisecondsSinceEpoch}|$text');
    await _p.setStringList(_kAlarmLog, raw.take(20).toList());
  }

  /// Last background-check summary: {time, lines: [..], open: bool}.
  static Future<Map<String, dynamic>?> lastStatus() async {
    final s = await _p.getString(_kStatus);
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveStatus(Map<String, dynamic> status) =>
      _p.setString(_kStatus, jsonEncode(status));
}

/// A fresh install: no city, movies or theaters yet. The city comes from
/// the first movie link and theaters are loaded from BookMyShow.
TrackerConfig defaultConfig() => TrackerConfig(
      city: defaultCity,
      movies: [],
      theaters: [],
    );
