// Garmin's Body Battery, shown as Garmin's.
//
// ProjectFit does not compute a body battery and will not (see the guard on
// `_daytimeHrv` in derivation_engine.dart: the composite has no published,
// validated method). What a paired Garmin watch stores in its own FIT files
// is read over Bluetooth and shown here with its name on it. The sums and the
// "usual at this time" line are plain arithmetic over Garmin's own samples.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/day_label.dart';
import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/date_text.dart';
import '../ui2.dart';
import 'home_screen.dart' show clock;
import 'metric_detail.dart' show detailScaffold;

const String kBodyBatteryKey = 'body_battery';

/// One stored sample: unix seconds and Garmin's 0-100.
typedef BbPoint = ({int t, int v});

class BodyBatteryData {
  final String day;
  final List<BbPoint> today;

  /// Earlier days' samples, by day, for "usual at this time".
  final Map<String, List<BbPoint>> before;
  final String source;
  const BodyBatteryData(
      {required this.day, this.today = const [], this.before = const {}, this.source = 'Garmin'});

  static Future<BodyBatteryData> load(String day, {int history = 14}) async {
    final d = DateTime.parse(day);
    final from = DateTime(d.year, d.month, d.day - history).millisecondsSinceEpoch;
    final to = DateTime(d.year, d.month, d.day + 1).millisecondsSinceEpoch;
    final rows = await LocalDb.vendorSeries(kBodyBatteryKey, from, to);
    final today = <BbPoint>[];
    final before = <String, List<BbPoint>>{};
    var source = 'Garmin';
    for (final r in rows) {
      final ms = (r['ts_ms'] as num).toInt();
      final p = (t: ms ~/ 1000, v: (r['value'] as num).round());
      final label = dayLabelOf(DateTime.fromMillisecondsSinceEpoch(ms));
      source = (r['attribution'] as String?) ?? source;
      if (label == day) {
        today.add(p);
      } else {
        (before[label] ??= []).add(p);
      }
    }
    return BodyBatteryData(day: day, today: today, before: before, source: source);
  }

  int? get latest => today.isEmpty ? null : today.last.v;

  /// Sum of rises and sum of falls between consecutive samples.
  (int, int) get chargedDrained {
    var up = 0, down = 0;
    for (var i = 1; i < today.length; i++) {
      final d = today[i].v - today[i - 1].v;
      if (d > 0) up += d;
      if (d < 0) down -= d;
    }
    return (up, down);
  }

  BbPoint? get peak => today.isEmpty ? null : today.reduce((a, b) => b.v >= a.v ? b : a);

  /// The mean of earlier days' value at the latest sample's time of day,
  /// each day's nearest sample within 20 minutes. Null under three days.
  double? get usualNow {
    if (today.isEmpty) return null;
    final at = DateTime.fromMillisecondsSinceEpoch(today.last.t * 1000);
    final secOfDay = at.hour * 3600 + at.minute * 60;
    final vs = <int>[];
    for (final pts in before.values) {
      BbPoint? best;
      var gap = 1 << 30;
      for (final p in pts) {
        final t = DateTime.fromMillisecondsSinceEpoch(p.t * 1000);
        final g = (t.hour * 3600 + t.minute * 60 - secOfDay).abs();
        if (g < gap) (best, gap) = (p, g);
      }
      if (best != null && gap <= 20 * 60) vs.add(best.v);
    }
    return vs.length < 3 ? null : vs.reduce((a, b) => a + b) / vs.length;
  }
}

class BodyBatteryScreen extends StatefulWidget {
  final String? day;
  final BodyBatteryData? data;
  const BodyBatteryScreen({super.key, this.day, this.data});

  @override
  State<BodyBatteryScreen> createState() => _BodyBatteryScreenState();
}

class _BodyBatteryScreenState extends State<BodyBatteryScreen> with RevisionReload {
  BodyBatteryData? _d;

  @override
  void initState() {
    super.initState();
    _d = widget.data;
    if (_d == null) reload();
  }

