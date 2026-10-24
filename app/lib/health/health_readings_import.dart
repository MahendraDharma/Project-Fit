// Read the vitals other devices already put in the phone's health store —
// a Garmin through Garmin Connect, an Apple Watch, a scale — so a day the band
// did not see, or a number the band cannot take (SpO₂ and VO₂ max on WHOOP
// 4.0), still shows up, with the device that took it named on it.
//
// The same contract as health_measurement_import.dart, and the rows land in
// the same table for that reason:
//   * DISPLAY ONLY. Nothing here is an input to readiness, strain, sleep
//     scoring or any baseline. Another device's HRV is SDNN on Apple and on
//     its own scale everywhere; folding it into ours would make a score look
//     complete and be wrong.
//   * NEVER BLENDED. A day shows our number when the band measured it and the
//     imported one only when it did not, and the imported one always carries
//     its source.
//   * NEVER OUR OWN. With health sync on, this app writes RHR, HRV, breathing
//     rate, steps and sleep to the same store. Those come back here with our
//     bundle id and are skipped, or the band would be shown as "from Health".
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/day_label.dart';
import '../data/db.dart';
import 'health_rhr_seed.dart' show isOwnHealthSample;
import 'health_workout_import.dart' show kHealthRoutesChannel;

/// `imported_measurement.kind` keys this file writes. Contract, like the
/// measurement kinds: renaming one orphans every stored row.
const String kKindSpo2 = 'spo2';
const String kKindHrvSdnn = 'hrv_sdnn';
const String kKindRhr = 'rhr_ext';
const String kKindResp = 'resp_ext';
const String kKindVo2 = 'vo2max';
const String kKindStepsDay = 'steps_day';
const String kKindSleepMin = 'sleep_asleep_min';
const String kKindSleepDeep = 'sleep_deep_min';
const String kKindSleepRem = 'sleep_rem_min';

const Map<HealthDataType, String> kReadingKinds = {
  HealthDataType.BLOOD_OXYGEN: kKindSpo2,
  HealthDataType.HEART_RATE_VARIABILITY_SDNN: kKindHrvSdnn,
  HealthDataType.RESTING_HEART_RATE: kKindRhr,
  HealthDataType.RESPIRATORY_RATE: kKindResp,
};

const List<HealthDataType> _sleepTypes = [
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.SLEEP_LIGHT,
  HealthDataType.SLEEP_DEEP,
  HealthDataType.SLEEP_REM,
];

/// Plausibility bounds per kind. Outside them a reading is dropped, never
/// clamped (see kImportedBounds for why).
const Map<String, (double, double)> kReadingBounds = {
  kKindSpo2: (70, 100),
  kKindHrvSdnn: (3, 300),
  kKindRhr: (25, 130),
  kKindResp: (4, 40),
  kKindVo2: (10, 95),
  kKindStepsDay: (1, 150000),
};

bool _inBounds(String kind, double v) {
  final b = kReadingBounds[kind];
  return b == null || (v >= b.$1 && v <= b.$2);
}

String _source(String name) => name.trim().isEmpty ? 'Unknown app' : name.trim();

/// Point readings (SpO₂, SDNN, RHR, breathing rate) → rows. Pure.
@visibleForTesting
List<Map<String, Object?>> readingRowsFrom(List<HealthDataPoint> points, String ownId) {
  final out = <Map<String, Object?>>[];
  final seen = <String>{};
  for (final p in points) {
    final kind = kReadingKinds[p.type];
    if (kind == null || p.uuid.isEmpty) continue;
    if (isOwnHealthSample(p.sourceId, p.sourceName, ownId)) continue;
    final v = p.value;
    if (v is! NumericHealthValue) continue;
    var value = v.numericValue.toDouble();
    // HealthKit hands oxygen saturation over as a fraction (0.97).
    if (kind == kKindSpo2 && value <= 1.0) value *= 100;
    if (!_inBounds(kind, value) || !seen.add(p.uuid)) continue;
    out.add({
      'uuid': p.uuid,
      'ts': p.dateTo.millisecondsSinceEpoch ~/ 1000,
      'kind': kind,
      'value': value,
      'unit': p.unit.name,
      'source': _source(p.sourceName),
    });
  }
  return out;
}

