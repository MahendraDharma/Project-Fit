// The top and the bottom of the Recovery, Sleep and Strain screens.
//
// TOP: the day's figure as one big ring over a tinted sky, the two numbers
// behind it as tiles, and one coaching sentence built from those same stored
// figures — nothing in it is a number this screen computed.
//
// BOTTOM: "Trends" — one card per metric, today's value, where it sits in the
// person's own usual range, and the last 30 days as a sparkline. A day the
// band did not measure may be filled by another device's reading from the
// health store (a Garmin through Garmin Connect); that point is drawn hollow
// and the card names the device. The usual range is built from the band's own
// days only, and an imported value is never placed against it.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/day_label.dart';
import '../../data/db.dart';
import '../../data/local_repository.dart';
import '../../health/health_readings_import.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/decimal_text.dart';
import '../../l10n/display_text.dart';
import '../ui2.dart';
import 'external_vitals.dart';
import 'home_screen.dart';
import 'home_vitals.dart';
import 'metric_detail.dart';
import 'body_battery.dart';
import 'garmin_stress.dart';
import 'month_calendar.dart';
import 'vo2_screen.dart';

enum DetailKind { recovery, sleep, strain }

/// What the top of a detail screen shows, loaded once.
class DetailTopData {
  final HomeData d;
  final HomeVitals v;
  const DetailTopData(this.d, this.v);

  static Future<DetailTopData> load(LocalRepository repo, String? day) async {
    final d = day == null ? await HomeData.load(repo) : await HomeData.loadForDay(repo, day);
    final v = await HomeVitals.load(repo, d.dayId ?? day ?? todayLabel());
    return DetailTopData(d, v);
  }
}

/// The sky, the ring, the tiles and the coaching line.
class DetailTop extends StatefulWidget {
  final DetailKind kind;
  final String? day;
  final DetailTopData? data;

  /// Space reserved above the ring for the screen's own bar.
  final double topInset;

  const DetailTop(this.kind, {super.key, this.day, this.data, this.topInset = 0});

  @override
  State<DetailTop> createState() => _DetailTopState();
}

class _DetailTopState extends State<DetailTop> {
  DetailTopData? _data;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    if (_data == null) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(DetailTop old) {
    super.didUpdateWidget(old);
    if (widget.data != null && widget.data != old.data) _data = widget.data;
  }

  Future<void> _load() async {
    final repo = repoOf(context);
    if (repo == null) return;
    try {
      final x = await DetailTopData.load(repo, widget.day);
      if (mounted) setState(() => _data = x);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext c) {
    final x = _data;
    final l = AppLocalizations.of(c);
    final tint = switch (widget.kind) {
      DetailKind.recovery => C.green,
      DetailKind.sleep => C.indigo,
      DetailKind.strain => C.orange,
    };
    final tiles = x == null ? const <DetailTile>[] : _tiles(x, l);
    final coach = x == null ? null : _coaching(x, l);
    return Column(children: [
      DetailHero(
        tint: tint,
        topInset: widget.topInset,
        onDate: () => go(
            c,
            MonthCalendarScreen(
                metric: switch (widget.kind) {
              DetailKind.recovery => CalendarMetric.recovery,
              DetailKind.sleep => CalendarMetric.sleep,
              DetailKind.strain => CalendarMetric.strain,
            })),
        date: prettyDay(x?.d.dayId ?? widget.day, l),
        ring: x == null ? const HeroRingSpec() : _ring(x, l),
      ),
      if (tiles.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.x4),
          child: DetailTiles(tiles),
        ),
      if (coach != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(S.x4, S.x3, S.x4, 0),
          child: CoachingCard(coach),
        ),
    ]);
  }

