// HOME VITALS — the data-dense half of Home: the four vitals under the rings,
// the day's heart rate with its zones, last night in one card, the health
// monitor and the dashboard rows.
//
// Everything here is read, not computed: each figure is a field the derivation
// already stored for the day (getDayHeart / getDayStrain / getDayStress /
// getDaySleep / getInsights), or the stored daily series it comes from. A
// field the day does not have is left out of its card, and a card with nothing
// in it is not drawn — never a zero, never a dash standing in for a number.
//
// The health monitor's dots are the one judgement on this screen, and they are
// the illness watch's own: grey while its baseline is still filling (with the
// watch's own have/need count), its state colour once it has one. They are
// never a per-metric "normal" this file decided.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/local_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../state/clock_format.dart' show formatClockMinute, formatClockOf;
import '../charts.dart';
import '../grammar.dart';
import '../theme.dart';
import 'home_screen.dart' show ChartPoint, hm, pointsOf, thousands;
import 'metric_detail.dart' show specOf;
import 'sleep_detail.dart' show SleepData;

/// One dashboard row's figures: the day's value and the mean of the days
/// before it in the stored series (null when there were none).
typedef DashFigure = ({double? today, double? before});

class HomeVitals {
  final double? hrv, rhr, resp, stress, skinTempZ;
  final int? hrAvg, hrMin, hrMax;

  /// The day's heart rate as stored (`getDayHeart.hr`), timestamps intact.
  final List<ChartPoint> hr;

  /// Minutes per zone, z1…z5, and the zones' lower edges in bpm.
  final List<double> zoneMin;
  final List<num>? zoneLower;

  /// Last night: the stage samples and its figures.
  final List<SleepStage?> stages;
  final int? onsetTs, wakeTs;
  final double? sleepMin, efficiency, deepMin, remMin, needMin, debtMin;
  final int? cycles;
  final double? regularity;

  /// The illness watch: its state, and its baseline count while filling.
  final String? watchState;
  final int? watchHave, watchNeed;

  /// Tonight's plan from the sleep coach: lights out and wake, minutes of day.
  final double? bedtimeMin, wakeMin;

  /// Nights with a scored sleep in the stored series, up to and including
  /// this day — a count, not a judgement.
  final int? nightsRecorded;

  /// Recovery's own baseline gate while it is still filling (the readiness
  /// glass box's need_baseline note), else null.
  final int? recoveryHave, recoveryNeed;

  /// key → today / before, for the dashboard rows.
  final Map<String, DashFigure> dash;

  /// Midnight of the day, unix seconds — the heart chart's left edge.
  final int dayStart;

  const HomeVitals({
    this.hrv,
    this.rhr,
    this.resp,
    this.stress,
    this.skinTempZ,
    this.hrAvg,
    this.hrMin,
    this.hrMax,
    this.hr = const [],
    this.zoneMin = const [],
    this.zoneLower,
    this.stages = const [],
    this.onsetTs,
    this.wakeTs,
    this.sleepMin,
    this.efficiency,
    this.deepMin,
    this.remMin,
    this.needMin,
    this.debtMin,
    this.cycles,
    this.regularity,
    this.watchState,
    this.watchHave,
    this.watchNeed,
    this.dash = const {},
    this.dayStart = 0,
    this.bedtimeMin,
    this.wakeMin,
    this.nightsRecorded,
    this.recoveryHave,
    this.recoveryNeed,
  });

  bool get hasVitals => hrv != null || rhr != null || resp != null || stress != null;
  bool get hasHeart => hr.length >= 2;
  bool get hasNight => sleepMin != null;
  bool get hasMonitor => hrv != null || rhr != null || resp != null || skinTempZ != null;

  /// The dashboard rows, in this order: HRV, resting HR, steps, breathing,
  /// calories. Spec keys, so names and units come from the metric specs.
  static const dashKeys = ['hrv', 'resting_hr', 'steps', 'resp_rate', 'calories'];

  static double? _n(Object? v) => v is num ? v.toDouble() : null;
  static int? _i(Object? v) => v is num ? v.round() : null;

