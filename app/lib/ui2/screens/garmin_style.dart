// GARMIN-STYLE CARDS FROM A WHOOP BAND — all-day stress 0–100, Body Battery
// and fitness age (VO2max from routine). Owner decision, 2026-11-01; the
// research and the honesty notes are in docs/LOCAL_METRICS_RESEARCH.md and on
// each analytics function.
//
// Everything here is computed ON READ from what the derive already stored —
// `daytime_hrv` (motion-gated five-minute RMSSD), the minute HR curve, the
// sleep windows, and the nightly HRV / resting-HR / sleep-stress series — so
// none of it needs a schema change or a re-derive, and none of it feeds back
// into Recovery, Strain or any stored score.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:projectfit_analytics/onehz.dart' as ana;

import '../../compute/hr_max.dart' show estimatedMaxHr;
import '../../compute/profile.dart' show bmiOf, workoutSex;
import '../../data/day_label.dart';
import '../../data/local_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../models/metric.dart' show needMessageFromNote;
import '../ui2.dart';
import 'home_screen.dart' show ChartPoint;

/// Days of burn-in before the shown day: the battery's start level is unknown.
const int _batteryDays = ana.bodyBatteryBurnInDays + 1;

class GarminStyleData {
  final ana.Metric<ana.AllDayStress> stress;
  final ana.Metric<ana.BodyBattery> battery;
  final ana.Metric<ana.RoutineFitness> fitness;

  /// The day the stress and battery describe (the newest derived day).
  final String? day;

  /// Epoch seconds of that day's local midnight, the x-axis origin.
  final int? dayStartSec;
  final num? age;

  const GarminStyleData({
    required this.stress,
    required this.battery,
    required this.fitness,
    this.day,
    this.dayStartSec,
    this.age,
  });

  static const empty = GarminStyleData(
    stress: ana.Metric.absent(tier: ana.Tier.estimate, inputs_used: []),
    battery: ana.Metric.absent(tier: ana.Tier.estimate, inputs_used: []),
    fitness: ana.Metric.absent(tier: ana.Tier.estimate, inputs_used: []),
  );

  static Map<String, double> _byDay(List<ChartPoint> pts) => {
        for (final p in pts)
          dayLabelOf(DateTime.fromMillisecondsSinceEpoch(p.t * 1000)): p.v,
      };

  static String _shift(String day, int by) {
    final d = DateTime.parse(day);
    return dayLabelOf(DateTime(d.year, d.month, d.day + by));
  }