  HeroRingSpec _ring(DetailTopData x, AppLocalizations? l) {
    final d = x.d, v = x.v;
    switch (widget.kind) {
      case DetailKind.recovery:
        final r = d.readiness.value;
        if (r != null) {
          final band = readinessBand(r, l);
          return HeroRingSpec(
              frac: r / 100,
              colors: [C.greenD, band.color],
              value: '${r.round()}',
              suffix: '%',
              label: band.label);
        }
        if (v.recoveryNeed case final need?) {
          final have = v.recoveryHave ?? 0;
          return HeroRingSpec(
              dashes: need,
              filled: have,
              colors: const [C.greenD, C.green],
              value: '$have/$need',
              label: l?.detailCalibratingNights ?? 'nights calibrating');
        }
        return HeroRingSpec(label: l?.homeReadinessNotScored ?? 'Not scored');
      case DetailKind.sleep:
        final s = d.sleepMin.value, need = v.needMin ?? d.sleepNeedMin.value;
        if (s != null && need != null && need > 0) {
          return HeroRingSpec(
              frac: s / need,
              colors: const [C.indigo, C.blueSoft],
              value: '${(s / need * 100).round()}',
              suffix: '%',
              label: l?.detailOfNeed ?? 'of your need');
        }
        if (s != null) {
          return HeroRingSpec(
              frac: 0, colors: const [C.indigo, C.blueSoft], value: hm(s.toDouble()), label: '');
        }
        return HeroRingSpec(label: l?.homeRingNoSleep ?? 'No sleep');
      case DetailKind.strain:
        final s = d.strain.value;
        if (s == null) return HeroRingSpec(label: l?.detailNoStrain ?? 'No strain yet');
        return HeroRingSpec(
            frac: s / 21,
            colors: const [C.yellow, C.orange, C.red],
            value: displayFixed(s.toDouble(), 1),
            label: l?.homeStrainOf21 ?? 'of 21');
    }
  }

  List<DetailTile> _tiles(DetailTopData x, AppLocalizations? l) {
    final d = x.d, v = x.v;
    String? n(num? x) => x == null ? null : '${x.round()}';
    final out = switch (widget.kind) {
      DetailKind.recovery => [
          (LucideIcons.activity, l?.detailRestingHrv ?? 'Resting HRV', n(v.hrv), 'ms'),
          (LucideIcons.heart, l?.detailRestingHr ?? 'Resting HR', n(v.rhr ?? d.rhr.value), 'bpm'),
        ],
      DetailKind.sleep => [
          (
            LucideIcons.bedDouble,
            l?.detailTimeInBed ?? 'Time in bed',
            // Efficiency is stored as a fraction (0.91).
            v.sleepMin != null && (v.efficiency ?? 0) > 0
                ? hm(v.sleepMin! / v.efficiency!)
                : null,
            ''
          ),
          (LucideIcons.clock, l?.detailTimeAsleep ?? 'Time asleep',
              (v.sleepMin ?? d.sleepMin.value) == null ? null : hm((v.sleepMin ?? d.sleepMin.value)!.toDouble()), ''),
        ],
      DetailKind.strain => [
          (LucideIcons.heartPulse, l?.detailAvgHr ?? 'Average HR', n(v.hrAvg), 'bpm'),
          (LucideIcons.flame, l?.detailTotalEnergy ?? 'Total energy',
              d.caloriesTotal.value == null ? null : thousands(d.caloriesTotal.value!.toDouble()), 'kcal'),
        ],
    };
    return [
      for (final (ic, label, value, unit) in out)
        if (value != null) DetailTile(icon: ic, label: label, value: value, unit: unit),
    ];
  }