  static Future<HomeVitals> load(LocalRepository repo, String date) async {
    final heart = await repo.getDayHeart(date);
    final strain = await repo.getDayStrain(date);
    final stress = await repo.getDayStress(date);
    final night = await repo.getDaySleep(date);
    final insights = await repo.getInsights();

    final hrv = heart['hrv'];
    final resp = heart['resp'];
    final skin = heart['skin_temp'];
    final st = stress['stress'];
    final hrStats = strain['hr'];
    final zones = strain['zones'];
    final illness = heart['illness'];
    final watchNote = illness is Map ? illness['note']?.toString() : null;
    final counts = RegExp(r'need_baseline:have=(\d+),need=(\d+)')
        .firstMatch(watchNote ?? '');
    final coach = insights['sleep_coach'];
    double? coachVal(String part, String key) {
      final m = coach is Map ? coach[part] : null;
      final v = m is Map ? m['value'] : null;
      return v is Map ? _n(v[key]) : null;
    }
    final glass = insights['readiness_glassbox'];
    final rCounts = RegExp(r'need_baseline:have=(\d+),need=(\d+)')
        .firstMatch(glass is Map ? glass['note']?.toString() ?? '' : '');
    final reg = insights['regularity'];
    final regVal = reg is Map ? reg['value'] : null;

    final dash = <String, DashFigure>{};
    for (final key in dashKeys) {
      final pts = pointsOf(await repo.getChart(specOf(key).chartKey));
      final d = DateTime.parse(date);
      final dayT = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 1000;
      double? today;
      final before = <double>[];
      for (final pt in pts) {
        if (pt.t >= dayT && pt.t < dayT + 86400) {
          today = pt.v;
        } else if (pt.t < dayT && pt.t >= dayT - 30 * 86400) {
          before.add(pt.v);
        }
      }
      if (today != null) {
        dash[key] = (
          today: today,
          before: before.isEmpty ? null : before.reduce((a, b) => a + b) / before.length,
        );
      }
    }

    final d = DateTime.parse(date);
    final nightOk = night['has_sleep'] == true;
    final dayEnd = DateTime(d.year, d.month, d.day + 1).millisecondsSinceEpoch ~/ 1000;
    final nights = pointsOf(await repo.getChart(specOf('sleep').chartKey))
        .where((pt) => pt.t < dayEnd && pt.v > 0)
        .length;
    return HomeVitals(
      hrv: _n(hrv is Map ? hrv['rmssd'] : null),
      rhr: _n(heart['resting_hr']),
      resp: _n(resp is Map ? resp['value'] : null),
      stress: _n(st is Map ? st['score'] : null),
      skinTempZ: _n(skin is Map ? skin['value'] : null),
      hrAvg: _i(hrStats is Map ? hrStats['avg'] : null),
      hrMin: _i(hrStats is Map ? hrStats['min'] : null),
      hrMax: _i(hrStats is Map ? hrStats['max'] : null),
      hr: pointsOf({'points': heart['hr']}),
      zoneMin: zones is Map
          ? [for (var i = 1; i <= 5; i++) _n(zones['z$i']) ?? 0]
          : const [],
      zoneLower: (strain['zone_lower_bpm'] as List?)?.cast<num>(),
      stages: nightOk ? SleepData.stagesOf(night.cast<String, Object?>()) : const [],
      onsetTs: nightOk ? _i(night['onset_ts']) : null,
      wakeTs: nightOk ? _i(night['wake_ts']) : null,
      sleepMin: nightOk ? _n(night['duration_min']) : null,
      efficiency: nightOk ? _n(night['efficiency']) : null,
      deepMin: nightOk ? _n(night['deep_min']) : null,
      remMin: nightOk ? _n(night['rem_min']) : null,
      needMin: nightOk ? _n(night['need_min']) : null,
      debtMin: nightOk ? _n(night['debt_min']) : null,
      cycles: nightOk ? _i(night['cycle_count']) : null,
      regularity: regVal is Map ? _n(regVal['sri']) : null,
      watchState: counts == null && illness is Map ? illness['state']?.toString() : null,
      watchHave: counts == null ? null : int.parse(counts.group(1)!),
      watchNeed: counts == null ? null : int.parse(counts.group(2)!),
      dash: dash,
      dayStart: DateTime(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 1000,
      bedtimeMin: coachVal('bedtime', 'bedtime_min_of_day'),
      wakeMin: coachVal('wake', 'wake_min_of_day'),
      nightsRecorded: nights,
      recoveryHave: rCounts == null ? null : int.parse(rCounts.group(1)!),
      recoveryNeed: rCounts == null ? null : int.parse(rCounts.group(2)!),
    );
  }
}

// ── shared bits ─────────────────────────────────────────────────────────────

/// A card heading in the dashboard voice: tracked capitals, a chevron when the
/// card opens something.
class _CardHead extends StatelessWidget {
  final String title;
  final bool chevron;
  const _CardHead(this.title, {this.chevron = false});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return Row(children: [
      Expanded(child: Text(title.toUpperCase(), style: F.label.copyWith(color: p.ink))),
      if (chevron) Icon(LucideIcons.chevronRight, size: 18, color: p.ink3),
    ]);
  }
}

