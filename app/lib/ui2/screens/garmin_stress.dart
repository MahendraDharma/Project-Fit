// Garmin's all-day stress, shown as Garmin's.
//
// ProjectFit keeps no daytime stress score of its own (see the guard on
// `_daytimeHrv` in derivation_engine.dart); its only stress figure is the
// nightly Baevsky index. A paired Garmin watch stores its own 0-100 level in
// its FIT files, and this screen draws those samples, attributed. The bands
// are Garmin's published ones: 0-25 rest, 26-50 low, 51-75 medium, 76-100
// high. Durations, means and "usual" are plain arithmetic over its samples.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/day_label.dart';
import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/date_text.dart';
import '../ui2.dart';
import 'detail_v4.dart';
import 'external_vitals.dart' show TrendPoint;
import 'home_screen.dart' show clock, repoOf;
import 'home_vitals.dart';
import 'metric_detail.dart' show detailScaffold;

const String kGarminStressKey = 'stress_level';

/// Garmin's band of a 0-100 level: 0 rest, 1 low, 2 medium, 3 high.
int stressBand(num v) => v <= 25 ? 0 : (v <= 50 ? 1 : (v <= 75 ? 2 : 3));

const List<Color> kStressBandColors = [C.teal, C.green, C.yellow, C.red];

typedef StressPoint = ({int t, int v});

class GarminStressData {
  final String day;
  final List<StressPoint> today;

  /// Earlier days' mean level, by day.
  final Map<String, double> dailyMeans;
  final String source;
  final HomeVitals? vitals;
  const GarminStressData(
      {required this.day,
      this.today = const [],
      this.dailyMeans = const {},
      this.source = 'Garmin',
      this.vitals});

  static Future<GarminStressData> load(String day, {HomeVitals? vitals}) async {
    final d = DateTime.parse(day);
    final from = DateTime(d.year, d.month, d.day - 29).millisecondsSinceEpoch;
    final to = DateTime(d.year, d.month, d.day + 1).millisecondsSinceEpoch;
    final rows = await LocalDb.vendorSeries(kGarminStressKey, from, to);
    final today = <StressPoint>[];
    final sums = <String, (double, int)>{};
    var source = 'Garmin';
    for (final r in rows) {
      final ms = (r['ts_ms'] as num).toInt();
      final v = (r['value'] as num).round();
      final label = dayLabelOf(DateTime.fromMillisecondsSinceEpoch(ms));
      source = (r['attribution'] as String?) ?? source;
      if (label == day) today.add((t: ms ~/ 1000, v: v));
      final (sum, n) = sums[label] ?? (0.0, 0);
      sums[label] = (sum + v, n + 1);
    }
    return GarminStressData(
      day: day,
      today: today,
      dailyMeans: {for (final e in sums.entries) e.key: e.value.$1 / e.value.$2},
      source: source,
      vitals: vitals,
    );
  }

  double? get mean => dailyMeans[day];

  /// Mean of the earlier days, under three days null.
  double? get usual {
    final xs = [for (final e in dailyMeans.entries) if (e.key != day) e.value];
    return xs.length < 3 ? null : xs.reduce((a, b) => a + b) / xs.length;
  }

  /// Seconds in each band: each sample holds until the next, at most five
  /// minutes (a longer gap is the watch off the wrist), the last three.
  List<int> get bandSeconds {
    final out = [0, 0, 0, 0];
    for (var i = 0; i < today.length; i++) {
      final span = i + 1 < today.length ? (today[i + 1].t - today[i].t).clamp(0, 300) : 180;
      out[stressBand(today[i].v)] += span;
    }
    return out;
  }
}

class GarminStressScreen extends StatefulWidget {
  final String? day;
  final GarminStressData? data;
  const GarminStressScreen({super.key, this.day, this.data});

  @override
  State<GarminStressScreen> createState() => _GarminStressScreenState();
}

class _GarminStressScreenState extends State<GarminStressScreen> {
  GarminStressData? _d;