  String? _coaching(DetailTopData x, AppLocalizations? l) {
    final d = x.d, v = x.v;
    switch (widget.kind) {
      case DetailKind.recovery:
        final r = d.readiness.value;
        if (r != null) {
          final band = readinessBand(r, l).label;
          final rhr = v.rhr ?? d.rhr.value;
          return rhr == null
              ? band
              : (l?.detailCoachRecovery(band, '${rhr.round()}') ??
                  '$band. Resting heart rate ${rhr.round()} bpm last night.');
        }
        if (v.recoveryNeed case final need?) {
          final left = math.max(0, need - (v.recoveryHave ?? 0));
          return v.hrv == null
              ? (l?.detailCoachCalibrating(left) ??
                  'Recovery is scored once it has learned your normal: $left more nights.')
              : (l?.detailCoachCalibratingHrv(left, '${v.hrv!.round()}') ??
                  'Recovery is scored once it has learned your normal: $left more nights. Last night\'s HRV was ${v.hrv!.round()} ms.');
        }
        return null;
      case DetailKind.sleep:
        final s = v.sleepMin ?? d.sleepMin.value?.toDouble();
        if (s == null) return null;
        final need = v.needMin ?? d.sleepNeedMin.value?.toDouble();
        final parts = <String>[
          need == null
              ? (l?.detailCoachSlept(hm(s)) ?? 'You slept ${hm(s)}.')
              : (l?.detailCoachSleptOfNeed(hm(s), hm(need)) ??
                  'You slept ${hm(s)} of the ${hm(need)} you needed.'),
          if (v.debtMin case final debt? when debt >= 30)
            l?.detailCoachDebt(hm(debt)) ?? 'Sleep debt: ${hm(debt)}.',
          if (v.bedtimeMin case final bed?)
            l?.detailCoachBedtime(clock(bed)) ?? 'Aim to be in bed around ${clock(bed)} tonight.',
        ];
        return parts.join(' ');
      case DetailKind.strain:
        final s = d.strain.value;
        if (s == null) return null;
        final hard = v.zoneMin.length >= 5 ? (v.zoneMin[3] + v.zoneMin[4]).round() : null;
        return hard == null
            ? (l?.detailCoachStrain(displayFixed(s.toDouble(), 1)) ??
                'Strain ${displayFixed(s.toDouble(), 1)} of 21 today.')
            : (l?.detailCoachStrainZones(displayFixed(s.toDouble(), 1), hard) ??
                'Strain ${displayFixed(s.toDouble(), 1)} of 21 today, with $hard minutes in zones 4–5.');
    }
  }
}

/// What goes inside the hero ring.
class HeroRingSpec {
  final double? frac;
  final List<Color> colors;
  final int? dashes;
  final int filled;
  final String value, suffix, label;
  const HeroRingSpec({
    this.frac,
    this.colors = const [C.n400, C.n400],
    this.dashes,
    this.filled = 0,
    this.value = '–',
    this.suffix = '',
    this.label = '',
  });
}

/// The sky band: date, then the ring with its figure.
class DetailHero extends StatelessWidget {
  final Color tint;
  final String date;
  final HeroRingSpec ring;
  final double topInset;