/// Lays [cells] out [perRow] to a row (half that at large text), each cell an
/// equal share of the width.
Widget _grid(BuildContext c, List<Widget> cells, {int perRow = 4}) {
  final n = bigText(c) ? math.max(1, perRow ~/ 2) : perRow;
  return Column(children: [
    for (var i = 0; i < cells.length; i += n) ...[
      if (i > 0) const SizedBox(height: S.x4),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var j = i; j < i + n; j++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: j < i + n - 1 ? S.x2 : 0),
              child: j < cells.length ? cells[j] : const SizedBox(),
            ),
          ),
      ]),
    ],
  ]);
}

Widget _stat(BuildContext c, String value, String label, {Color? color}) {
  final p = P.of(c);
  // Scaled down rather than wrapped: "11h 00m" or a long label in a quarter
  // of a card is one line or nothing, never a word broken across two.
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(value, style: F.n24.copyWith(color: color ?? p.ink)),
    ),
    const SizedBox(height: S.x1),
    FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(label.toUpperCase(), style: F.labelSm.copyWith(color: p.ink3)),
    ),
  ]);
}

// ── vitals under the rings ──────────────────────────────────────────────────

/// HRV, resting heart rate, breathing and resting stress for the day, each as
/// a chip. A vital the day has none of is not drawn.
class VitalChips extends StatelessWidget {
  final HomeVitals v;
  const VitalChips(this.v, {super.key});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final chips = [
      if (v.hrv != null) (LucideIcons.activity, C.green, '${v.hrv!.round()}', 'ms'),
      if (v.rhr != null) (LucideIcons.heart, C.red, '${v.rhr!.round()}', 'bpm'),
      if (v.resp != null) (LucideIcons.wind, C.teal, v.resp!.toStringAsFixed(1), 'rpm'),
      if (v.stress != null)
        (LucideIcons.brain, C.purple, '${v.stress!.round()}', l?.homeVitalsStress ?? 'stress'),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    final cells = [
      for (final (icon, col, value, unit) in chips)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: S.x1),
          padding: const EdgeInsets.symmetric(vertical: S.x3, horizontal: S.x1),
          decoration: BoxDecoration(color: p.card, borderRadius: R.rMd),
          child: Column(children: [
            Icon(icon, size: 16, color: p.on(col)),
            const SizedBox(height: S.x2),
            Text(value, style: F.n24.copyWith(color: p.ink), maxLines: 1),
            const SizedBox(height: 2),
            Text(unit.toUpperCase(),
                style: F.labelSm.copyWith(color: p.ink3), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
    ];
    return _grid(c, cells, perRow: 4);
  }
}

// ── the day's heart rate ────────────────────────────────────────────────────

/// The day's stored heart rate, midnight to midnight, each stretch coloured by
/// the zone it sits in. A stretch more than fifteen minutes from its neighbour
/// is a gap (the band was off), drawn as one — never bridged. Last night's
/// window is shaded.
class _HeartDay extends CustomPainter {
  final List<ChartPoint> hr;
  final int dayStart;
  final List<num>? lower;
  final List<Color> zoneCols;
  final Color grid, shade, below;
  final int? sleepFrom, sleepTo;

  _HeartDay(this.hr, this.dayStart, this.lower, this.zoneCols,
      {required this.grid, required this.shade, required this.below, this.sleepFrom, this.sleepTo});

  static const _lo = 40.0, _hi = 200.0;

  Color _col(double bpm) {
    final edges = lower;
    if (edges == null || edges.length != 5 || bpm < edges[0]) return below;
    var z = 0;
    for (var i = 0; i < 5; i++) {
      if (bpm >= edges[i]) z = i;
    }
    return zoneCols[z];
  }

  @override
  void paint(Canvas c, Size s) {
    double x(int t) => ((t - dayStart) / 86400).clamp(0.0, 1.0) * s.width;
    double y(double v) => s.height - ((v - _lo) / (_hi - _lo)).clamp(0.0, 1.0) * s.height;
    final g = Paint()..color = grid..strokeWidth = 1;
    for (final v in [60.0, 100.0, 140.0, 180.0]) {
      c.drawLine(Offset(0, y(v)), Offset(s.width, y(v)), g);
    }
    final a = sleepFrom, b = sleepTo;
    if (a != null && b != null && b > a) {
      c.drawRect(Rect.fromLTRB(x(a), 0, x(b), s.height), Paint()..color = shade);
    }
    final line = Paint()..strokeWidth = 2..strokeCap = StrokeCap.round;
    for (var i = 1; i < hr.length; i++) {
      final p0 = hr[i - 1], p1 = hr[i];
      if (p1.t - p0.t > 900) continue;
      c.drawLine(Offset(x(p0.t), y(p0.v)), Offset(x(p1.t), y(p1.v)),
          line..color = _col((p0.v + p1.v) / 2));
    }
  }

  @override
  bool shouldRepaint(_HeartDay o) => o.hr != hr || o.zoneCols != zoneCols;
}

class DayHeartCard extends StatelessWidget {
  final HomeVitals v;
  final VoidCallback? onTap;
  const DayHeartCard(this.v, {super.key, this.onTap});

  @override
  Widget build(BuildContext c) {
    if (!v.hasHeart) return const SizedBox.shrink();
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    return Surface(
      onTap: onTap,
      pad: const EdgeInsets.all(S.x5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHead(l?.homeHeartTitle ?? "Today's heart rate", chevron: onTap != null),
        if (v.hrAvg != null) ...[
          const SizedBox(height: S.x2),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: S.x2,
            runSpacing: S.x1,
            children: [
              Text('${v.hrAvg}', style: F.n34.copyWith(color: p.ink)),
              Text((l?.homeHeartAvg ?? 'bpm average').toUpperCase(),
                  style: F.labelSm.copyWith(color: p.ink3)),
              if (v.hrMin != null && v.hrMax != null)
                Text('${v.hrMin}–${v.hrMax}', style: F.n17.copyWith(color: p.ink2)),
            ],
          ),
        ],
        const SizedBox(height: S.x4),
        SizedBox(
          height: 120,
          width: double.infinity,
          child: CustomPaint(
            painter: _HeartDay(
              v.hr,
              v.dayStart,
              v.zoneLower,
              ZoneRows.cols(p),
              grid: p.line,
              shade: p.wash(C.blueSoft),
              below: p.ink3,
              sleepFrom: v.onsetTs,
              sleepTo: v.wakeTs,
            ),
          ),
        ),
        const SizedBox(height: S.x2),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final h in ['00', '06', '12', '18', '24'])
            Text(h, style: F.cap.copyWith(color: p.ink3)),
        ]),
        if (v.zoneMin.length == 5 && v.zoneMin.any((m) => m > 0)) ...[
          const SizedBox(height: S.x5),
          Text((l?.homeHeartZones ?? 'Heart rate zones').toUpperCase(),
              style: F.labelSm.copyWith(color: p.ink3)),
          const SizedBox(height: S.x3),
          _zones(c, v),
        ],
      ]),
    );
  }
}

