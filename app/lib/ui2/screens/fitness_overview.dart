// The top of the workout tab, Bevel's way: two load gauges, then the week's
// cardio and strength as a grid of small cards, then each muscle's last
// session.
//
// Every figure is one this app already stores. The gauges are acute load
// against the person's own chronic load: the sweet spot is 0.8–1.3 times the
// chronic weekly figure (the acute:chronic window of Gabbett 2016), drawn as
// the green arc. Cardio uses the pipeline's ATL/CTL; muscular uses tonnage,
// the last seven days against the mean week of the 28 before them.
//
// Each muscle's "% recovered" is an estimate from its logged sets, with the
// whole model stated in muscle_recovery.dart; the card says it is one.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/decimal_text.dart';
import '../../l10n/display_text.dart';
import '../ui2.dart';
import 'home_screen.dart' show go, hm, thousands;
import 'muscle_recovery.dart';
import 'vo2_screen.dart';

/// Acute over chronic, and the window it should sit in.
const double kLoadLow = .8, kLoadHigh = 1.3;

/// One load gauge's inputs: this week's figure, and the person's usual week
/// (null while there is not enough history to have one).
typedef LoadGauge = ({double acute, double? chronic});

class FitnessSummary {
  final LoadGauge? cardio;
  final LoadGauge? muscular;

  /// Minutes and kcal per day, Monday first, this week and last.
  final List<double> activeMinThis, activeMinLast, kcalThis, kcalLast;

  /// Minutes per heart-rate zone this week, z1..z5.
  final List<double> zones;
  final double? vo2;
  final String? vo2Source;
  final int? hrr;
  final int totalSets;
  final double? volumeKg;

  /// Muscle → when it was last trained, and sets this week.
  final Map<String, DateTime> lastTrained;
  final Map<String, double> weekSets;

  /// Every session's work per muscle in the window, for the recovery estimate.
  final List<MuscleDose> doses;

  const FitnessSummary({
    this.cardio,
    this.muscular,
    this.activeMinThis = const [],
    this.activeMinLast = const [],
    this.kcalThis = const [],
    this.kcalLast = const [],
    this.zones = const [],
    this.vo2,
    this.vo2Source,
    this.hrr,
    this.totalSets = 0,
    this.volumeKg,
    this.lastTrained = const {},
    this.weekSets = const {},
    this.doses = const [],
  });
}

class FitnessOverview extends StatelessWidget {
  final FitnessSummary s;
  final DateTime? now;
  const FitnessOverview(this.s, {super.key, this.now});

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    final big = MediaQuery.textScalerOf(c).scale(10) > 14;
    Widget pair(Widget a, Widget b) => big
        ? Column(children: [a, const SizedBox(height: S.x3), b])
        : IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: a),
              const SizedBox(width: S.x3),
              Expanded(child: b),
            ]),
          );
    final sumMin = s.activeMinThis.fold(0.0, (a, b) => a + b);
    final sumKcal = s.kcalThis.fold(0.0, (a, b) => a + b);
    final z = s.zones.length == 5 ? s.zones : null;
    final zTotal = z?.fold(0.0, (a, b) => a + b) ?? 0;
    final topZone = z == null || zTotal == 0 ? null : z.indexOf(z.reduce(math.max));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      pair(
        _GaugeCard(l?.fitCardio ?? 'Cardio', s.cardio, C.blue),
        _GaugeCard(l?.fitMuscular ?? 'Muscular', s.muscular, C.orange),
      ),
      Section(
        l?.fitCardio ?? 'Cardio',
        Column(children: [
          pair(
            _Card(
              title: l?.fitActiveDuration ?? 'Active duration',
              value: hm(sumMin),
              sub: l?.fitThisWeek ?? 'This week',
              chart: _Cumulative(s.activeMinThis, s.activeMinLast, C.sky),
            ),
            _Card(
              title: l?.fitActiveEnergy ?? 'Active energy',
              value: '${thousands(sumKcal)} kcal',
              sub: l?.fitThisWeek ?? 'This week',
              chart: _Cumulative(s.kcalThis, s.kcalLast, C.sky),
            ),
          ),
          const SizedBox(height: S.x3),
          pair(
            _Card(
              title: l?.readingVo2 ?? 'VO₂ max',
              value: s.vo2 == null ? '–' : displayFixed(s.vo2!, 1),
              sub: s.vo2Source ?? (l?.vo2NoneTitle ?? 'No VO₂ max yet'),
              onTap: () => go(c, const Vo2MaxScreen()),
            ),
            _Card(
              title: l?.fitHrr ?? 'Heart rate recovery',
              value: s.hrr == null ? '–' : '${s.hrr} bpm',
              sub: l?.fitHrrSub ?? 'Drop in the first minute after your last workout',
            ),
          ),
          const SizedBox(height: S.x3),
          _Card(
            title: l?.fitZones ?? 'Heart rate zones this week',
            value: topZone == null ? '–' : (l?.fitZoneN(topZone + 1) ?? 'Zone ${topZone + 1}'),
            sub: topZone == null ? '' : hm(z![topZone]),
            chart: z == null ? null : _ZoneBars(z),
          ),
        ]),
      ),
      Section(
        l?.fitStrength ?? 'Strength',
        Column(children: [
          pair(
            _Card(title: l?.fitTotalSets ?? 'Total sets', value: '${s.totalSets}', sub: l?.fitThisWeek ?? 'This week'),
            _Card(
              title: l?.fitTotalVolume ?? 'Total volume',
              value: s.volumeKg == null ? '–' : '${thousands(s.volumeKg!)} kg',
              sub: l?.fitThisWeek ?? 'This week',
            ),
          ),
          if (s.lastTrained.isNotEmpty) ...[
            const SizedBox(height: S.x3),
            _MuscleCard(s, now ?? DateTime.now()),
          ],
        ]),
      ),
    ]);
  }
}

