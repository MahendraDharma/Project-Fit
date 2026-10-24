// The month as a calendar: one small ring per day for the metric picked in
// the chips, filled by that day's stored value. A day with nothing stored is
// an empty track, never a zero.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/day_label.dart';
import '../../data/local_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/date_text.dart';
import '../ui2.dart';
import 'home_screen.dart';

enum CalendarMetric { strain, recovery, sleep, stress, steps }

/// Day → how full its ring is (0–1), and the colour to fill it with.
typedef CalendarDay = ({double frac, Color color});

/// The `getChart` key and how a stored value becomes a ring.
(String, CalendarDay Function(double)) calendarSpec(CalendarMetric m,
    {double sleepNeedMin = 480, int stepGoal = kDefaultStepGoal, double stressMax = 100}) =>
    switch (m) {
      CalendarMetric.strain => ('strain', (v) => (frac: v / 21, color: strainColor(v))),
      CalendarMetric.recovery => ('recovery', (v) => (frac: v / 100, color: recoveryColor(v))),
      CalendarMetric.sleep => ('sleep', (v) => (frac: v / sleepNeedMin, color: sleepColor(v / sleepNeedMin * 100))),
      CalendarMetric.stress => ('stress', (v) => (frac: v / stressMax, color: C.purple)),
      CalendarMetric.steps => ('steps', (v) => (frac: v / stepGoal, color: C.green)),
    };

class MonthCalendarScreen extends StatefulWidget {
  final CalendarMetric metric;

  /// Preloaded, per metric, for the gallery and tests.
  final Map<CalendarMetric, Map<String, CalendarDay>>? data;
  final DateTime? month;
  const MonthCalendarScreen(
      {super.key, this.metric = CalendarMetric.recovery, this.data, this.month});

  @override
  State<MonthCalendarScreen> createState() => _MonthCalendarScreenState();
}

class _MonthCalendarScreenState extends State<MonthCalendarScreen> {
  late CalendarMetric _m = widget.metric;
  late DateTime _month = widget.month ?? DateTime(DateTime.now().year, DateTime.now().month);
  final Map<CalendarMetric, Map<String, CalendarDay>> _days = {};

