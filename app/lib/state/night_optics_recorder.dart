// Records the WHOOP 4.0's red/IR ratio through the night, unattended, for the
// SpO2 calibration against the Garmin watch (lib/ble/night_optics.dart).
//
// While it is on, every evening from [kNightStartHour] to [kNightEndHour] it
// owns the gen4 high-rate optical stream (LiveStreamOwners.nightOptics); each
// 30 s window is scored and appended to one file per night. No sleep
// detection is needed: falling asleep late only means the first hours score
// as moving windows, which the quality gate drops. It stops itself when the
// band's battery runs low.
//
// Checked on every engine state change rather than on a timer: a suspended
// iOS app runs no timers, but the band's prompts and battery polls still wake
// it, and the first of those after 21:00 starts the night.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ble/night_optics.dart';
import '../data/db.dart';

const String kNightOpticsPref = 'night_optics_enabled';
const int kNightStartHour = 21, kNightEndHour = 9;

/// Below this band battery the night stream is let go.
const int kNightOpticsMinBattery = 20;

/// Nights kept on disk.
const int kNightOpticsKeepNights = 60;

/// Whether [now] is inside the nightly window.
bool inNightWindow(DateTime now) =>
    now.hour >= kNightStartHour || now.hour < kNightEndHour;

/// The night a moment belongs to: the evening's date (02:00 on the 29th is
/// the night of the 28th).
String nightLabel(DateTime now) {
  final d = now.subtract(const Duration(hours: 12));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

class NightOpticsRecorder extends ChangeNotifier {
  NightOpticsRecorder({
    required this.gen4,
    required this.connected,
    required this.batteryPct,
    required this.nudge,
    DateTime Function()? now,
    Future<Directory> Function()? dir,
  })  : _now = now ?? DateTime.now,
        _dir = dir ?? _defaultDir;

  final bool Function() gen4, connected;
  final double? Function() batteryPct;

  /// Re-run the live-stream owners after [active] changed.
  final void Function() nudge;
  final DateTime Function() _now;
  final Future<Directory> Function() _dir;

  static Future<Directory> _defaultDir() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/night_optics');

  bool _enabled = true;
  bool _active = false;
  final OpticWindowAnalyzer _analyzer = OpticWindowAnalyzer();

  /// Tonight's counts, for the screen.
  int windows = 0, good = 0;
  String? _countsNight;

  bool get enabled => _enabled;

  /// Holding the optical stream right now.
  bool get active => _active;

  Future<void> start() async {
    try {
      _enabled = (await SharedPreferences.getInstance()).getBool(kNightOpticsPref) ?? true;
    } catch (_) {}
    evaluate();
  }

  Future<void> setEnabled(bool on) async {
    _enabled = on;
    try {
      await (await SharedPreferences.getInstance()).setBool(kNightOpticsPref, on);
    } catch (_) {}
    evaluate();
    notifyListeners();
  }

  /// Decide whether to hold the stream. Cheap and allocation-free: called on
  /// every engine state change (live HR ticks, battery polls, link changes,
  /// the band's own wake prompts), which is what runs while the phone sleeps.
  void evaluate() {
    final battery = batteryPct();
    final want = _enabled &&
        gen4() &&
        connected() &&
        inNightWindow(_now()) &&
        (battery == null || battery >= kNightOpticsMinBattery);
    if (want == _active) return;
    _active = want;
    _analyzer.reset();
    nudge();
    notifyListeners();
  }

  /// A live frame. Only gen4 R10 optics while [active] are used.
  void onFrame(int pt, String hex) {
    if (!_active || pt != 0x2B || hex.length < 4 || hex.substring(2, 4) != '0b') return;
    final Uint8List bytes;
    try {
      bytes = _hexBytes(hex);
    } catch (_) {
      return;
    }
    final block = parseOpticsFrame(bytes);
    if (block == null) return;
    final now = _now();
    final w = _analyzer.add(block, now.millisecondsSinceEpoch);
    if (w == null) return;
    final night = nightLabel(now);
    if (_countsNight != night) {
      _countsNight = night;
      windows = 0;
      good = 0;
    }
    windows++;
    if (w.ok) good++;
    unawaited(_append(night, w));
    notifyListeners();
  }

  Future<void> _append(String night, OpticWindow w) async {
    try {
      final d = await _dir();
      if (!d.existsSync()) d.createSync(recursive: true);
      await File('${d.path}/$night.jsonl')
          .writeAsString('${jsonEncode(w.toJson())}\n', mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('[night-optics] write: $e');
    }
  }

  /// Every stored window, oldest night first.
  Future<Map<String, List<OpticWindow>>> loadNights() async {
    final out = <String, List<OpticWindow>>{};
    try {
      final d = await _dir();
      if (!d.existsSync()) return out;
      final files = d.listSync().whereType<File>().where((f) => f.path.endsWith('.jsonl')).toList()
        ..sort((x, y) => x.path.compareTo(y.path));
      for (final f in files.skip(files.length > kNightOpticsKeepNights ? files.length - kNightOpticsKeepNights : 0)) {
        final name = f.uri.pathSegments.last.replaceAll('.jsonl', '');
        out[name] = [
          for (final line in await f.readAsLines())
            if (line.trim().isNotEmpty) ?_tryParse(line)
        ];
      }
      for (final f in files.take(files.length > kNightOpticsKeepNights ? files.length - kNightOpticsKeepNights : 0)) {
        f.deleteSync();
      }
    } catch (e) {
      debugPrint('[night-optics] read: $e');
    }
    return out;
  }

  static OpticWindow? _tryParse(String line) {
    try {
      return OpticWindow.fromJson(jsonDecode(line));
    } catch (_) {
      return null;
    }
  }

  /// The Garmin watch's SpO2 readings over the stored nights.
  static Future<List<({int atMs, double spo2})>> garminSpo2(int fromMs, int toMs) async {
    final rows = await LocalDb.vendorSeries('spo2', fromMs, toMs);
    return [
      for (final r in rows)
        if ('${r['attribution']}'.toLowerCase().contains('garmin') && r['value'] is num)
          (atMs: r['ts_ms'] as int, spo2: (r['value'] as num).toDouble())
    ];
  }
}

Uint8List _hexBytes(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(2 * i, 2 * i + 2), radix: 16);
  }
  return out;
}