/// Where acute sits against the usual week, as Bevel draws it: a dial whose
/// green arc is the 0.8–1.3 window.
class _GaugeCard extends StatelessWidget {
  final String title;
  final LoadGauge? g;
  final Color color;
  const _GaugeCard(this.title, this.g, this.color);

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final chronic = g?.chronic;
    final acute = g?.acute;
    final ratio = chronic == null || chronic <= 0 || acute == null ? null : acute / chronic;
    final (String word, Color wc) = switch (ratio) {
      null => (l?.detailCalibrating ?? 'Calibrating', p.ink3),
      < kLoadLow => (l?.fitBelow ?? 'Below usual', p.on(C.blue)),
      <= kLoadHigh => (l?.fitOptimal ?? 'Optimal', p.on(C.green)),
      _ => (l?.fitAbove ?? 'Above usual', p.on(C.orange)),
    };
    return Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: F.head.copyWith(color: p.ink)),
        Text(word, style: F.t2.copyWith(color: wc)),
        const SizedBox(height: S.x2),
        AspectRatio(
          aspectRatio: 1.4,
          child: CustomPaint(
            painter: _Dial(acute, chronic, color, p),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(acute == null ? '–' : '${acute.round()}', style: F.n34.copyWith(color: p.ink)),
              ),
            ),
          ),
        ),
        if (chronic != null)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              l?.fitOptimalRange('${(chronic * kLoadLow).round()}', '${(chronic * kLoadHigh).round()}') ??
                  'Optimal: ${(chronic * kLoadLow).round()}–${(chronic * kLoadHigh).round()}',
              style: F.cap.copyWith(color: p.ink3),
            ),
          ),
      ]),
    );
  }
}

class _Dial extends CustomPainter {
  final double? acute, chronic;
  final Color color;
  final P p;
  _Dial(this.acute, this.chronic, this.color, this.p);

  @override
  void paint(Canvas c, Size s) {
    final r = math.min(s.width / 2, s.height * .62) - 6;
    final ctr = Offset(s.width / 2, s.height * .62);
    final rect = Rect.fromCircle(center: ctr, radius: r);
    const start = math.pi * .75, sweep = math.pi * 1.5;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = p.track;
    c.drawArc(rect, start, sweep, false, track);
    final top = chronic == null || chronic! <= 0 ? null : chronic! * 2;
    if (top == null) return;
    double at(double v) => start + sweep * (v / top).clamp(0.0, 1.0);
    final ok = Rect.fromCircle(center: ctr, radius: r + 8);
    c.drawArc(ok, at(chronic! * kLoadLow), at(chronic! * kLoadHigh) - at(chronic! * kLoadLow), false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = p.on(C.green));
    if (acute == null) return;
    c.drawArc(rect, start, at(acute!) - start, false, track..color = p.on(color));
    final a = at(acute!);
    c.drawCircle(ctr + Offset(math.cos(a), math.sin(a)) * r, 7, Paint()..color = p.card);
    c.drawCircle(ctr + Offset(math.cos(a), math.sin(a)) * r, 7,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = p.on(color));
  }

  @override
  bool shouldRepaint(_Dial o) => true;
}