/// Step samples → one row per (day, source). Sources are kept apart, never
/// added together: a phone and a watch both counting the same walk would
/// otherwise double it. Pure.
@visibleForTesting
List<Map<String, Object?>> stepRowsFrom(List<HealthDataPoint> points, String ownId) {
  final sums = <(String, String), double>{};
  for (final p in points) {
    if (p.type != HealthDataType.STEPS) continue;
    if (isOwnHealthSample(p.sourceId, p.sourceName, ownId)) continue;
    final v = p.value;
    if (v is! NumericHealthValue) continue;
    final key = (dayLabelOf(p.dateFrom.toLocal()), _source(p.sourceName));
    sums[key] = (sums[key] ?? 0) + v.numericValue.toDouble();
  }
  return [
    for (final e in sums.entries)
      if (_inBounds(kKindStepsDay, e.value))
        {
          'uuid': 'agg:$kKindStepsDay:${e.key.$1}:${e.key.$2}',
          'ts': _noonOf(e.key.$1),
          'kind': kKindStepsDay,
          'value': e.value.roundToDouble(),
          'unit': 'COUNT',
          'source': e.key.$2,
        },
  ];
}

int _noonOf(String day) {
  final d = DateTime.parse(day);
  return DateTime(d.year, d.month, d.day, 12).millisecondsSinceEpoch ~/ 1000;
}

/// Sleep segments → per night and source: minutes asleep, deep and REM. A
/// night is a run of one source's segments with no gap over two hours, dated
/// by the day it ends on. Staged minutes win over an unstaged "asleep" total
/// for the same night, so a source writing both is not counted twice. Pure.
@visibleForTesting
List<Map<String, Object?>> sleepRowsFrom(List<HealthDataPoint> points, String ownId) {
  final bySource = <String, List<HealthDataPoint>>{};
  for (final p in points) {
    if (!_sleepTypes.contains(p.type)) continue;
    if (isOwnHealthSample(p.sourceId, p.sourceName, ownId)) continue;
    bySource.putIfAbsent(_source(p.sourceName), () => []).add(p);
  }
  final out = <Map<String, Object?>>[];
  for (final MapEntry(key: src, value: segs) in bySource.entries) {
    segs.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    var night = <HealthDataPoint>[];
    DateTime? lastEnd;
    void close() {
      if (night.isEmpty) return;
      double mins(Iterable<HealthDataPoint> xs) =>
          xs.fold(0.0, (a, p) => a + p.dateTo.difference(p.dateFrom).inSeconds / 60);
      final staged = night.where((p) => p.type != HealthDataType.SLEEP_ASLEEP);
      final asleep = staged.isNotEmpty
          ? mins(staged)
          : mins(night.where((p) => p.type == HealthDataType.SLEEP_ASLEEP));
      final end = night.map((p) => p.dateTo).reduce((a, b) => a.isAfter(b) ? a : b);
      final day = dayLabelOf(end.toLocal());
      final ts = end.millisecondsSinceEpoch ~/ 1000;
      // A nap or a stray minute is not a night.
      if (asleep >= 90) {
        for (final (kind, v) in [
          (kKindSleepMin, asleep),
          if (staged.isNotEmpty) (kKindSleepDeep, mins(night.where((p) => p.type == HealthDataType.SLEEP_DEEP))),
          if (staged.isNotEmpty) (kKindSleepRem, mins(night.where((p) => p.type == HealthDataType.SLEEP_REM))),
        ]) {
          out.add({
            'uuid': 'agg:$kind:$day:$src',
            'ts': ts,
            'kind': kind,
            'value': v.roundToDouble(),
            'unit': 'MINUTE',
            'source': src,
          });
        }
      }
      night = [];
    }

    for (final p in segs) {
      if (lastEnd != null && p.dateFrom.difference(lastEnd).inMinutes > 120) close();
      night.add(p);
      lastEnd = lastEnd == null || p.dateTo.isAfter(lastEnd) ? p.dateTo : lastEnd;
    }
    close();
  }
  return out;
}