  /// Opens the month. Null hides the chevron.
  final VoidCallback? onDate;
  const DetailHero(
      {super.key,
      required this.tint,
      required this.date,
      required this.ring,
      this.topInset = 0,
      this.onDate});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return CustomPaint(
      painter: _Sky(tint, p.bg, p.dark),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(S.x4, topInset + S.x2, S.x4, S.x8),
        child: Column(children: [
          Pressable(
            onTap: onDate,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                child: Text(date,
                    style: F.head.copyWith(color: p.ink2), textAlign: TextAlign.center),
              ),
              if (onDate != null) ...[
                const SizedBox(width: S.x1),
                Icon(LucideIcons.calendarDays, size: 18, color: p.ink2),
              ],
            ]),
          ),
          const SizedBox(height: S.x5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: AspectRatio(
              aspectRatio: 1,
              child: Semantics(
                label: '${ring.value}${ring.suffix} ${ring.label}',
                excludeSemantics: true,
                child: Stack(alignment: Alignment.center, children: [
                  Positioned.fill(child: CustomPaint(painter: _HeroRing(ring, p))),
                  FractionallySizedBox(
                    widthFactor: .56,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(ring.value, style: F.n48.copyWith(color: p.ink)),
                              if (ring.suffix.isNotEmpty)
                                Text(ring.suffix, style: F.n24.copyWith(color: p.ink)),
                            ]),
                        if (ring.label.isNotEmpty)
                          Text(ring.label, style: F.cap.copyWith(color: p.ink3)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// A tinted dusk sky fading into the page, with two soft ridges. Abstract on
/// purpose: no photograph, nobody's landscape.
class _Sky extends CustomPainter {
  final Color tint, bg;
  final bool dark;
  _Sky(this.tint, this.bg, this.dark);

  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    final top = Color.lerp(tint, dark ? C.n900 : C.white, dark ? .55 : .7)!;
    c.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, Color.lerp(tint, bg, .8)!, bg],
            stops: const [0, .6, 1],
          ).createShader(r));
    for (final (h, a) in [(.66, .14), (.76, .2)]) {
      final path = Path()..moveTo(0, s.height * h);
      for (var x = 0.0; x <= s.width; x += 6) {
        path.lineTo(x, s.height * h + math.sin(x / s.width * math.pi * h * 5) * 16 - math.cos(x / 53) * 5);
      }
      path
        ..lineTo(s.width, s.height)
        ..lineTo(0, s.height)
        ..close();
      c.drawPath(path, Paint()..color = Color.lerp(bg, tint, a)!.withValues(alpha: .7));
    }
  }

  @override
  bool shouldRepaint(_Sky o) => o.tint != tint || o.bg != bg;
}

class _HeroRing extends CustomPainter {
  final HeroRingSpec r;
  final P p;
  _HeroRing(this.r, this.p);

  @override
  void paint(Canvas c, Size s) {
    final ctr = s.center(Offset.zero);
    final rad = s.shortestSide / 2;
    c.drawCircle(ctr, rad, Paint()..color = p.card.withValues(alpha: .85));
    c.drawCircle(ctr, rad, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = p.line);
    final st = rad * .2;
    final rr = Rect.fromCircle(center: ctr, radius: rad - st / 2 - rad * .09);
    c.drawArc(rr, 0, 2 * math.pi, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = st..color = p.track);
    if (r.dashes case final n?) {
      final seg = 2 * math.pi / n;
      const gap = .06;
      for (var i = 0; i < n; i++) {
        c.drawArc(
            rr,
            -math.pi / 2 + i * seg + gap / 2,
            seg - gap,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = st
              ..color = i < r.filled ? r.colors.last : p.card2);
      }
    } else if ((r.frac ?? 0) > 0) {
      final sweep = 2 * math.pi * r.frac!.clamp(0.0, 1.0);
      c.drawArc(
          rr,
          -math.pi / 2,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = st + 8
            ..strokeCap = StrokeCap.round
            ..color = r.colors.last.withValues(alpha: .25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      c.drawArc(
          rr,
          -math.pi / 2,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = st
            // Butt, not round: a round cap at the start would show the
            // gradient's END colour wrapped back onto the top.
            ..strokeCap = StrokeCap.butt
            ..shader = SweepGradient(
              endAngle: math.max(sweep, .01),
              colors: r.colors,
              transform: const GradientRotation(-math.pi / 2),
            ).createShader(rr));
    }
    final inner = rad - st - rad * .2;
    c.drawCircle(ctr, inner, Paint()..color = p.card2);
  }

  @override
  bool shouldRepaint(_HeroRing o) => true;
}

/// One headline tile: a header strip with the name, the value under it.
class DetailTile {
  final IconData icon;
  final String label, value, unit;
  const DetailTile({required this.icon, required this.label, required this.value, this.unit = ''});
}

/// Two tiles side by side; stacked at large text.
class DetailTiles extends StatelessWidget {
  final List<DetailTile> tiles;
  const DetailTiles(this.tiles, {super.key});

  @override
  Widget build(BuildContext c) {
    final big = MediaQuery.textScalerOf(c).scale(10) > 14;
    final cells = [for (final t in tiles) _tile(c, t)];
    if (big || cells.length == 1) {
      return Column(children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(height: S.x3),
          cells[i],
        ],
      ]);
    }
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(width: S.x3),
          Expanded(child: cells[i]),
        ],
      ]),
    );
  }

  Widget _tile(BuildContext c, DetailTile t) {
    final p = P.of(c);
    return Container(
      decoration: BoxDecoration(color: p.card, borderRadius: p.cardRadius, boxShadow: p.el(1)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          color: p.card2.withValues(alpha: .5),
          padding: const EdgeInsets.fromLTRB(S.x4, S.x3, S.x3, S.x2),
          child: Row(children: [
            Icon(t.icon, size: 15, color: p.ink3),
            const SizedBox(width: S.x2),
            Expanded(child: Text(t.label, style: F.cap.copyWith(color: p.ink3))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(S.x4, S.x3, S.x3, S.x4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(t.value, style: F.n34.copyWith(color: p.ink)),
                  if (t.unit.isNotEmpty) ...[
                    const SizedBox(width: S.x1),
                    Text(uiText(c, t.unit), style: F.body.copyWith(color: p.ink3)),
                  ],
                ]),
          ),
        ),
      ]),
    );
  }
}