  /// [hrv], [rhr] and [sleepStress] are the stored nightly series (`getChart`
  /// points), [days] the derived days newest first.
  static Future<GarminStyleData> load(
    LocalRepository repo, {
    required Map<String, dynamic> profile,
    required List<String> days,
    required List<ChartPoint> hrv,
    required List<ChartPoint> rhr,
    required List<ChartPoint> sleepStress,
  }) async {
    final age = profile['age'] as num?;
    final hrvBy = _byDay(hrv), rhrBy = _byDay(rhr), stressBy = _byDay(sleepStress);
    List<double?> nightsUpTo(Map<String, double> by, String day, int n) =>
        [for (var i = n - 1; i >= 0; i--) by[_shift(day, -i)]];

    final fitness = await _fitness(repo, profile, age, rhrBy);
    if (days.isEmpty) {
      return GarminStyleData(
          stress: empty.stress, battery: empty.battery, fitness: fitness, age: age);
    }
    final day = days.first;
    final start = localDayStartSec(day);

    // ── the shown day and its burn-in, one read per day ──
    final heart = <String, Map<String, dynamic>>{};
    final sleep = <String, Map<String, dynamic>>{};
    for (var i = -(_batteryDays - 1); i <= 1; i++) {
      final d = _shift(day, i);
      sleep[d] = await _soft(() => repo.getDaySleepV2(d));
      if (i <= 0) heart[d] = await _soft(() => repo.getDayHeart(d));
    }

    List<ana.QuietHrvWindow> windowsOf(String d) {
      final tl = (heart[d]?['daytime_hrv'] as Map?)?['timeline'];
      return [
        for (final e in (tl is List ? tl : const []))
          if (e is Map && e['t'] is num && e['rmssd'] is num && e['n'] is num)
            ana.QuietHrvWindow((e['t'] as num).round(),
                (e['rmssd'] as num).toDouble(), (e['n'] as num).round()),
      ];
    }

    final stress = ana.allDayStress(windowsOf(day), nightsUpTo(hrvBy, day, 14));

    // ── battery slots ──
    final windows = <(int, int, double?)>[]; // sleep onset, wake, its stress
    for (final e in sleep.entries) {
      final on = e.value['onset_ts'], off = e.value['wake_ts'];
      if (on is num && off is num && off > on) {
        windows.add((on.round(), off.round(), stressBy[e.key]));
      }
    }
    final hrMax = estimatedMaxHr(age, null);
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final slots = <ana.BatterySlot>[];
    for (var i = -(_batteryDays - 1); i <= 0; i++) {
      final d = _shift(day, i);
      final lo = localDayStartSec(d), hi = localDayEndSec(d);
      if (lo == null || hi == null) continue;
      final rest = ana.restReferenceRmssd(nightsUpTo(hrvBy, d, 14));
      final quiet = {
        for (final w in windowsOf(d))
          if (w.pairs >= ana.allDayStressMinPairs) w.tSec: w.rmssdMs
      };
      final hrSlots = <int, List<double>>{};
      for (final e in (heart[d]?['hr'] as List? ?? const [])) {
        if (e is! Map || e['t'] is! num || e['v'] is! num) continue;
        final t = (e['t'] as num).round();
        (hrSlots[t - t % ana.bodyBatterySlotSec] ??= [])
            .add((e['v'] as num).toDouble());
      }
      final dayRhr = rhrBy[d] ?? rhrBy[_shift(d, -1)];
      for (var t = lo - lo % ana.bodyBatterySlotSec;
          t < hi && t <= nowSec;
          t += ana.bodyBatterySlotSec) {
        final night = windows.where((w) => t >= w.$1 && t < w.$2);
        if (night.isNotEmpty) {
          slots.add(ana.BatterySlot(t, ana.BatteryState.asleep,
              stress: night.first.$3));
          continue;
        }
        final q = quiet[t];
        if (q != null && rest != null) {
          slots.add(ana.BatterySlot(t, ana.BatteryState.still,
              stress: ana.stressScoreOf(q, rest)));
          continue;
        }
        final hr = hrSlots[t];
        if (hr == null || hr.isEmpty) {
          slots.add(ana.BatterySlot(t, ana.BatteryState.notWorn));
          continue;
        }
        final mean = hr.reduce((a, b) => a + b) / hr.length;
        final hrr = (hrMax == null || dayRhr == null || hrMax <= dayRhr)
            ? null
            : (mean - dayRhr) / (hrMax - dayRhr);
        slots.add(hrr != null && hrr >= ana.bbActiveHrrFloor
            ? ana.BatterySlot(t, ana.BatteryState.active, hrr: hrr)
            : ana.BatterySlot(t, ana.BatteryState.awake));
      }
    }
    final battery = start == null
        ? empty.battery
        : ana.bodyBattery(slots, showFromSec: start);

    return GarminStyleData(
      stress: stress,
      battery: battery,
      fitness: fitness,
      day: day,
      dayStartSec: start,
      age: age,
    );
  }