/// Z5 down to Z1, one line each: zone, its bpm range, a bar scaled to the
/// day's biggest zone, the minutes. The colours are [ZoneRows]' own.
Widget _zones(BuildContext c, HomeVitals v) {
  final p = P.of(c);
  final l = AppLocalizations.of(c);
  final cols = ZoneRows.cols(p);
  final most = v.zoneMin.reduce(math.max);
  return Column(children: [
    for (var i = 4; i >= 0; i--)
      Padding(
        padding: const EdgeInsets.only(bottom: S.x2),
        child: Row(children: [
          SizedBox(
            width: 30,
            child: Text('Z${i + 1}', style: F.n17.copyWith(color: cols[i])),
          ),
          Expanded(
            flex: 3,
            child: Text(
              (ZoneRows.range(v.zoneLower, i, l) ?? '').replaceAll(' bpm', ''),
              style: F.cap.copyWith(color: p.ink3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 5,
            child: LayoutBuilder(
              builder: (c, k) => Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 8,
                  width: most <= 0 ? 0 : math.max(4.0, k.maxWidth * v.zoneMin[i] / most),
                  decoration: BoxDecoration(color: cols[i], borderRadius: R.rPill),
                ),
              ),
            ),
          ),
          const SizedBox(width: S.x2),
          Text(hm(v.zoneMin[i]), style: F.n17.copyWith(color: p.ink)),
        ]),
      ),
  ]);
}

// ── last night ──────────────────────────────────────────────────────────────

class NightCard extends StatelessWidget {
  final HomeVitals v;
  final VoidCallback? onTap;
  const NightCard(this.v, {super.key, this.onTap});