/// One coaching sentence, built from the screen's own stored figures.
class CoachingCard extends StatelessWidget {
  final String text;
  const CoachingCard(this.text, {super.key});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    return Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l?.detailCoaching ?? 'Coaching', style: F.cap.copyWith(color: p.ink3)),
        const SizedBox(height: S.x1),
        Text(text, style: F.body.copyWith(color: p.ink, height: 1.45)),
      ]),
    );
  }
}

/// Which metrics a screen's Trends section lists, and which health-store kind,
/// if any, may fill the days the band has nothing for.
typedef TrendSpec = ({String key, String? ext});

const kRecoveryTrends = <TrendSpec>[
  (key: 'readiness', ext: null),
  (key: 'hrv', ext: null),
  (key: 'resting_hr', ext: kKindRhr),
  (key: 'resp_rate', ext: kKindResp),
  (key: 'spo2', ext: kKindSpo2),
  (key: 'skin_temp', ext: null),
];
const kSleepTrends = <TrendSpec>[
  (key: 'sleep', ext: kKindSleepMin),
  (key: 'rem', ext: kKindSleepRem),
  (key: 'deep', ext: kKindSleepDeep),
  (key: 'efficiency', ext: null),
  (key: 'dip', ext: null),
];
const kStrainTrends = <TrendSpec>[
  (key: 'strain', ext: null),
  (key: 'calories', ext: null),
  (key: 'steps', ext: kKindStepsDay),
  (key: 'active_min', ext: null),
];

/// One loaded trend.
class TrendRow {
  final String key;
  final List<TrendPoint> points;
  final UsualRange? band;

  /// A name that is not the metric spec's — another device's series under a
  /// key ProjectFit also uses ("Garmin stress" is not our stress).
  final String? title;
  const TrendRow(this.key, this.points, this.band, {this.title});
}

/// The 30 days a card draws, ending [until].
const int kTrendCardDays = 30;

Future<List<TrendRow>> loadTrends(LocalRepository repo, List<TrendSpec> specs, String until) async {
  final u = DateTime.parse(until);
  final from = dayLabelOf(DateTime(u.year, u.month, u.day - (kTrendCardDays - 1)));
  final out = <TrendRow>[];
  for (final s in specs) {
    try {
      final m = await MetricData.load(repo, s.key);
      final own = <String, double>{
        for (final p in m.series)
          dayLabelOf(DateTime.fromMillisecondsSinceEpoch(p.t * 1000)): p.v,
      };
      final ext = s.ext == null
          ? const <String, ExternalDay>{}
          : await loadExternalDays(s.ext!, until: until, days: kTrendCardDays);
      final band = usualRangeFor(s.key, [for (final p in m.series) p.v], m.baselines);
      final pts = mergeWithExternal(own, ext)
          .where((p) => p.day.compareTo(from) >= 0 && p.day.compareTo(until) <= 0)
          .toList();
      if (pts.isNotEmpty) out.add(TrendRow(s.key, pts, band));
    } catch (_) {}
  }
  return out;
}