  static Future<ana.Metric<ana.RoutineFitness>> _fitness(
    LocalRepository repo,
    Map<String, dynamic> profile,
    num? age,
    Map<String, double> rhrBy,
  ) async {
    final today = todayLabel();
    final nights = [
      for (var i = 13; i >= 0; i--) rhrBy[_shift(today, -i)]
    ];
    final known = [for (final v in nights) ?v];
    final rhr = known.isEmpty ? null : (known..sort())[known.length ~/ 2];
    final hrMax = estimatedMaxHr(age, null);
    final from = DateTime.now().millisecondsSinceEpoch ~/ 1000 -
        ana.paIndexWindowDays * 86400;
    final sessions = <ana.RoutineSession>[];
    final w = await _soft(() => repo.getWorkouts(range: 'month'));
    for (final s in (w['workouts'] as List? ?? const [])) {
      if (s is! Map || s['status'] == 'live') continue;
      final st = s['start_ts'], min = s['duration_min'];
      if (st is! num || st < from || min is! num || min <= 0) continue;
      final avg = s['avg_hr'];
      final hrr = (avg is num && rhr != null && hrMax != null && hrMax > rhr)
          ? ((avg - rhr) / (hrMax - rhr)).clamp(0.0, 1.0).toDouble()
          : null;
      sessions.add(ana.RoutineSession(min.toDouble(), meanHrr: hrr));
    }
    return ana.routineFitness(
      age: age?.toDouble(),
      sex: workoutSex(profile['sex'] as String?),
      waistCm: (profile['waist_cm'] as num?)?.toDouble(),
      bmi: bmiOf(profile['weight_kg'] as num?, profile['height_cm'] as num?),
      nightlyRhr: nights,
      sessions: sessions,
    );
  }

  static Future<Map<String, dynamic>> _soft(
      Future<Map<String, dynamic>> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return const {};
    }
  }
}

// ── STRESS ──────────────────────────────────────────────────────────────────

Color stressColor(double score) =>
    score <= 25 ? C.blue : (score <= 50 ? C.yellow : (score <= 75 ? C.orange : C.red));

String stressBandWord(AppLocalizations? l, String band) => switch (band) {
      'rest' => l?.stressBandRest ?? 'Rest',
      'low' => l?.stressBandLow ?? 'Low',
      'medium' => l?.stressBandMedium ?? 'Medium',
      _ => l?.stressBandHigh ?? 'High',
    };

class AllDayStressCard extends StatelessWidget {
  final ana.Metric<ana.AllDayStress> stress;
  final int? dayStartSec;
  const AllDayStressCard(this.stress, {super.key, this.dayStartSec});

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    final p = P.of(c);
    final v = stress.value;
    if (v == null) {
      return StatusCard(
        l?.stressDayLearningTitle ?? 'Stress is still learning',
        needMessageFromNote(stress.note) ??
            (l?.stressDayLearningBody ??
                'It needs a week of nights and at least half an hour of still '
                    'time today.'),
        icon: LucideIcons.hourglass,
      );
    }
    final band = ana.stressBand(v.average);
    return Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          spacing: S.x2,
          runSpacing: S.x2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l?.stressDayTitle ?? 'Stress', style: F.head.copyWith(color: p.ink)),
            Pill(stressBandWord(l, band), stressColor(v.average), wrap: true),
          ],
        ),
        const SizedBox(height: S.x2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('${v.average.round()}', style: F.n34.copyWith(color: p.ink)),
            const SizedBox(width: S.x2),
            Flexible(
              child: Text(
                l?.stressDayAverage(v.highest.round().toString()) ??
                    'average · highest ${v.highest.round()}',
                style: F.cap.copyWith(color: p.ink3),
              ),
            ),
          ],
        ),
        const SizedBox(height: S.x3),
        SizedBox(
          height: 56,
          child: CustomPaint(
            size: Size.infinite,
            painter: _StressBars(v.timeline, dayStartSec, p),
          ),
        ),
        const SizedBox(height: S.x3),
        Wrap(spacing: S.x3, runSpacing: S.x1, children: [
          for (final b in const ['rest', 'low', 'medium', 'high'])
            Text(
              l?.stressBandMinutes(stressBandWord(l, b), v.bandMinutes[b] ?? 0) ??
                  '${stressBandWord(l, b)} ${v.bandMinutes[b] ?? 0} min',
              style: F.cap.copyWith(color: p.ink2),
            ),
        ]),
        const SizedBox(height: S.x2),
        Text(
          l?.stressDayFootnote ??
              'Scored only while you were still, against how variable your '
                  'heart is at night: as calm as your nights reads 0. '
                  'ProjectFit’s own scale, not Garmin’s, so compare it only '
                  'with itself. Moving time is left blank, not scored.',
          style: F.cap.copyWith(color: p.ink3),
        ),
      ]),
    );
  }
}