  // Re-read when a sync lands the watch's samples while this screen is open.
  @override
  bool get revisionReloads => widget.data == null;

  @override
  void reload() {
    final t = beginRead(#bb);
    BodyBatteryData.load(widget.day ?? todayLabel()).then((d) {
      if (stillNewest(#bb, t)) setState(() => _d = d);
    }, onError: (_) {
      if (stillNewest(#bb, t)) setState(() => _d = BodyBatteryData(day: widget.day ?? todayLabel()));
    });
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final d = _d;
    final title = l?.bbTitle ?? 'Body Battery';
    if (d == null) {
      return detailScaffold(c, title, const [
        SizedBox(height: S.x8),
        Center(child: CircularProgressIndicator()),
      ]);
    }
    final loc = l?.localeName ?? 'en';
    final note = Text(
      l?.bbNote(d.source) ??
          '${d.source}\'s own number, read from the watch. Its method is not published, and ProjectFit does not compute one.',
      style: F.cap.copyWith(color: p.ink3, height: 1.5),
    );
    final v = d.latest;
    if (v == null) {
      return detailScaffold(c, title, [
        StatusCard(
          l?.bbNoneTitle ?? 'No Body Battery for this day',
          l?.bbNoneBody ??
              'It comes from a Garmin watch paired on Devices: the watch keeps it in its own files, and they are read over Bluetooth when it syncs.',
          icon: LucideIcons.batteryCharging,
        ),
        const SizedBox(height: S.x3),
        note,
      ]);
    }
    final (up, down) = d.chargedDrained;
    final peak = d.peak!;
    final usual = d.usualNow;
    final lastAt = DateTime.fromMillisecondsSinceEpoch(d.today.last.t * 1000);
    String hhmm(int t) {
      final x = DateTime.fromMillisecondsSinceEpoch(t * 1000);
      return clock(x.hour * 60 + x.minute);
    }

    return detailScaffold(c, title, sub: localizedDate(DateTime.parse(d.day), loc, pattern: 'd MMMM yyyy'), [
      const SizedBox(height: S.x4),
      Center(child: _Battery(v)),
      const SizedBox(height: S.x3),
      Center(
        child: Text(
          l?.bbPeak(peak.v, hhmm(peak.t)) ?? 'Highest today: ${peak.v}% at ${hhmm(peak.t)}',
          style: F.body.copyWith(color: p.ink2),
        ),
      ),
      const SizedBox(height: S.x5),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _Sum('+$up', l?.bbCharged ?? 'Charged', p.on(C.green))),
          const SizedBox(width: S.x3),
          Expanded(child: _Sum('−$down', l?.bbDrained ?? 'Drained', p.on(C.red))),
        ]),
      ),
      if (usual != null) ...[
        const SizedBox(height: S.x3),
        Surface(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l?.detailCoaching ?? 'Coaching', style: F.cap.copyWith(color: p.ink3)),
            const SizedBox(height: S.x1),
            Text(
              _vsUsual(l, v - usual, clock(lastAt.hour * 60 + lastAt.minute)),
              style: F.body.copyWith(color: p.ink, height: 1.45),
            ),
          ]),
        ),
      ],
      Section(
        l?.bbLevel ?? 'Level through the day',
        Surface(
          child: SizedBox(
            height: 200,
            child: CustomPaint(size: Size.infinite, painter: _Curve(d.today, d.day, p)),
          ),
        ),
      ),
      const SizedBox(height: S.x3),
      Text(l?.dataFrom(d.source) ?? 'Data from ${d.source}',
          style: F.cap.copyWith(color: p.ink3)),
      const SizedBox(height: S.x2),
      note,
    ]);
  }

  String _vsUsual(AppLocalizations? l, double diff, String at) {
    final n = diff.abs().round();
    if (n < 3) return l?.bbUsualSame(at) ?? 'About where it usually is at $at.';
    return diff > 0
        ? (l?.bbUsualHigher(n, at) ?? '$n points higher than usual at $at.')
        : (l?.bbUsualLower(n, at) ?? '$n points lower than usual at $at.');
  }
}

