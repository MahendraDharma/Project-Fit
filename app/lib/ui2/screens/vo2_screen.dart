// VO₂ max, as the device that estimated it recorded it.
//
// The band does not estimate VO₂ max from a night or a day. What this screen
// shows is read from the health store (a Garmin through Garmin Connect, an
// Apple Watch), each point with its device named, and placed in the age and
// sex rating table the same device makers publish. The rating is a population
// percentile band, not a diagnosis and not one of this app's scores.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/db.dart';
import '../../data/local_repository.dart';
import '../../health/health_readings_import.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/date_text.dart';
import '../../l10n/decimal_text.dart';
import '../ui2.dart';
import 'home_screen.dart';
import 'metric_detail.dart' show detailScaffold;

/// The Cooper Institute's VO₂ max ratings (mL/kg/min) as printed in Garmin's
/// owner's manuals ("VO2 Max. Standard Ratings"): the lower edge of Fair,
/// Good, Excellent and Superior — the 40th, 60th, 80th and 95th percentiles —
/// per ten-year age band from 20–29 to 70–79. Below Fair is Poor.
const Map<String, List<List<double>>> kVo2Norms = {
  'm': [
    [41.7, 45.4, 51.1, 55.4],
    [40.5, 44.0, 48.3, 54.0],
    [38.5, 42.4, 46.4, 52.5],
    [35.6, 39.2, 43.4, 48.9],
    [32.3, 35.5, 39.5, 45.7],
    [29.4, 32.3, 36.7, 42.1],
  ],
  'f': [
    [36.1, 39.5, 43.9, 49.6],
    [34.4, 37.8, 42.4, 47.4],
    [33.0, 36.3, 39.7, 45.3],
    [30.1, 33.0, 36.7, 41.1],
    [27.5, 30.0, 33.0, 37.8],
    [25.9, 28.1, 30.9, 36.7],
  ],
};

/// The four cut points for [sex] ('m'/'f', or anything starting with one) at
/// [age], or null when either is unknown. Under 20 uses 20–29 and over 79
/// uses 70–79, the table's own ends.
List<double>? vo2Cuts(String? sex, int? age) {
  final s = sex?.toLowerCase();
  final key = s == null ? null : (s.startsWith('f') ? 'f' : (s.startsWith('m') ? 'm' : null));
  if (key == null || age == null) return null;
  final band = ((age - 20) ~/ 10).clamp(0, 5);
  return kVo2Norms[key]![band];
}

/// 0 Poor, 1 Fair, 2 Good, 3 Excellent, 4 Superior.
int vo2Tier(double v, List<double> cuts) => cuts.where((c) => v >= c).length;

/// One stored reading.
typedef Vo2Point = ({DateTime at, double value, String source});

class Vo2Data {
  final List<Vo2Point> points;
  final String? sex;
  final int? age;
  const Vo2Data({this.points = const [], this.sex, this.age});

  static Future<Vo2Data> load(LocalRepository repo) async {
    final now = DateTime.now();
    final rows = await LocalDb.importedMeasurementsBetween(
        kKindVo2, 0, now.millisecondsSinceEpoch ~/ 1000 + 1);
    final profile = await repo.getProfile();
    return Vo2Data(
      points: [
        for (final r in rows)
          (
            at: DateTime.fromMillisecondsSinceEpoch((r['ts'] as num).toInt() * 1000),
            value: (r['value'] as num).toDouble(),
            source: r['source'] as String,
          ),
      ],
      sex: profile['sex']?.toString(),
      age: (profile['age'] as num?)?.toInt(),
    );
  }
}

class Vo2MaxScreen extends StatefulWidget {
  final Vo2Data? data;
  const Vo2MaxScreen({super.key, this.data});

  @override
  State<Vo2MaxScreen> createState() => _Vo2MaxScreenState();
}

/// Days shown per range tab.
const List<int> kVo2RangeDays = [30, 91, 182, 365];

class _Vo2MaxScreenState extends State<Vo2MaxScreen> {
  Vo2Data? _d;
  int _range = 1;