  /// The painter takes one stage per column. An unobserved column carries the
  /// stage before it, so a one-second hole is not drawn as a lane change.
  static List<SleepStage> _filled(List<SleepStage?> st) {
    final out = <SleepStage>[];
    SleepStage? last;
    for (final s in st) {
      last = s ?? last;
      if (last != null) out.add(last);
    }
    return out;
  }

  @override
  Widget build(BuildContext c) {
    if (!v.hasNight) return const SizedBox.shrink();
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final stages = _filled(v.stages);
    String clock(int? ts) =>
        ts == null ? '' : formatClockOf(DateTime.fromMillisecondsSinceEpoch(ts * 1000));

    final cells = <Widget>[
      _stat(c, hm(v.sleepMin), l?.homeNightAsleep ?? 'Asleep'),
      if (v.efficiency != null)
        _stat(c, '${(v.efficiency! * 100).round()}%', l?.homeNightEfficiency ?? 'Efficiency'),
      if (v.deepMin != null)
        _stat(c, hm(v.deepMin), l?.homeNightDeep ?? 'Deep', color: p.on(C.blue)),
      if (v.remMin != null) _stat(c, hm(v.remMin), l?.homeNightRem ?? 'REM', color: p.on(C.teal)),
      if (v.regularity != null)
        _stat(c, '${v.regularity!.round()}%', l?.homeNightConsistency ?? 'Consistency',
            color: p.on(C.green)),
      if (v.debtMin != null && v.debtMin! > 0)
        _stat(c, hm(v.debtMin), l?.homeNightDebt ?? 'Sleep debt', color: p.on(C.orange)),
      if (v.needMin != null) _stat(c, hm(v.needMin), l?.homeNightNeed ?? 'Need'),
      if (v.cycles != null) _stat(c, '${v.cycles}', l?.homeNightCycles ?? 'Cycles'),
    ];

    return Surface(
      onTap: onTap,
      pad: const EdgeInsets.all(S.x5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHead(l?.homeNightTitle ?? 'Last night', chevron: onTap != null),
        if (stages.length >= 2) ...[
          const SizedBox(height: S.x4),
          Row(children: [
            SizedBox(
              width: 52,
              height: 88,
              child: Column(children: [
                for (final st in SleepStage.values)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(st.label(l).toUpperCase(),
                            style: F.labelSm.copyWith(color: p.ink3), maxLines: 1),
                      ),
                    ),
                  ),
              ]),
            ),
            Expanded(
              child: SizedBox(
                height: 88,
                child: CustomPaint(painter: Hypnogram(stages, p)),
              ),
            ),
          ]),
          const SizedBox(height: S.x2),
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(child: Text(clock(v.onsetTs), style: F.cap.copyWith(color: p.ink3))),
              const SizedBox(width: S.x2),
              Flexible(
                child: Text(clock(v.wakeTs),
                    style: F.cap.copyWith(color: p.ink3), textAlign: TextAlign.end),
              ),
            ]),
          ),
        ],
        const SizedBox(height: S.x5),
        _grid(c, cells, perRow: 4),
      ]),
    );
  }
}

// ── health monitor ──────────────────────────────────────────────────────────

class HealthMonitorCard extends StatelessWidget {
  final HomeVitals v;
  final VoidCallback? onTap;
  const HealthMonitorCard(this.v, {super.key, this.onTap});