class _Card extends StatelessWidget {
  final String title, value, sub;
  final Widget? chart;
  final VoidCallback? onTap;
  const _Card({required this.title, required this.value, this.sub = '', this.chart, this.onTap});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return Surface(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: F.body.copyWith(color: p.ink, fontWeight: FontWeight.w600))),
          if (onTap != null) Icon(LucideIcons.arrowRight, size: 16, color: p.ink3),
        ]),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: F.n24.copyWith(color: p.ink)),
        ),
        if (sub.isNotEmpty) Text(uiText(c, sub), style: F.cap.copyWith(color: p.ink3)),
        if (chart != null) ...[const SizedBox(height: S.x3), SizedBox(height: 56, child: chart)],
      ]),
    );
  }
}

/// This week's running total against last week's, day by day.
class _Cumulative extends StatelessWidget {
  final List<double> now, last;
  final Color color;
  const _Cumulative(this.now, this.last, this.color);

  @override
  Widget build(BuildContext c) => CustomPaint(size: Size.infinite, painter: _CumPaint(now, last, color, P.of(c)));
}

class _CumPaint extends CustomPainter {
  final List<double> now, last;
  final Color color;
  final P p;
  _CumPaint(this.now, this.last, this.color, this.p);

  List<double> _cum(List<double> xs) {
    var a = 0.0;
    return [for (final x in xs) a += x];
  }

  @override
  void paint(Canvas c, Size s) {
    final a = _cum(now), b = _cum(last);
    final top = [...a, ...b, 1.0].reduce(math.max);
    Path path(List<double> xs) {
      final pth = Path();
      for (var i = 0; i < xs.length; i++) {
        final o = Offset(i / 6 * (s.width - 8), s.height - 4 - xs[i] / top * (s.height - 8));
        i == 0 ? pth.moveTo(o.dx, o.dy) : pth.lineTo(o.dx, o.dy);
      }
      return pth;
    }

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round;
    if (b.length == 7) c.drawPath(path(b), line..color = p.ink3);
    if (a.isNotEmpty) {
      c.drawPath(path(a), line..color = p.on(color));
      final i = a.length - 1;
      c.drawCircle(Offset(i / 6 * (s.width - 8), s.height - 4 - a[i] / top * (s.height - 8)), 4.5,
          Paint()..color = p.on(color));
    }
  }

  @override
  bool shouldRepaint(_CumPaint o) => true;
}

class _ZoneBars extends StatelessWidget {
  final List<double> z;
  const _ZoneBars(this.z);

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    const cols = [C.sky, C.blue, C.green, C.yellow, C.red];
    final top = z.reduce(math.max);
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 0; i < 5; i++) ...[
        if (i > 0) const SizedBox(width: S.x1),
        Expanded(
          child: FractionallySizedBox(
            heightFactor: top == 0 ? .04 : math.max(.04, z[i] / top),
            child: DecoratedBox(
              decoration: BoxDecoration(color: p.on(cols[i]), borderRadius: R.rSm),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// The body, each muscle filled by its estimated recovery, then the list.
class _MuscleCard extends StatelessWidget {
  final FitnessSummary s;
  final DateTime now;
  const _MuscleCard(this.s, this.now);

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final rec = muscleRecovery(s.doses, now);
    final rows = rec.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    String word(MuscleState st) => switch (st) {
          MuscleState.recovered => l?.fitRecovered ?? 'Recovered',
          MuscleState.fatigued => l?.fitFatigued ?? 'Fatigued',
          MuscleState.depleted => l?.fitDepleted ?? 'Depleted',
        };
    return Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l?.fitMuscleFreshness ?? 'Muscle freshness', style: F.head.copyWith(color: p.ink)),
        const SizedBox(height: S.x3),
        BodyMap(rec),
        const SizedBox(height: S.x3),
        Text(
          l?.fitRecoveryNote ??
              'An estimate from your logged sets: each session\'s fatigue halves every 24 hours, 36 when sets went to failure.',
          style: F.cap.copyWith(color: p.ink3),
        ),
        for (final e in rows) ...[
          const SizedBox(height: S.x3),
          Builder(builder: (c) {
            final st = muscleState(e.value);
            final col = p.on(kMuscleStateColor[st]!);
            final last = s.lastTrained[e.key];
            final h = last == null ? null : now.difference(last).inHours;
            final when = h == null
                ? null
                : (h < 24 ? (l?.fitToday ?? 'Today') : (l?.fitDaysAgo(h ~/ 24) ?? '${h ~/ 24} d ago'));
            return Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(uiText(c, e.key), style: F.body.copyWith(color: p.ink, fontWeight: FontWeight.w600)),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: word(st), style: TextStyle(color: col)),
                      TextSpan(text: ' · ${e.value.round()}%'),
                      if (when != null) TextSpan(text: ' · $when'),
                    ]),
                    style: F.cap.copyWith(color: p.ink2),
                  ),
                ]),
              ),
              const SizedBox(width: S.x2),
              RecoveryBar(e.value),
            ]);
          }),
        ],
      ]),
    );
  }
}