  @override
  void initState() {
    super.initState();
    if (widget.data != null) {
      _days.addAll(widget.data!);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(_m));
    }
  }

  Future<void> _load(CalendarMetric m) async {
    if (_days.containsKey(m)) return;
    final repo = repoOf(context);
    if (repo == null) return;
    try {
      final profile = await repo.getProfile();
      final pts = pointsOf(await repo.getChart(calendarSpec(m).$1));
      // Stress has no fixed top; a ring is the day against the person's own
      // highest stored day.
      final top = pts.isEmpty ? 1.0 : pts.map((e) => e.v).reduce(math.max);
      final (_, ring) = calendarSpec(m,
          stepGoal: (profile['step_goal'] as num?)?.toInt() ?? kDefaultStepGoal,
          stressMax: top > 0 ? top : 1);
      final out = <String, CalendarDay>{
        for (final p in pts)
          dayLabelOf(DateTime.fromMillisecondsSinceEpoch(p.t * 1000)): ring(p.v),
      };
      if (mounted) setState(() => _days[m] = out);
    } catch (_) {
      if (mounted) setState(() => _days[m] = const {});
    }
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final loc = l?.localeName ?? 'en';
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final days = _days[_m] ?? const {};
    final first = _month;
    final lead = first.weekday % 7; // Sunday first
    final count = DateTime(first.year, first.month + 1, 0).day;
    final names = [
      (CalendarMetric.strain, l?.homeRingStrain ?? 'Strain'),
      (CalendarMetric.recovery, l?.homeRingRecovery ?? 'Recovery'),
      (CalendarMetric.sleep, l?.homeRingSleep ?? 'Sleep'),
      (CalendarMetric.stress, l?.homeVitalsStress ?? 'Stress'),
      (CalendarMetric.steps, l?.readingSteps ?? 'Steps'),
    ];
    final sunday = DateTime(2026, 10, 4);
    final weekdays = [
      for (var i = 0; i < 7; i++)
        localizedDate(DateTime(sunday.year, sunday.month, sunday.day + i), loc, pattern: 'EEE'),
    ];

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(S.x4, S.x2, S.x4, S.x10), children: [
          NavBar(localizedDate(first, loc, pattern: 'MMMM yyyy'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Pressable(
                  onTap: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                  semanticLabel: l?.calendarPrevMonth ?? 'Previous month',
                  child: Icon(LucideIcons.chevronLeft, color: p.ink),
                ),
                Pressable(
                  onTap: _month.isBefore(thisMonth)
                      ? () => setState(() => _month = DateTime(_month.year, _month.month + 1))
                      : null,
                  semanticLabel: l?.calendarNextMonth ?? 'Next month',
                  child: Icon(LucideIcons.chevronRight,
                      color: _month.isBefore(thisMonth) ? p.ink : p.ink3),
                ),
              ]),
              trailingWidth: S.tap * 2),
          const SizedBox(height: S.x3),
          SubTabs([for (final (_, n) in names) n], names.indexWhere((e) => e.$1 == _m), (i) {
            setState(() => _m = names[i].$1);
            _load(_m);
          }),
          const SizedBox(height: S.x4),
          Row(children: [
            for (final w in weekdays)
              Expanded(
                child: Text(w, textAlign: TextAlign.center, style: F.cap.copyWith(color: p.ink3)),
              ),
          ]),
          const SizedBox(height: S.x2),
          Divider(color: p.line, height: 1),
          const SizedBox(height: S.x3),
          LayoutBuilder(builder: (c, k) {
            final w = (k.maxWidth - 6 * S.x1) / 7;
            return Wrap(spacing: S.x1, runSpacing: S.x3, children: [
              for (var i = 0; i < lead; i++) SizedBox(width: w),
              for (var d = 1; d <= count; d++)
                _cell(c, w, DateTime(first.year, first.month, d), days, now),
            ]);
          }),
          const SizedBox(height: S.x5),
          Text(l?.calendarEmptyNote ?? 'An empty ring is a day with nothing stored, not a zero.',
              style: F.cap.copyWith(color: p.ink3)),
        ]),
      ),
    );
  }

  Widget _cell(BuildContext c, double w, DateTime day, Map<String, CalendarDay> days, DateTime now) {
    final p = P.of(c);
    final id = dayLabelOf(day);
    final v = days[id];
    final today = id == dayLabelOf(now);
    final future = day.isAfter(now);
    return Container(
      width: w,
      padding: const EdgeInsets.symmetric(vertical: S.x2),
      decoration: BoxDecoration(
        color: today ? p.card2 : null,
        borderRadius: R.rPill,
        border: Border.all(color: today ? p.ink3 : p.line),
      ),
      child: Column(children: [
        SizedBox(
          width: math.min(w - S.x2, 38),
          height: math.min(w - S.x2, 38),
          child: CustomPaint(painter: _MiniRing(v, p)),
        ),
        const SizedBox(height: S.x1),
        Text('${day.day}',
            style: F.body.copyWith(
                color: today ? p.on(C.blue) : (future ? p.ink3 : p.ink),
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _MiniRing extends CustomPainter {
  final CalendarDay? d;
  final P p;
  _MiniRing(this.d, this.p);

  @override
  void paint(Canvas c, Size s) {
    final st = s.shortestSide * .16;
    final r = Rect.fromLTWH(st / 2, st / 2, s.width - st, s.height - st);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = st
      ..strokeCap = StrokeCap.round;
    final x = d;
    c.drawArc(r, 0, 2 * math.pi, false,
        paint..color = x == null ? p.track : x.color.withValues(alpha: .25));
    if (x != null && x.frac > 0) {
      c.drawArc(r, -math.pi / 2, 2 * math.pi * x.frac.clamp(0.0, 1.0), false,
          paint..color = p.on(x.color));
    }
  }

  @override
  bool shouldRepaint(_MiniRing o) => o.d != d;
}