  @override
  void initState() {
    super.initState();
    _d = widget.data;
    if (_d == null) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repo = repoOf(context);
    if (repo == null) {
      if (mounted) setState(() => _d = const Vo2Data());
      return;
    }
    try {
      final d = await Vo2Data.load(repo);
      if (mounted) setState(() => _d = d);
    } catch (_) {
      if (mounted) setState(() => _d = const Vo2Data());
    }
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final d = _d;
    final title = l?.readingVo2 ?? 'VO₂ max';
    if (d == null) {
      return detailScaffold(c, title, const [
        SizedBox(height: S.x8),
        Center(child: CircularProgressIndicator()),
      ]);
    }
    final about = Section(
      l?.vo2WhatIs ?? 'What is VO₂ max?',
      Surface(
        child: Text(
          l?.vo2WhatIsBody ??
              'The most oxygen your body can use in hard exercise, per kilogram, per minute. It is one of the best single measures of aerobic fitness, and it rises with regular endurance training.',
          style: F.body.copyWith(color: p.ink2, height: 1.45),
        ),
      ),
    );
    if (d.points.isEmpty) {
      return detailScaffold(c, title, [
        StatusCard(
          l?.vo2NoneTitle ?? 'No VO₂ max yet',
          l?.vo2NoneBody ??
              'A watch that estimates VO₂ max (a Garmin, an Apple Watch) writes it to Apple Health. Read it on Profile › From your phone.',
          icon: LucideIcons.wind,
        ),
        about,
      ]);
    }
    final last = d.points.last;
    final cuts = vo2Cuts(d.sex, d.age);
    final tier = cuts == null ? null : vo2Tier(last.value, cuts);
    final tierNames = [
      l?.vo2Poor ?? 'Poor',
      l?.vo2Fair ?? 'Fair',
      l?.vo2Good ?? 'Good',
      l?.vo2Excellent ?? 'Excellent',
      l?.vo2Superior ?? 'Superior',
    ];
    const tierColors = [C.red, C.orange, C.yellow, C.green, C.teal];
    final from = DateTime(last.at.year, last.at.month, last.at.day - kVo2RangeDays[_range] + 1);
    final shown = [for (final x in d.points) if (!x.at.isBefore(from)) x];
    final sources = {for (final x in shown) x.source}.toList()..sort();
    final loc = l?.localeName ?? 'en';

    return detailScaffold(c, title, [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(displayFixed(last.value, 1), style: F.n48.copyWith(color: p.ink)),
            Text(localizedDate(last.at, loc, pattern: 'd MMM yyyy'),
                style: F.body.copyWith(color: p.ink3)),
          ]),
        ),
        if (tier != null)
          Text(tierNames[tier], style: F.t2.copyWith(color: p.on(tierColors[tier]))),
      ]),
      const SizedBox(height: S.x4),
      SizedBox(
        height: 220,
        child: CustomPaint(
          size: Size.infinite,
          painter: _Vo2Chart(shown, from, last.at, p, cuts),
        ),
      ),
      const SizedBox(height: S.x3),
      SubTabs(
        [l?.range30d ?? '30D', l?.range3m ?? '3M', l?.range6m ?? '6M', l?.range1y ?? '1Y'],
        _range,
        (i) => setState(() => _range = i),
        color: C.orange,
      ),
      const SizedBox(height: S.x5),
      if (cuts != null && tier != null)
        Surface(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _TierBar(cuts: cuts, tier: tier, colors: tierColors),
            const SizedBox(height: S.x4),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: l?.vo2YourRange ?? 'Your range is '),
                TextSpan(
                    text: tierNames[tier],
                    style: TextStyle(color: p.on(tierColors[tier]))),
              ]),
              style: F.head.copyWith(color: p.ink),
            ),
            const SizedBox(height: S.x1),
            Text(
              _cohort(l, d),
              style: F.body.copyWith(color: p.ink2),
            ),
            const SizedBox(height: S.x1),
            Text(
              l?.vo2NormsSource ?? 'Ratings: The Cooper Institute, as published by Garmin.',
              style: F.cap.copyWith(color: p.ink3),
            ),
          ]),
        )
      else
        StatusCard(
          l?.vo2NoProfileTitle ?? 'No rating without your age and sex',
          l?.vo2NoProfileBody ??
              'The ratings differ by age and sex. Add both on Edit profile to see where this sits.',
          icon: LucideIcons.user,
        ),
      if (sources.isNotEmpty) ...[
        const SizedBox(height: S.x3),
        Text(l?.dataFrom(sources.join(', ')) ?? 'Data from ${sources.join(', ')}',
            style: F.cap.copyWith(color: p.ink3), textAlign: TextAlign.end),
      ],
      about,
    ]);
  }

  String _cohort(AppLocalizations? l, Vo2Data d) {
    final lo = 20 + ((d.age! - 20) ~/ 10).clamp(0, 5) * 10;
    final female = d.sex!.toLowerCase().startsWith('f');
    return female
        ? (l?.vo2CohortFemale(lo, lo + 9) ?? 'Standardised for women aged $lo–${lo + 9}')
        : (l?.vo2CohortMale(lo, lo + 9) ?? 'Standardised for men aged $lo–${lo + 9}');
  }
}