  @override
  Widget build(BuildContext c) {
    if (!v.hasMonitor) return const SizedBox.shrink();
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final calibrating = v.watchNeed != null;
    final dot = calibrating || v.watchState == null
        ? p.track
        : switch (v.watchState) {
            'green' => p.on(C.green),
            'amber' => p.on(C.orange),
            _ => p.on(C.red),
          };
    String temp(double z) => '${z >= 0 ? '+' : '−'}${z.abs().toStringAsFixed(1)}';
    final cells = [
      (LucideIcons.wind, l?.homeMonitorResp ?? 'Resp', v.resp?.toStringAsFixed(1)),
      (LucideIcons.droplet, l?.homeMonitorSpo2 ?? 'SpO₂', null),
      (LucideIcons.heartPulse, l?.homeMonitorRhr ?? 'RHR', v.rhr?.round().toString()),
      (LucideIcons.activity, l?.homeMonitorHrv ?? 'HRV', v.hrv?.round().toString()),
      (LucideIcons.thermometer, l?.homeMonitorTemp ?? 'Temp', v.skinTempZ == null ? null : temp(v.skinTempZ!)),
    ];
    final status = calibrating
        ? (l?.homeMonitorCalibrating(v.watchHave!, v.watchNeed!) ??
            'Calibrating · ${v.watchHave} of ${v.watchNeed} nights before your usual ranges are set.')
        : switch (v.watchState) {
            'green' => l?.homeMonitorGreen ?? 'Nothing unusual in your overnight signs.',
            'amber' => l?.homeMonitorAmber ?? 'Something in your overnight signs looks off. See Health.',
            null => l?.homeMonitorUnknown ?? 'Not checked against your usual ranges yet.',
            _ => l?.homeMonitorRed ?? 'Several overnight signs are off. See Health.',
          };

    return Surface(
      onTap: onTap,
      pad: const EdgeInsets.all(S.x5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHead(l?.homeMonitorTitle ?? 'Health monitor', chevron: onTap != null),
        const SizedBox(height: S.x5),
        _grid(
          c,
          [
            for (final (icon, name, value) in cells)
              Column(children: [
                Icon(icon, size: 22, color: p.ink),
                const SizedBox(height: S.x2),
                Text(name.toUpperCase(),
                    style: F.labelSm.copyWith(color: p.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: S.x2),
                Text(value ?? '—', style: F.n17.copyWith(color: value == null ? p.ink3 : p.ink)),
                const SizedBox(height: S.x2),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: value == null ? p.track : dot),
                ),
              ]),
          ],
          perRow: 5,
        ),
        const SizedBox(height: S.x4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: S.x3, vertical: S.x3),
          decoration: BoxDecoration(color: p.card2, borderRadius: R.rMd),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
            ),
            const SizedBox(width: S.x2),
            Expanded(child: Text(status, style: F.cap.copyWith(color: p.ink2))),
          ]),
        ),
        const SizedBox(height: S.x2),
        Text(l?.homeMonitorNoSpo2 ?? 'SpO₂ is not read from this strap.',
            style: F.cap.copyWith(color: p.ink3)),
      ]),
    );
  }
}

// ── dashboard ───────────────────────────────────────────────────────────────

class _Tri extends CustomPainter {
  final bool up;
  final Color color;
  _Tri(this.up, this.color);

  @override
  void paint(Canvas c, Size s) {
    final path = up
        ? (Path()..moveTo(0, s.height)..lineTo(s.width, s.height)..lineTo(s.width / 2, 0)..close())
        : (Path()..moveTo(0, 0)..lineTo(s.width, 0)..lineTo(s.width / 2, s.height)..close());
    c.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Tri o) => o.up != up || o.color != color;
}

/// Today's value of each dashboard metric over the mean of the 30 days before
/// it. The arrow is coloured only where the literature agrees which way is
/// better at rest (HRV up, resting HR down, more steps); breathing and calories
/// get a neutral arrow, because neither direction is good on its own.
class DashboardRows extends StatelessWidget {
  final HomeVitals v;
  final void Function(String key)? onOpen;
  const DashboardRows(this.v, {super.key, this.onOpen});

  static const _icons = {
    'hrv': LucideIcons.activity,
    'resting_hr': LucideIcons.heartPulse,
    'steps': LucideIcons.footprints,
    'resp_rate': LucideIcons.wind,
    'calories': LucideIcons.flame,
  };
  static const _higherIsBetter = {'hrv': true, 'resting_hr': false, 'steps': true};