class _StressBars extends CustomPainter {
  final List<ana.StressPoint> pts;
  final int? t0;
  final P p;
  _StressBars(this.pts, this.t0, this.p);

  @override
  void paint(Canvas c, Size s) {
    c.drawLine(Offset(0, s.height), Offset(s.width, s.height),
        Paint()..color = p.track);
    if (pts.isEmpty) return;
    final origin = t0 ?? pts.first.tSec;
    final w = math.max(1.5, s.width / 288 - 0.5);
    for (final q in pts) {
      final x = (q.tSec - origin) / 86400 * s.width;
      final h = math.max(2.0, q.score / 100 * s.height);
      c.drawRect(Rect.fromLTWH(x, s.height - h, w, h),
          Paint()..color = p.on(stressColor(q.score)));
    }
  }

  @override
  bool shouldRepaint(_StressBars o) => true;
}

// ── BODY BATTERY ────────────────────────────────────────────────────────────

class BodyBatteryCard extends StatelessWidget {
  final ana.Metric<ana.BodyBattery> battery;
  final int? dayStartSec;
  const BodyBatteryCard(this.battery, {super.key, this.dayStartSec});

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    final p = P.of(c);
    final v = battery.value;
    if (v == null) {
      return StatusCard(
        l?.batteryLearningTitle ?? 'Body Battery needs a night first',
        l?.batteryLearningBody ??
            'It starts counting from a night the band recorded, and needs an '
                'hour of wear today.',
        icon: LucideIcons.batteryLow,
      );
    }
    final last = DateTime.fromMillisecondsSinceEpoch(
        v.timeline.last.tSec * 1000);
    final at = '${last.hour.toString().padLeft(2, '0')}:'
        '${last.minute.toString().padLeft(2, '0')}';
    return Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l?.batteryTitle ?? 'Body Battery',
            style: F.head.copyWith(color: p.ink)),
        const SizedBox(height: S.x2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('${v.current.round()}', style: F.n34.copyWith(color: p.ink)),
            const SizedBox(width: S.x2),
            Flexible(
              child: Text(l?.batteryAt(at) ?? 'at $at',
                  style: F.cap.copyWith(color: p.ink3)),
            ),
          ],
        ),
        const SizedBox(height: S.x3),
        SizedBox(
          height: 64,
          child: CustomPaint(
            size: Size.infinite,
            painter: _BatteryLine(v.timeline, dayStartSec, p),
          ),
        ),
        const SizedBox(height: S.x3),
        Text(
          l?.batteryChargedDrained(
                  v.charged.round().toString(), v.drained.round().toString()) ??
              '+${v.charged.round()} charged · −${v.drained.round()} drained today',
          style: F.body.copyWith(color: p.ink2),
        ),
        const SizedBox(height: S.x2),
        Text(
          l?.batteryFootnote ??
              'ProjectFit’s estimate, modelled on how Garmin describes Body '
                  'Battery: sleep and calm still time charge it, activity and '
                  'stress drain it. The rates are ours and written down in the '
                  'research notes; this is not Garmin’s number.',
          style: F.cap.copyWith(color: p.ink3),
        ),
      ]),
    );
  }
}

class _BatteryLine extends CustomPainter {
  final List<ana.BatteryPoint> pts;
  final int? t0;
  final P p;
  _BatteryLine(this.pts, this.t0, this.p);