/// Five segments, the person's own lit, a marker above it.
class _TierBar extends StatelessWidget {
  final List<double> cuts;
  final int tier;
  final List<Color> colors;
  const _TierBar({required this.cuts, required this.tier, required this.colors});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final labels = [
      '<${displayFixed(cuts[0], 1)}',
      for (final x in cuts) displayFixed(x, 1),
    ];
    return Row(children: [
      for (var i = 0; i < 5; i++) ...[
        if (i > 0) const SizedBox(width: S.x1),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(LucideIcons.triangle,
                size: 10, color: i == tier ? p.ink : Colors.transparent),
            const SizedBox(height: S.x1),
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: i == tier ? colors[i] : colors[i].withValues(alpha: .25),
                borderRadius: R.rPill,
              ),
            ),
            const SizedBox(height: S.x1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(labels[i], style: F.cap.copyWith(color: p.ink3)),
            ),
          ]),
        ),
      ],
    ]);
  }
}

class _Vo2Chart extends CustomPainter {
  final List<Vo2Point> pts;
  final DateTime from, to;
  final P p;
  final List<double>? cuts;
  _Vo2Chart(this.pts, this.from, this.to, this.p, this.cuts);

  @override
  void paint(Canvas c, Size s) {
    final label = TextPainter(textDirection: TextDirection.ltr);
    const right = 40.0, pad = 10.0;
    final vs = [for (final x in pts) x.value];
    var lo = vs.isEmpty ? 30.0 : vs.reduce(math.min) - 5;
    var hi = vs.isEmpty ? 50.0 : vs.reduce(math.max) + 5;
    if (hi - lo < 10) {
      final m = (hi + lo) / 2;
      lo = m - 5;
      hi = m + 5;
    }
    final w = s.width - right;
    double y(double v) => pad + (hi - v) / (hi - lo) * (s.height - 2 * pad);
    final span = math.max(1, to.difference(from).inHours);
    double x(DateTime t) => pad + t.difference(from).inHours / span * (w - 2 * pad);
    final grid = Paint()..color = p.line..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final v = lo + (hi - lo) * i / 3;
      c.drawLine(Offset(0, y(v)), Offset(w, y(v)), grid);
      label
        ..text = TextSpan(text: displayFixed(v, 1), style: F.cap.copyWith(color: p.ink3))
        ..layout();
      label.paint(c, Offset(w + 4, y(v) - label.height / 2));
    }
    if (pts.isEmpty) return;
    final col = p.on(C.orange);
    final path = Path()..moveTo(x(pts.first.at), y(pts.first.value));
    for (final q in pts.skip(1)) {
      path.lineTo(x(q.at), y(q.value));
    }
    c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.4..color = col);
    for (var i = 0; i < pts.length; i++) {
      final o = Offset(x(pts[i].at), y(pts[i].value));
      final last = i == pts.length - 1;
      if (last) {
        c.drawCircle(o, 11,
            Paint()..color = col.withValues(alpha: .3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      }
      c.drawCircle(o, last ? 6 : 4, Paint()..color = last ? col : p.card);
      c.drawCircle(o, last ? 6 : 4, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = col);
    }
  }

  @override
  bool shouldRepaint(_Vo2Chart o) => true;
}