  @override
  void initState() {
    super.initState();
    _d = widget.data;
    if (_d == null) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final day = widget.day ?? todayLabel();
    HomeVitals? v;
    final repo = repoOf(context);
    if (repo != null) {
      try {
        v = await HomeVitals.load(repo, day);
      } catch (_) {}
    }
    try {
      final d = await GarminStressData.load(day, vitals: v);
      if (mounted) setState(() => _d = d);
    } catch (_) {
      if (mounted) setState(() => _d = GarminStressData(day: day));
    }
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final d = _d;
    final title = l?.gsTitle ?? 'Stress';
    if (d == null) {
      return detailScaffold(c, title, const [
        SizedBox(height: S.x8),
        Center(child: CircularProgressIndicator()),
      ]);
    }
    final note = Text(
      l?.gsNote(d.source) ??
          '${d.source}\'s own all-day stress level, read from the watch. ProjectFit keeps no daytime stress score of its own.',
      style: F.cap.copyWith(color: p.ink3, height: 1.5),
    );
    final mean = d.mean;
    if (mean == null || d.today.isEmpty) {
      return detailScaffold(c, title, [
        StatusCard(
          l?.gsNoneTitle ?? 'No stress level for this day',
          l?.bbNoneBody ??
              'It comes from a Garmin watch paired on Devices: the watch keeps it in its own files, and they are read over Bluetooth when it syncs.',
          icon: LucideIcons.gauge,
        ),
        const SizedBox(height: S.x3),
        note,
      ]);
    }
    final names = [
      l?.gsRest ?? 'Rest',
      l?.gsLow ?? 'Low',
      l?.gsMedium ?? 'Medium',
      l?.gsHigh ?? 'High',
    ];
    final band = stressBand(mean);
    final secs = d.bandSeconds;
    final total = secs.fold(0, (a, b) => a + b);
    final usual = d.usual;
    final v = d.vitals;
    final tiles = [
      if (v?.hrv case final hrv?)
        DetailTile(icon: LucideIcons.activity, label: l?.detailRestingHrv ?? 'Resting HRV', value: '${hrv.round()}', unit: 'ms'),
      if (v?.hrAvg case final hr?)
        DetailTile(icon: LucideIcons.heart, label: l?.detailAvgHr ?? 'Average HR', value: '$hr', unit: 'bpm'),
    ];
    String dur(int s) => '${s ~/ 3600}:${((s % 3600) ~/ 60).toString().padLeft(2, '0')}';

    return detailScaffold(
      c,
      title,
      hero: (t) => DetailHero(
        tint: C.purple,
        topInset: t,
        date: localizedDate(DateTime.parse(d.day), l?.localeName ?? 'en', pattern: 'd MMMM yyyy'),
        ring: HeroRingSpec(
          frac: mean / 100,
          colors: [C.teal, kStressBandColors[band]],
          value: '${mean.round()}',
          label: names[band],
        ),
      ),
      [
        if (tiles.isNotEmpty) DetailTiles(tiles),
        if (usual != null) ...[
          const SizedBox(height: S.x3),
          CoachingCard(_vsUsual(l, mean - usual)),
        ],
        Section(
          l?.gsToday ?? 'Through the day',
          Surface(
            child: SizedBox(
              height: 200,
              child: CustomPaint(
                size: Size.infinite,
                painter: _StressCurve(d.today, d.day, p, v?.onsetTs, v?.wakeTs),
              ),
            ),
          ),
        ),
        const SizedBox(height: S.x3),
        for (var b = 3; b >= 0; b--) ...[
          Surface(
            child: Row(children: [
              SizedBox(width: 76, child: Text(names[b], style: F.body.copyWith(color: p.ink))),
              Expanded(
                child: ClipRRect(
                  borderRadius: R.rPill,
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : secs[b] / total,
                    minHeight: 8,
                    color: kStressBandColors[b],
                    backgroundColor: kStressBandColors[b].withValues(alpha: .18),
                  ),
                ),
              ),
              const SizedBox(width: S.x3),
              Text(total == 0 ? '0%' : '${(secs[b] / total * 100).round()}%',
                  style: F.body.copyWith(color: p.ink)),
              const SizedBox(width: S.x2),
              Text(dur(secs[b]), style: F.body.copyWith(color: p.ink3)),
            ]),
          ),
          const SizedBox(height: S.x2),
        ],
        if (d.dailyMeans.length >= 2)
          Section(
            l?.detailTrends ?? 'Trends',
            MetricTrendCard(TrendRow(
              'stress',
              <TrendPoint>[
                for (final e in (d.dailyMeans.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
                  (day: e.key, value: e.value, source: d.source),
              ],
              null,
              title: l?.gsDailyAverage ?? 'Daily average',
            )),
          ),
        // The trend card already names the source; said once.
        if (d.dailyMeans.length < 2) ...[
          const SizedBox(height: S.x3),
          Text(l?.dataFrom(d.source) ?? 'Data from ${d.source}', style: F.cap.copyWith(color: p.ink3)),
        ],
        const SizedBox(height: S.x2),
        note,
      ],
    );
  }

  String _vsUsual(AppLocalizations? l, double diff) {
    final n = diff.abs().round();
    if (n < 3) return l?.gsUsualSame ?? 'Your stress level today is about where it usually is.';
    return diff < 0
        ? (l?.gsUsualLower(n) ?? 'Your stress level today is $n points lower than usual.')
        : (l?.gsUsualHigher(n) ?? 'Your stress level today is $n points higher than usual.');
  }
}

class _StressCurve extends CustomPainter {
  final List<StressPoint> pts;
  final String day;
  final P p;
  final int? onset, wake;
  _StressCurve(this.pts, this.day, this.p, this.onset, this.wake);

  @override
  void paint(Canvas c, Size s) {
    final d = DateTime.parse(day);
    final start = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 1000;
    const right = 30.0, bottom = 18.0;
    final w = s.width - right, h = s.height - bottom;
    double x(int t) => ((t - start) / 86400).clamp(0.0, 1.0) * w;
    double y(num v) => h - v / 100 * h;
    if (onset != null && wake != null) {
      c.drawRect(Rect.fromLTRB(x(onset!), 0, x(wake!), h), Paint()..color = C.indigo.withValues(alpha: .14));
    }
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
      tp.paint(c, Offset(hr / 24 * w, h + 2));
    }
    final line = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      if (b.t - a.t > 600) continue; // off the wrist or in an activity: a gap
      c.drawLine(Offset(x(a.t), y(a.v)), Offset(x(b.t), y(b.v)),
          line..color = p.on(kStressBandColors[stressBand((a.v + b.v) / 2)]));
    }
  }

  @override
  bool shouldRepaint(_StressCurve o) => true;
}