  @override
  void paint(Canvas c, Size s) {
    final grid = Paint()..color = p.track;
    for (final y in const [0.0, 0.5, 1.0]) {
      c.drawLine(Offset(0, y * s.height), Offset(s.width, y * s.height), grid);
    }
    if (pts.isEmpty) return;
    final origin = t0 ?? pts.first.tSec;
    Offset at(ana.BatteryPoint q) => Offset(
        ((q.tSec - origin) / 86400 * s.width).clamp(0.0, s.width),
        s.height - q.level / 100 * s.height);
    final line = Paint()
      ..color = p.on(C.teal)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    Path? path;
    int? prevT;
    for (final q in pts) {
      // A gap of more than one slot (band off) breaks the line.
      if (path == null || prevT == null || q.tSec - prevT > ana.bodyBatterySlotSec) {
        if (path != null) c.drawPath(path, line);
        path = Path()..moveTo(at(q).dx, at(q).dy);
      } else {
        path.lineTo(at(q).dx, at(q).dy);
      }
      prevT = q.tSec;
    }
    if (path != null) c.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_BatteryLine o) => true;
}

// ── FITNESS AGE ─────────────────────────────────────────────────────────────

class RoutineFitnessCard extends StatelessWidget {
  final ana.Metric<ana.RoutineFitness> fitness;
  final num? age;
  const RoutineFitnessCard(this.fitness, {super.key, this.age});

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    final p = P.of(c);
    final v = fitness.value;
    if (v == null) {
      final needsWaist = fitness.note == 'need_input:name=waist_cm';
      final needsAge = fitness.note == 'need_input:name=age';
      return StatusCard(
        needsWaist || needsAge
            ? (l?.fitnessNeedProfileTitle ?? 'Add your waist and age')
            : (l?.fitnessLearningTitle ?? 'Fitness age is still learning'),
        needsWaist || needsAge
            ? (l?.fitnessNeedProfileBody ??
                'Profile › Edit profile. Fitness age is worked out from your '
                    'age, waist, resting heart rate and routine.')
            : (needMessageFromNote(fitness.note) ??
                (l?.fitnessLearningBody ?? 'It needs a week of nights.')),
        icon: LucideIcons.hourglass,
      );
    }
    String one(double x) => x.toStringAsFixed(0);
    return Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l?.fitnessTitle ?? 'Fitness age', style: F.head.copyWith(color: p.ink)),
        const SizedBox(height: S.x2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(one(v.fitnessAge), style: F.n34.copyWith(color: p.ink)),
            const SizedBox(width: S.x2),
            if (age != null)
              Flexible(
                child: Text(l?.fitnessYourAge('$age') ?? 'your age $age',
                    style: F.cap.copyWith(color: p.ink3)),
              ),
          ],
        ),
        const SizedBox(height: S.x2),
        Text(
          l?.fitnessVo2(one(v.vo2max), one(v.seeMlKgMin), one(v.averageForAge)) ??
              'VO₂max ≈ ${one(v.vo2max)} ± ${one(v.seeMlKgMin)} mL/kg/min · '
                  'average for your age ${one(v.averageForAge)}',
          style: F.body.copyWith(color: p.ink2),
        ),
        const SizedBox(height: S.x1),
        Text(
          l?.fitnessRoutine(v.pa.sessionsPerWeek.toStringAsFixed(1)) ??
              'Last 4 weeks: ${v.pa.sessionsPerWeek.toStringAsFixed(1)} sessions a week',
          style: F.cap.copyWith(color: p.ink2),
        ),
        const SizedBox(height: S.x2),
        Text(
          l?.fitnessFootnote ??
              'Estimated without an exercise test, with the HUNT Study model: '
                  'age, waist, resting heart rate and your routine. It is '
                  'often 5 mL/kg/min off either way. Your resting heart rate '
                  'here is the overnight one, a little lower than the seated '
                  'one the model was built on, so it may read slightly high.',
          style: F.cap.copyWith(color: p.ink3),
        ),
      ]),
    );
  }
}

