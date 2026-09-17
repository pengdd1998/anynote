import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opt-in, local-only product analytics: event counters and operation
/// durations. No note content, identifiers, or timestamps beyond aggregate
/// totals ever leave this class, and nothing leaves the device at all.
///
/// Design constraints (tech plan, cross-sprint instrumentation):
/// - opt-in: every method is a no-op until [setOptIn] enables recording;
/// - counts + durations only: [count] and [duration]/[track] are the whole
///   vocabulary — there is deliberately no event-payload API;
/// - small: one JSON blob in SharedPreferences, written through on change.
class AnalyticsService {
  static const _optInKey = 'analytics_opt_in';
  static const _dataKey = 'analytics_data';

  /// Shared instance for non-Riverpod call sites (StateNotifiers etc.).
  /// The Riverpod [analyticsProvider] returns this same instance.
  static final AnalyticsService instance = AnalyticsService();

  bool _optIn = false;
  bool _loaded = false;
  final Map<String, int> _counts = {};
  // event -> [totalMs, count]
  final Map<String, List<int>> _durations = {};

  bool get optIn => _optIn;

  /// Loads persisted state. Safe to call multiple times. Every storage
  /// error is swallowed: analytics must never break a feature, so a
  /// missing/flaky plugin just means in-memory-only recording.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _optIn = prefs.getBool(_optInKey) ?? false;
      final raw = prefs.getString(_dataKey);
      if (raw != null) {
        try {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          final events = data['events'] as Map<String, dynamic>? ?? {};
          events.forEach((k, v) => _counts[k] = (v as num).toInt());
          final durs = data['durations'] as Map<String, dynamic>? ?? {};
          durs.forEach((k, v) {
            if (v is List && v.length == 2) {
              _durations[k] = [(v[0] as num).toInt(), (v[1] as num).toInt()];
            }
          });
        } catch (_) {
          // Corrupt blob: start fresh rather than crash.
        }
      }
    } catch (_) {
      // Storage unavailable: keep defaults, stay in memory.
    }
    _loaded = true;
  }

  /// Enables or disables recording. Collected aggregates are kept when
  /// disabling (the user can clear them explicitly via [reset]).
  Future<void> setOptIn(bool value) async {
    await load();
    _optIn = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_optInKey, value);
    } catch (_) {
      // In-memory only; recording still works for this session.
    }
  }

  /// Records one occurrence of [event]. No-op when not opted in.
  Future<void> count(String event) async {
    await load();
    if (!_optIn) return;
    _counts[event] = (_counts[event] ?? 0) + 1;
    await _persist();
  }

  /// Records one [event] execution of [ms] milliseconds.
  /// No-op when not opted in.
  Future<void> duration(String event, int ms) async {
    await load();
    if (!_optIn) return;
    final slot = _durations.putIfAbsent(event, () => [0, 0]);
    slot[0] += ms;
    slot[1] += 1;
    await _persist();
  }

  /// Times [body] and records it as [event]; returns the body's result.
  Future<T> track<T>(String event, Future<T> Function() body) async {
    final sw = Stopwatch()..start();
    try {
      return await body();
    } finally {
      sw.stop();
      await duration(event, sw.elapsedMilliseconds);
    }
  }

  /// Read-only view for UI: {events: {name: count}, durations: {name: {avgMs,
  /// totalMs, count}}, totalEvents: int}.
  Future<Map<String, dynamic>> snapshot() async {
    await load();
    var total = 0;
    _counts.forEach((_, c) => total += c);
    _durations.forEach((_, slot) => total += slot[1]);
    return {
      'events': Map<String, int>.of(_counts),
      'durations': _durations.map(
        (k, slot) => MapEntry(k, {
          'totalMs': slot[0],
          'count': slot[1],
          'avgMs': slot[1] == 0 ? 0.0 : slot[0] / slot[1],
        }),
      ),
      'totalEvents': total,
    };
  }

  /// Clears all collected aggregates (does not change the opt-in flag).
  Future<void> reset() async {
    await load();
    _counts.clear();
    _durations.clear();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _dataKey,
        jsonEncode({'events': _counts, 'durations': _durations}),
      );
    } catch (_) {
      // In-memory only this session; never surface storage errors.
    }
  }
}

final analyticsProvider = Provider<AnalyticsService>((ref) => AnalyticsService.instance);