/// "Trends": a card per metric that has anything in the last 30 days.
class TrendSection extends StatefulWidget {
  final List<TrendSpec> specs;
  final String? until;
  final List<TrendRow>? rows;
  const TrendSection(this.specs, {super.key, this.until, this.rows});

  @override
  State<TrendSection> createState() => _TrendSectionState();
}

class _TrendSectionState extends State<TrendSection> {
  List<TrendRow>? _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.rows;
    if (_rows == null) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(TrendSection old) {
    super.didUpdateWidget(old);
    if (widget.rows != null && widget.rows != old.rows) _rows = widget.rows;
  }

  Future<void> _load() async {
    final repo = repoOf(context);
    if (repo == null) return;
    final rows = await loadTrends(repo, widget.specs, widget.until ?? todayLabel());
    if (mounted) setState(() => _rows = rows);
  }

  @override
  Widget build(BuildContext c) {
    final rows = _rows;
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(c);
    return Section(
      l?.detailTrends ?? 'Trends',
      Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: S.x3),
          MetricTrendCard(rows[i], onTap: () => go(c, MetricDetail(rows[i].key))),
        ],
      ]),
    );
  }
}

/// Today's value, its place in the usual range, and 30 days of it.
class MetricTrendCard extends StatelessWidget {
  final TrendRow row;
  final VoidCallback? onTap;
  const MetricTrendCard(this.row, {super.key, this.onTap});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final spec = specOf(row.key);
    final last = row.points.last;
    final unit = unitBeside(spec.unit);
    final color = p.on(spec.color);
    final (IconData stIcon, Color stColor, String stText) = _status(c, spec, last);
    final sources = {for (final p in row.points) ?p.source}.toList()..sort();
    final big = MediaQuery.textScalerOf(c).scale(10) > 14;

    final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(spec.icon, size: 16, color: p.ink3),
        const SizedBox(width: S.x2),
        Expanded(
          child: Text(row.title ?? uiText(c, spec.title), style: F.body.copyWith(color: p.ink3)),
        ),
      ]),
      const SizedBox(height: S.x3),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(metricValue(spec.unit, last.value), style: F.n34.copyWith(color: p.ink)),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: S.x1),
                Text(unit, style: F.body.copyWith(color: p.ink3)),
              ],
            ]),
      ),
      const SizedBox(height: S.x2),
      Row(children: [
        Icon(stIcon, size: 16, color: stColor),
        const SizedBox(width: S.x1),
        Flexible(child: Text(stText, style: F.cap.copyWith(color: stColor, fontWeight: FontWeight.w700))),
      ]),
    ]);
    final chart = SizedBox(
      height: 72,
      child: CustomPaint(
        size: Size.infinite,
        painter: _Spark(row.points, row.band, color, p),
      ),
    );
    return Surface(
      onTap: onTap,
      semanticLabel: '${row.title ?? uiText(c, spec.title)}, ${metricValue(spec.unit, last.value)} $unit, $stText',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (big) ...[left, const SizedBox(height: S.x3), chart]
        else
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(flex: 11, child: left),
            const SizedBox(width: S.x3),
            Expanded(flex: 9, child: chart),
          ]),
        if (sources.isNotEmpty) ...[
          const SizedBox(height: S.x3),
          Text(l?.dataFrom(sources.join(', ')) ?? 'Data from ${sources.join(', ')}',
              style: F.cap.copyWith(color: p.ink3)),
        ],
      ]),
    );
  }

  (IconData, Color, String) _status(BuildContext c, MetricSpec spec, TrendPoint last) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    if (last.source != null) {
      return (LucideIcons.watch, p.ink3, l?.detailFromOtherDevice ?? 'From another device');
    }
    final band = row.band;
    if (band == null) {
      return (LucideIcons.loaderCircle, p.ink3, l?.detailCalibrating ?? 'Calibrating');
    }
    final side = band.side(last.value);
    final better = betterDirection(row.key, higherBetter: spec.higherBetter);
    return switch (side) {
      Side.inside => (LucideIcons.circleCheck, p.on(C.green), l?.detailNormalRange ?? 'Normal range'),
      Side.above => (
          LucideIcons.circleArrowUp,
          better == null ? p.on(C.blue) : p.on(better ? C.green : C.orange),
          l?.detailAboveNormal ?? 'Above normal'
        ),
      Side.below => (
          LucideIcons.circleArrowDown,
          better == null ? p.on(C.blue) : p.on(better ? C.orange : C.green),
          l?.detailBelowNormal ?? 'Below normal'
        ),
    };
  }
}

