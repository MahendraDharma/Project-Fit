// What other devices put in the health store, ready for a screen: the label,
// unit and icon of each kind, and a per-day series that says, for every day,
// whose number it is.
//
// The rule every screen shows through this file: a day the band measured is
// the band's; a day it did not may show another device's reading, drawn
// differently and named. The two are never averaged.
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/day_label.dart';
import '../../data/db.dart';
import '../../health/health_readings_import.dart';
import '../../l10n/app_localizations.dart';

/// The order the kinds are listed in wherever they are listed.
const List<String> kReadingKindOrder = [
  kKindVo2,
  kKindSpo2,
  kKindHrvSdnn,
  kKindRhr,
  kKindResp,
  kKindSleepMin,
  kKindSleepDeep,
  kKindSleepRem,
  kKindStepsDay,
];

String readingLabel(String kind, AppLocalizations? l) => switch (kind) {
      kKindVo2 => l?.readingVo2 ?? 'VO₂ max',
      kKindSpo2 => l?.readingSpo2 ?? 'Blood oxygen',
      kKindHrvSdnn => l?.readingHrvSdnn ?? 'HRV (SDNN)',
      kKindRhr => l?.readingRhr ?? 'Resting heart rate',
      kKindResp => l?.readingResp ?? 'Breathing rate',
      kKindSleepMin => l?.readingSleep ?? 'Time asleep',
      kKindSleepDeep => l?.readingSleepDeep ?? 'Deep sleep',
      kKindSleepRem => l?.readingSleepRem ?? 'REM sleep',
      kKindStepsDay => l?.readingSteps ?? 'Steps',
      'body_battery' => l?.bbTitle ?? 'Body Battery',
      _ => kind,
    };

IconData readingIcon(String kind) => switch (kind) {
      kKindVo2 => LucideIcons.wind,
      kKindSpo2 => LucideIcons.droplet,
      kKindHrvSdnn => LucideIcons.activity,
      kKindRhr => LucideIcons.heart,
      kKindResp => LucideIcons.wind,
      kKindSleepMin || kKindSleepDeep || kKindSleepRem => LucideIcons.moon,
      kKindStepsDay => LucideIcons.footprints,
      'body_battery' => LucideIcons.batteryCharging,
      _ => LucideIcons.circle,
    };

String readingUnit(String kind) => switch (kind) {
      kKindVo2 => 'mL/kg/min',
      kKindSpo2 || 'body_battery' => '%',
      kKindHrvSdnn => 'ms',
      kKindRhr => 'bpm',
      kKindResp => 'rpm',
      _ => '',
    };

/// "41.0", "96", "7h 12m", "8,214".
String formatReading(String kind, double v) => switch (kind) {
      kKindVo2 || kKindResp => v.toStringAsFixed(1),
      kKindSleepMin || kKindSleepDeep || kKindSleepRem =>
        '${v ~/ 60}h ${(v % 60).round()}m',
      kKindStepsDay => v.round().toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ','),
      _ => v.round().toString(),
    };

/// One day of an imported kind: the value and the device that recorded it.
typedef ExternalDay = ({double value, String source});

/// Per-day imported values for [kind] over the [days] up to and including
/// [until]. Several readings in one day (SpO₂ spot checks) are averaged
/// WITHIN one source; across sources the one with the most readings wins,
/// and its name is the one shown. Never mixed with the band's own values.
Future<Map<String, ExternalDay>> loadExternalDays(String kind,
    {required String until, int days = 90}) async {
  final u = DateTime.parse(until);
  final end = DateTime(u.year, u.month, u.day + 1);
  final start = DateTime(u.year, u.month, u.day + 1 - days);
  final rows = await LocalDb.importedMeasurementsBetween(
      kind, start.millisecondsSinceEpoch ~/ 1000, end.millisecondsSinceEpoch ~/ 1000);
  return externalDaysFrom(rows);
}

/// The pure half of [loadExternalDays].
Map<String, ExternalDay> externalDaysFrom(List<Map<String, dynamic>> rows) {
  final acc = <String, Map<String, List<double>>>{};
  for (final r in rows) {
    final day = dayLabelOf(
        DateTime.fromMillisecondsSinceEpoch((r['ts'] as num).toInt() * 1000));
    acc
        .putIfAbsent(day, () => {})
        .putIfAbsent(r['source'] as String, () => [])
        .add((r['value'] as num).toDouble());
  }
  return {
    for (final MapEntry(key: day, value: bySrc) in acc.entries)
      day: () {
        final best = bySrc.entries
            .reduce((a, b) => b.value.length > a.value.length ? b : a);
        return (
          value: best.value.reduce((a, b) => a + b) / best.value.length,
          source: best.key,
        );
      }(),
  };
}

/// A point on a trend: the day, the value, and whose it is (null = the band).
typedef TrendPoint = ({String day, double value, String? source});

/// The band's days, with another device's reading filling only the days the
/// band has nothing for. Sorted by day.
List<TrendPoint> mergeWithExternal(
    Map<String, double> own, Map<String, ExternalDay> ext) {
  final out = <TrendPoint>[
    for (final e in own.entries) (day: e.key, value: e.value, source: null),
    for (final e in ext.entries)
      if (!own.containsKey(e.key))
        (day: e.key, value: e.value.value, source: e.value.source),
  ]..sort((a, b) => a.day.compareTo(b.day));
  return out;
}