// ── SLEEP SCORE ─────────────────────────────────────────────────────────────

/// The night's sleep score from what `getDaySleepV2` returns. Pure.
ana.Metric<ana.SleepScore> sleepScoreOfNight(Map<String, dynamic> n) =>
    ana.sleepScore(
      asleepMin: (n['duration_min'] as num?)?.toDouble(),
      needMin: (n['need_min'] as num?)?.toDouble(),
      deepMin: (n['deep_min'] as num?)?.toDouble(),
      remMin: (n['rem_min'] as num?)?.toDouble(),
      awakeMin: (n['awake_min'] as num?)?.toDouble(),
      restlessMin: (n['restless_min'] as num?)?.toDouble(),
      sleepStress: (n['sleep_stress'] as num?)?.toDouble(),
    );

class SleepScoreCard extends StatelessWidget {
  final ana.Metric<ana.SleepScore> score;
  const SleepScoreCard(this.score, {super.key});

  @override
  Widget build(BuildContext c) {
    final v = score.value;
    if (v == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(c);
    final p = P.of(c);
    final band = switch (ana.sleepScoreBand(v.score)) {
      'excellent' => (l?.sleepScoreExcellent ?? 'Excellent', C.green),
      'good' => (l?.sleepScoreGood ?? 'Good', C.blue),
      'fair' => (l?.sleepScoreFair ?? 'Fair', C.yellow),
      _ => (l?.sleepScorePoor ?? 'Poor', C.orange),
    };
    String label(String k) => switch (k) {
          'duration' => l?.sleepScoreDuration ?? 'Duration',
          'stages' => l?.sleepScoreStages ?? 'Stages',
          'awake' => l?.sleepScoreAwake ?? 'Awake time',
          'restlessness' => l?.sleepScoreRestless ?? 'Restlessness',
          _ => l?.sleepScoreStress ?? 'Stress',
        };
    return Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          spacing: S.x2,
          runSpacing: S.x2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l?.sleepScoreTitle ?? 'Sleep score',
                style: F.head.copyWith(color: p.ink)),
            Pill(band.$1, band.$2, wrap: true),
          ],
        ),
        const SizedBox(height: S.x2),
        Text('${v.score.round()}', style: F.n34.copyWith(color: p.ink)),
        const SizedBox(height: S.x3),
        for (final e in v.components.entries) ...[
          Row(children: [
            Expanded(
              flex: 2,
              child: Text(label(e.key),
                  style: F.cap.copyWith(color: p.ink2),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: S.x2),
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 8,
                child: ClipRRect(
                  borderRadius: R.rPill,
                  child: Stack(children: [
                    Positioned.fill(child: ColoredBox(color: p.track)),
                    FractionallySizedBox(
                      widthFactor: (e.value / 100).clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: ColoredBox(color: p.on(C.indigo)),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: S.x2),
            SizedBox(
              width: 32,
              child: Text('${e.value.round()}',
                  textAlign: TextAlign.right,
                  style: F.cap.copyWith(color: p.ink)),
            ),
          ]),
          const SizedBox(height: S.x2),
        ],
        if (v.needFromGuideline)
          Text(
            l?.sleepScoreGuideline ??
                'No sleep need learned yet, so duration is measured against '
                    '7 hours.',
            style: F.cap.copyWith(color: p.ink2),
          ),
        const SizedBox(height: S.x1),
        Text(
          l?.sleepScoreFootnote ??
              'Garmin’s ingredients with ProjectFit’s own weights: duration 35, '
                  'stages 20, awake time, restlessness and stress 15 each. Sleep '
                  'performance is still the share of your sleep need you got.',
          style: F.cap.copyWith(color: p.ink3),
        ),
      ]),
    );
  }
}