/// 30 days as a line. The band's own days are solid dots; another device's
/// days are hollow. The usual range is a shaded strip; today's point glows.
class _Spark extends CustomPainter {
  final List<TrendPoint> pts;
  final UsualRange? band;
  final Color color;
  final P p;
  _Spark(this.pts, this.band, this.color, this.p);

  @override
  void paint(Canvas c, Size s) {
    if (pts.isEmpty) return;
    final vs = [for (final x in pts) x.value];
    var lo = vs.reduce(math.min), hi = vs.reduce(math.max);
    if (band case final b?) {
      lo = math.min(lo, b.lo);
      hi = math.max(hi, b.hi);
    }
    if (hi - lo < 1e-6) {
      hi += 1;
      lo -= 1;
    }
    const pad = 8.0;
    final end = DateTime.parse(pts.last.day);
    // The days actually held, at least a week wide: four nights spread over a
    // 30-day axis are a vertical scribble in the corner.
    final span = math.max(6.0, end.difference(DateTime.parse(pts.first.day)).inHours / 24);
    double x(String day) {
      final back = end.difference(DateTime.parse(day)).inHours / 24;
      return s.width - pad - (back / span) * (s.width - 2 * pad);
    }

    double y(double v) => s.height - pad - (v - lo) / (hi - lo) * (s.height - 2 * pad);
    if (band case final b?) {
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(0, y(b.hi), s.width - pad, y(b.lo)), const Radius.circular(R.sm)),
          Paint()..color = color.withValues(alpha: .16));
    }
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      // A gap of more than a day is a gap, not a line.
      if (DateTime.parse(b.day).difference(DateTime.parse(a.day)).inHours > 36) continue;
      c.drawLine(Offset(x(a.day), y(a.value)), Offset(x(b.day), y(b.value)),
          line..color = (a.source ?? b.source) == null ? color : color.withValues(alpha: .5));
    }
    for (var i = 0; i < pts.length; i++) {
      final pt = pts[i];
      final o = Offset(x(pt.day), y(pt.value));
      final lastOne = i == pts.length - 1;
      if (lastOne) {
        c.drawCircle(o, 10,
            Paint()..color = color.withValues(alpha: .3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      }
      final r = lastOne ? 6.0 : 3.0;
      if (pt.source == null && !lastOne) {
        c.drawCircle(o, r, Paint()..color = color);
      } else {
        c.drawCircle(o, r, Paint()..color = p.card);
        c.drawCircle(o, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(_Spark o) => true;
}

/// The newest reading per kind that another device put in the health store.
typedef OtherReading = ({String kind, double value, String source, int ts});

Future<List<OtherReading>> loadOtherReadings({DateTime? now}) async {
  final t = now ?? DateTime.now();
  // A week back: older than that is history, not "today's" picture.
  final from = DateTime(t.year, t.month, t.day - 7).millisecondsSinceEpoch ~/ 1000;
  final out = <OtherReading>[];
  // Garmin's Body Battery, read from the watch itself: today's newest sample.
  final bb = await LocalDb.vendorSeries(kBodyBatteryKey,
      DateTime(t.year, t.month, t.day).millisecondsSinceEpoch, t.millisecondsSinceEpoch + 1);
  if (bb.isNotEmpty) {
    out.add((
      kind: kBodyBatteryKey,
      value: (bb.last['value'] as num).toDouble(),
      source: bb.last['attribution'] as String,
      ts: (bb.last['ts_ms'] as num).toInt() ~/ 1000,
    ));
  }
  // Garmin's stress level: today's mean so far, over its samples.
  final st = await LocalDb.vendorSeries(kGarminStressKey,
      DateTime(t.year, t.month, t.day).millisecondsSinceEpoch, t.millisecondsSinceEpoch + 1);
  if (st.isNotEmpty) {
    out.add((
      kind: kGarminStressKey,
      value: st.fold<double>(0, (a, r) => a + (r['value'] as num)) / st.length,
      source: st.last['attribution'] as String,
      ts: (st.last['ts_ms'] as num).toInt() ~/ 1000,
    ));
  }
  for (final k in kReadingKindOrder) {
    final rows = await LocalDb.importedMeasurementsBetween(
        k, from, t.millisecondsSinceEpoch ~/ 1000 + 1);
    if (rows.isEmpty) continue;
    final r = rows.last;
    out.add((
      kind: k,
      value: (r['value'] as num).toDouble(),
      source: r['source'] as String,
      ts: (r['ts'] as num).toInt(),
    ));
  }
  return out;
}

/// "From your other devices" on Home: VO₂ max, SpO₂ and the rest, each with
/// the device that recorded it. Absent when nothing was read.
class OtherDevicesCard extends StatefulWidget {
  final List<OtherReading>? readings;
  const OtherDevicesCard({super.key, this.readings});

  @override
  State<OtherDevicesCard> createState() => _OtherDevicesCardState();
}

class _OtherDevicesCardState extends State<OtherDevicesCard> {
  List<OtherReading>? _r;

  @override
  void initState() {
    super.initState();
    _r = widget.readings;
    if (_r == null) {
      loadOtherReadings().then((r) {
        if (mounted) setState(() => _r = r);
      }, onError: (_) {});
    }
  }

  @override
  Widget build(BuildContext c) {
    final r = _r;
    if (r == null || r.isEmpty) return const SizedBox.shrink();
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final sources = {for (final x in r) x.source}.toList()..sort();
    return Section(
      l?.phoneImportOtherDevices ?? 'From your other devices',
      Surface(
        child: Column(children: [
          for (var i = 0; i < r.length; i++) ...[
            if (i > 0) Divider(color: p.line, height: S.x5),
            Pressable(
              onTap: switch (r[i].kind) {
                kKindVo2 => () => go(c, const Vo2MaxScreen()),
                kBodyBatteryKey => () => go(c, const BodyBatteryScreen()),
                kGarminStressKey => () => go(c, const GarminStressScreen()),
                _ => null,
              },
              child: Row(children: [
                Icon(readingIcon(r[i].kind), size: 18, color: p.ink3),
                const SizedBox(width: S.x2),
                Expanded(
                  child: Text(readingLabel(r[i].kind, l), style: F.body.copyWith(color: p.ink)),
                ),
                const SizedBox(width: S.x2),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(formatReading(r[i].kind, r[i].value),
                              style: F.n24.copyWith(color: p.ink)),
                          if (readingUnit(r[i].kind).isNotEmpty) ...[
                            const SizedBox(width: S.x1),
                            Text(readingUnit(r[i].kind), style: F.cap.copyWith(color: p.ink3)),
                          ],
                        ]),
                  ),
                ),
                if (r[i].kind == kKindVo2 ||
                    r[i].kind == kBodyBatteryKey ||
                    r[i].kind == kGarminStressKey)
                  Icon(LucideIcons.chevronRight, size: 16, color: p.ink3),
              ]),
            ),
          ],
          const SizedBox(height: S.x3),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(l?.dataFrom(sources.join(', ')) ?? 'Data from ${sources.join(', ')}',
                style: F.cap.copyWith(color: p.ink3)),
          ),
        ]),
      ),
    );
  }
}