  /// Name left, figures right; at large text the figures go under the name,
  /// where they have the width.
  static Widget _row(BuildContext c, Widget name, Widget figures) => bigText(c)
      ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          name,
          const SizedBox(height: S.x2),
          // At the largest sizes even a four-digit figure and its mean are
          // wider than the card; they shrink to fit rather than clip.
          Align(
            alignment: Alignment.centerRight,
            child: FittedBox(fit: BoxFit.scaleDown, child: figures),
          ),
        ])
      : Row(children: [Expanded(child: name), const SizedBox(width: S.x2), figures]);

  static String _name(AppLocalizations? l, String key) => switch (key) {
        'hrv' => l?.homeDashHrv ?? 'Heart rate variability',
        'resting_hr' => l?.homeDashRestingHr ?? 'Resting heart rate',
        'steps' => l?.homeDashSteps ?? 'Steps',
        'resp_rate' => l?.homeDashRespRate ?? 'Respiratory rate',
        'calories' => l?.homeDashCalories ?? 'Active energy',
        _ => specOf(key).title,
      };

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    String fmt(String key, double x) => switch (key) {
          'resp_rate' => x.toStringAsFixed(1),
          'steps' || 'calories' => thousands(x),
          _ => '${x.round()}',
        };
    final rows = [for (final k in HomeVitals.dashKeys) if (v.dash[k] case final f?) (k, f)];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      for (final (key, f) in rows) ...[
        Surface(
          onTap: onOpen == null ? null : () => onOpen!(key),
          pad: const EdgeInsets.symmetric(horizontal: S.x4, vertical: S.x4),
          child: _row(
            c,
            Row(children: [
              Icon(_icons[key], size: 22, color: p.ink3),
              const SizedBox(width: S.x3),
              Expanded(
                child: Text(_name(l, key).toUpperCase(),
                    style: F.label.copyWith(color: p.ink), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmt(key, f.today!), style: F.n24.copyWith(color: p.ink)),
              if (f.before != null) ...[
                const SizedBox(height: 2),
                Text(fmt(key, f.before!), style: F.cap.copyWith(color: p.ink3)),
              ],
            ]),
            const SizedBox(width: S.x2),
            SizedBox(
              width: 10,
              height: 8,
              // No arrow when the two print the same: a triangle under "51"
              // over "51" points at a difference the reader cannot see.
              child: f.before == null || fmt(key, f.today!) == fmt(key, f.before!)
                  ? null
                  : CustomPaint(
                      painter: _Tri(
                        f.today! > f.before!,
                        switch (_higherIsBetter[key]) {
                          null => p.ink3,
                          final hb => (f.today! > f.before!) == hb ? p.on(C.green) : p.on(C.orange),
                        },
                      ),
                    ),
            ),
            ]),
          ),
        ),
        const SizedBox(height: S.x2),
      ],
    ]);
  }
}

// ── recovery, while it calibrates ───────────────────────────────────────────

/// What stands where a recovery score will be: the nights already recorded,
/// and the number recovery's own baseline gate says it needs. Drawn only while
/// that gate is still filling.
class RecoveryCalibrationCard extends StatelessWidget {
  final HomeVitals v;
  final VoidCallback? onTap;
  const RecoveryCalibrationCard(this.v, {super.key, this.onTap});

  static bool shows(HomeVitals v) => v.recoveryNeed != null && v.nightsRecorded != null;

  @override
  Widget build(BuildContext c) {
    if (!shows(v)) return const SizedBox.shrink();
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final nights = v.nightsRecorded!;
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l?.homeRecoveryCalTitle ?? 'Recovery is calibrating',
          style: F.head.copyWith(color: p.ink)),
      const SizedBox(height: S.x2),
      Text(
        l?.homeRecoveryCalBody(nights, v.recoveryNeed!) ??
            '$nights nights of sleep recorded. A recovery score appears after '
                '${v.recoveryNeed} nights with complete overnight data.',
        style: F.body.copyWith(color: p.ink2),
      ),
      if (onTap != null) ...[
        const SizedBox(height: S.x3),
        Row(children: [
          Flexible(
            child: Text((l?.homeRecoveryCalLink ?? 'See HRV').toUpperCase(),
                style: F.label.copyWith(color: p.on(C.green))),
          ),
          const SizedBox(width: S.x2),
          Icon(LucideIcons.arrowRight, size: 16, color: p.on(C.green)),
        ]),
      ],
    ]);
    final dial = SizedBox(
      width: 76,
      height: 76,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(size: Size.infinite, painter: Ring(0, p.track, p.track, stroke: 6)),
        Padding(
          padding: const EdgeInsets.all(S.x3),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$nights', style: F.n24.copyWith(color: p.ink)),
              Text((l?.homeRecoveryCalNights ?? 'nights').toUpperCase(),
                  style: F.labelSm.copyWith(color: p.ink3)),
            ]),
          ),
        ),
      ]),
    );
    return Surface(
      onTap: onTap,
      pad: const EdgeInsets.all(S.x5),
      child: bigText(c)
          ? Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [dial, const SizedBox(height: S.x3), text])
          : Row(children: [Expanded(child: text), const SizedBox(width: S.x3), dial]),
    );
  }
}

// ── my day ──────────────────────────────────────────────────────────────────

/// Today's activities: last night as the first one, and the two ways to add
/// another — log one that happened, or start one now.
class MyDayCard extends StatelessWidget {
  final HomeVitals v;
  final VoidCallback? onAdd, onStart, onSleep;
  const MyDayCard(this.v, {super.key, this.onAdd, this.onStart, this.onSleep});