class _Sum extends StatelessWidget {
  final String value, label;
  final Color color;
  const _Sum(this.value, this.label, this.color);

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return Surface(
      child: Column(children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: F.n34.copyWith(color: color))),
        Text(label, style: F.body.copyWith(color: p.ink), textAlign: TextAlign.center),
      ]),
    );
  }
}

/// A battery: an outlined body, filled to the level, the number on it.
class _Battery extends StatelessWidget {
  final int v;
  const _Battery(this.v);

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final col = v >= 50 ? C.green : (v >= 25 ? C.yellow : C.red);
    return Semantics(
      label: '$v%',
      excludeSemantics: true,
      child: SizedBox(
        width: 220,
        height: 110,
        child: Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(S.x2),
              decoration: BoxDecoration(
                borderRadius: R.rXl,
                border: Border.all(color: p.line, width: 3),
                color: p.card,
              ),
              child: ClipRRect(
                borderRadius: R.rLg,
                child: Stack(fit: StackFit.expand, children: [
                  ColoredBox(color: col.withValues(alpha: .18)),
                  DrawIn(
                    builder: (_, t) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (v / 100 * t).clamp(0.0, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [col, Color.lerp(col, p.bg, .25)!],
                        ),
                      ),
                    ),
                  ),
                  ),
                  Center(
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('$v', style: F.n48.copyWith(color: p.ink)),
                          Text('%', style: F.n24.copyWith(color: p.ink)),
                        ]),
                  ),
                ]),
              ),
            ),
          ),
          Container(
            width: 8,
            height: 36,
            decoration: BoxDecoration(color: p.line, borderRadius: R.rSm),
          ),
        ]),
      ),
    );
  }
}

/// The day, midnight to midnight, 0-100, filled under the line.
class _Curve extends CustomPainter {
  final List<BbPoint> pts;
  final String day;
  final P p;
  _Curve(this.pts, this.day, this.p);

  @override
  void paint(Canvas c, Size s) {
    final d = DateTime.parse(day);
    final start = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 1000;
    const right = 30.0, bottom = 18.0;
    final w = s.width - right, h = s.height - bottom;
    double x(int t) => (t - start) / 86400 * w;
    double y(num v) => h - v / 100 * h;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final v in [0, 25, 50, 75, 100]) {
      c.drawLine(Offset(0, y(v)), Offset(w, y(v)), Paint()..color = p.line..strokeWidth = 1);
      tp
        ..text = TextSpan(text: '$v', style: F.cap.copyWith(color: p.ink3))
        ..layout();
      tp.paint(c, Offset(w + 4, y(v) - tp.height / 2));
    }
    for (final hr in [0, 6, 12, 18]) {
      tp
        ..text = TextSpan(text: clock(hr * 60), style: F.cap.copyWith(color: p.ink3))
        ..layout();
      tp.paint(c, Offset(math.min(hr / 24 * w, w - tp.width), h + 2));
    }
    if (pts.length < 2) return;
    final line = Path()..moveTo(x(pts.first.t), y(pts.first.v));
    for (var i = 1; i < pts.length; i++) {
      // Off the wrist for over half an hour: a gap, not a slope.
      if (pts[i].t - pts[i - 1].t > 1800) {
        line.moveTo(x(pts[i].t), y(pts[i].v));
      } else {
        line.lineTo(x(pts[i].t), y(pts[i].v));
      }
    }
    final fill = Path.from(line)
      ..lineTo(x(pts.last.t), h)
      ..lineTo(x(pts.first.t), h)
      ..close();
    c.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [C.green.withValues(alpha: .35), C.green.withValues(alpha: .02)],
          ).createShader(Rect.fromLTWH(0, 0, w, h)));
    c.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeJoin = StrokeJoin.round
          ..color = p.on(C.green));
    final e = Offset(x(pts.last.t), y(pts.last.v));
    c.drawCircle(e, 6, Paint()..color = p.on(C.green));
  }

  @override
  bool shouldRepaint(_Curve o) => true;
}