/// VO₂ max samples from the native bridge → rows. Pure.
@visibleForTesting
List<Map<String, Object?>> vo2RowsFrom(List<Object?> raw, String ownId) {
  final out = <Map<String, Object?>>[];
  for (final r in raw) {
    if (r is! Map) continue;
    final uuid = r['uuid'] as String? ?? '';
    final v = (r['value'] as num?)?.toDouble();
    final ms = (r['ts'] as num?)?.toInt();
    if (uuid.isEmpty || v == null || ms == null || !_inBounds(kKindVo2, v)) continue;
    if (isOwnHealthSample(r['sourceId'] as String? ?? '', r['source'] as String? ?? '', ownId)) continue;
    out.add({
      'uuid': uuid,
      'ts': ms ~/ 1000,
      'kind': kKindVo2,
      'value': v,
      'unit': 'ML_KG_MIN',
      'source': _source(r['source'] as String? ?? ''),
    });
  }
  return out;
}

const String kHealthReadingsAsked = 'health_readings_asked';
const String kHealthReadingsLastMs = 'health_readings_last_ms';
const Duration kHealthReadingsInterval = Duration(hours: 1);

class HealthReadingsImporter {
  HealthReadingsImporter({Health? health, bool? isApple})
      : _health = health ?? Health(),
        _isApple = isApple ?? (Platform.isIOS || Platform.isMacOS);

  final Health _health;
  final bool _isApple;

  static final List<HealthDataType> types = [
    ...kReadingKinds.keys,
    HealthDataType.STEPS,
    ..._sleepTypes,
  ];

  /// READ only, asked on the user's tap. VO₂ max is asked for by the native
  /// bridge in the same tap (the plugin has no VO₂ max type).
  Future<bool> requestPermission() async {
    try {
      await _health.configure();
      final perms = [for (final _ in types) HealthDataAccess.READ];
      final ok = await _health.hasPermissions(types, permissions: perms) == true ||
          await _health.requestAuthorization(types, permissions: perms);
      await (await SharedPreferences.getInstance()).setBool(kHealthReadingsAsked, true);
      return ok;
    } catch (e) {
      debugPrint('[health_readings] permission: $e');
      return false;
    }
  }

  /// Read the window and store it. [prompt] is true only on a tap: a
  /// background pass never raises a permission sheet. Returns rows stored.
  Future<int> sync({DateTime? now, bool prompt = false}) async {
    final end = now ?? DateTime.now();
    final start = _isApple
        ? DateTime(end.year, end.month - 6, end.day)
        : end.subtract(const Duration(days: 30));
    String ownId;
    try {
      ownId = (await PackageInfo.fromPlatform()).packageName;
    } catch (e) {
      // Without our own id our own exports would come back as "from Health".
      debugPrint('[health_readings] package info: $e');
      return 0;
    }
    final rows = <Map<String, Object?>>[];
    try {
      await _health.configure();
      final points = await _health.getHealthDataFromTypes(
          types: types, startTime: start, endTime: end);
      rows
        ..addAll(readingRowsFrom(points, ownId))
        ..addAll(stepRowsFrom(points, ownId))
        ..addAll(sleepRowsFrom(points, ownId));
    } catch (e) {
      debugPrint('[health_readings] read: $e');
    }
    if (_isApple) {
      try {
        final raw = await kHealthRoutesChannel.invokeMethod<List<Object?>>('vo2max', {
          'fromMs': DateTime(end.year - 2, end.month, end.day).millisecondsSinceEpoch,
          'toMs': end.millisecondsSinceEpoch,
          'prompt': prompt,
        });
        rows.addAll(vo2RowsFrom(raw ?? const [], ownId));
      } on PlatformException catch (e) {
        debugPrint('[health_readings] vo2max: $e');
      } on MissingPluginException {
        // Tests and platforms without the bridge.
      }
    }
    final n = await LocalDb.putImportedMeasurements(rows);
    await (await SharedPreferences.getInstance())
        .setInt(kHealthReadingsLastMs, end.millisecondsSinceEpoch);
    return n;
  }

  /// The foreground pass: only once the user has said yes on a tap, at most
  /// hourly, never prompting, never throwing.
  static Future<void> maybeRun({HealthReadingsImporter? importer, DateTime? now}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(kHealthReadingsAsked) != true) return;
      final t = now ?? DateTime.now();
      final last = prefs.getInt(kHealthReadingsLastMs);
      if (last != null &&
          t.difference(DateTime.fromMillisecondsSinceEpoch(last)) < kHealthReadingsInterval) {
        return;
      }
      await (importer ?? HealthReadingsImporter()).sync(now: t);
    } catch (e) {
      debugPrint('[health_readings] auto: $e');
    }
  }
}