  /// Pill, name, times across; at large text the pill takes its own line.
  static Widget _sleepRow(BuildContext c, Widget pill, Widget name, Widget times) => bigText(c)
      ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          pill,
          const SizedBox(height: S.x2),
          Row(children: [Expanded(child: name), const SizedBox(width: S.x2), Flexible(child: times)]),
        ])
      : Row(children: [
          Flexible(child: pill),
          const SizedBox(width: S.x3),
          Expanded(child: name),
          times,
        ]);

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    String clock(int? ts) =>
        ts == null ? '' : formatClockOf(DateTime.fromMillisecondsSinceEpoch(ts * 1000));
    Widget button(IconData icon, String label, VoidCallback? onTap) => Pressable(
          onTap: onTap,
          semanticLabel: label,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: S.x3, horizontal: S.x2),
            decoration: BoxDecoration(color: p.card2, borderRadius: R.rMd),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 18, color: p.ink),
              const SizedBox(width: S.x2),
              Flexible(
                child: Text(label.toUpperCase(),
                    style: F.label.copyWith(color: p.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        );
    return Surface(
      pad: const EdgeInsets.all(S.x5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHead(l?.homeActivitiesTitle ?? "Today's activities"),
        if (v.hasNight) ...[
          const SizedBox(height: S.x4),
          Pressable(
            onTap: onSleep,
            semanticLabel: l?.homeActivitySleep ?? 'Sleep',
            child: Container(
              padding: const EdgeInsets.all(S.x2),
              decoration: BoxDecoration(color: p.card2, borderRadius: R.rLg),
              child: _sleepRow(
                c,
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: S.x4, vertical: S.x3),
                  decoration: BoxDecoration(color: p.fill(C.blueSoft), borderRadius: R.rMd),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.moon, size: 18, color: p.inkOnFill),
                    const SizedBox(width: S.x2),
                    Flexible(
                      child: Text(hm(v.sleepMin),
                          style: F.n24.copyWith(color: p.inkOnFill), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ),
                Text((l?.homeActivitySleep ?? 'Sleep').toUpperCase(),
                    style: F.label.copyWith(color: p.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(clock(v.onsetTs), style: F.cap.copyWith(color: p.ink3)),
                  Text(clock(v.wakeTs), style: F.cap.copyWith(color: p.ink3)),
                ]),
              ),
            ),
          ),
        ],
        if (onAdd != null || onStart != null) ...[
          const SizedBox(height: S.x3),
          Row(children: [
            if (onAdd != null) Expanded(child: button(LucideIcons.plus, l?.homeActivityAdd ?? 'Add', onAdd)),
            if (onAdd != null && onStart != null) const SizedBox(width: S.x3),
            if (onStart != null) Expanded(child: button(LucideIcons.timer, l?.homeActivityStart ?? 'Start', onStart)),
          ]),
        ],
      ]),
    );
  }
}

/// Tonight's plan from the sleep coach: when to put the lights out, and the
/// wake time the need and your efficiency imply.
class TonightCard extends StatelessWidget {
  final HomeVitals v;
  final VoidCallback? onTap;
  const TonightCard(this.v, {super.key, this.onTap});

  static bool shows(HomeVitals v) => v.bedtimeMin != null && v.wakeMin != null;

  @override
  Widget build(BuildContext c) {
    if (!shows(v)) return const SizedBox.shrink();
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    Widget half(IconData icon, String time, String label) => Column(children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 22, color: p.ink3),
              const SizedBox(width: S.x2),
              Text(time, style: F.n34.copyWith(color: p.ink)),
            ]),
          ),
          const SizedBox(height: S.x2),
          Text(label.toUpperCase(), textAlign: TextAlign.center, style: F.labelSm.copyWith(color: p.ink3)),
        ]);
    return Surface(
      onTap: onTap,
      pad: const EdgeInsets.all(S.x5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHead(l?.homeTonightTitle ?? "Tonight's sleep", chevron: onTap != null),
        const SizedBox(height: S.x4),
        _grid(c, [
          half(LucideIcons.sunset, formatClockMinute(v.bedtimeMin!.round()),
              l?.homeTonightBedtime ?? 'Recommended bedtime'),
          half(LucideIcons.alarmClock, formatClockMinute(v.wakeMin!.round()),
              v.needMin == null
                  ? (l?.homeTonightWake ?? 'Wake')
                  : (l?.homeTonightWakeNeed(hm(v.needMin)) ?? 'Wake · need ${hm(v.needMin)}')),
        ], perRow: 2),
      ]),
    );
  }
}
