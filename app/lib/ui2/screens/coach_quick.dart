// QUICK ANSWERS — the coach that needs no setup.
//
// A fixed set of questions, each answered on this phone from figures the app
// already stores: no model, no key, no network. The same data always gives the
// same answer, so it can be tested like any other rule, and it is what the
// coach says to everyone before (or instead of) connecting a model.
//
// Every function here is pure: it takes dense day arrays (one slot per
// calendar day, oldest first, the LAST slot is today, `null` for a day with no
// value — the shape `denseDays` builds) and returns words, a figure and the
// mochi's mood. The screen does the reading.
import '../../coach/coach_engine.dart' show ChartSeries, ChartSpec;
import '../../l10n/app_localizations.dart';
import '../../l10n/date_text.dart';
import '../../state/clock_format.dart';
import '../mochi.dart';
import 'home_screen.dart' show hm, thousands;

enum QuickAsk { recovery, sleep, bedtime, hrv, restingHr, steps }

/// One answer: the words, an optional figure, and how the mochi looks saying it.
typedef QuickReply = ({String text, ChartSpec? chart, MochiMood mood});

/// The question as the user would ask it.
String quickQuestion(AppLocalizations? l, QuickAsk a) => switch (a) {
      QuickAsk.recovery => l?.quickAskRecovery ?? 'How recovered am I today?',
      QuickAsk.sleep => l?.quickAskSleep ?? 'How was my sleep this week?',
      QuickAsk.bedtime => l?.quickAskBedtime ?? 'When should I go to bed tonight?',
      QuickAsk.hrv => l?.quickAskHrv ?? 'Is my HRV going up or down?',
      QuickAsk.restingHr => l?.quickAskRhr ?? 'How is my resting heart rate?',
      QuickAsk.steps => l?.quickAskSteps ?? 'How active was I this week?',
    };

// ── small statistics ──

List<double> _vals(Iterable<double?> xs) => [for (final x in xs) ?x];

double? _mean(Iterable<double?> xs) {
  final v = _vals(xs);
  return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
}

/// The last [n] slots of [xs] (fewer when it is shorter).
List<double?> _tail(List<double?> xs, int n) =>
    xs.length <= n ? xs : xs.sublist(xs.length - n);

/// Everything before the last [n] slots.
List<double?> _head(List<double?> xs, int n) =>
    xs.length <= n ? const [] : xs.sublist(0, xs.length - n);

/// Day labels for a dense array ending [today]: weekday names for a week,
/// day-of-month beyond that.
List<String> _labels(DateTime today, int n, String locale) => [
      for (var i = n - 1; i >= 0; i--)
        localizedDate(DateTime(today.year, today.month, today.day - i), locale,
            pattern: n <= 7 ? 'E' : 'd'),
    ];

String _weekday(DateTime today, int index, int n, String locale) => localizedDate(
    DateTime(today.year, today.month, today.day - (n - 1 - index)), locale,
    pattern: 'EEEE');

QuickReply _noData(AppLocalizations? l) => (
      text: l?.quickNoData ??
          'There is not enough data for this yet. Wear the band for a few more '
              'days and nights, then ask again.',
      chart: null,
      mood: MochiMood.think,
    );

// ── the answers ──

/// [days]: recovery 0–100, ideally 30 slots. The figure shows the last 14.
QuickReply quickRecovery(AppLocalizations? l, List<double?> days,
    {required DateTime today, String locale = 'en'}) {
  final now = days.isEmpty ? null : days.last;
  if (now == null) {
    return (
      text: l?.quickRecoveryNone ??
          'No recovery score yet today. It appears after a night with the band on.',
      chart: null,
      mood: MochiMood.think,
    );
  }
  final pct = '${now.round()}';
  final parts = <String>[l?.quickRecoveryToday(pct) ?? 'Recovery today is $pct%.'];
  final before = _vals(_head(days, 1));
  if (before.length >= 4) {
    final avg = _mean(before)!;
    final d = (now - avg).round();
    final a = '${avg.round()}';
    parts.add(d >= 5
        ? (l?.quickVsUsualUp('$d', a) ?? 'That is $d points above your usual $a.')
        : d <= -5
            ? (l?.quickVsUsualDown('${-d}', a) ?? 'That is ${-d} points below your usual $a.')
            : (l?.quickVsUsualSame(a) ?? 'That is close to your usual $a.'));
  }
  final MochiMood mood;
  if (now >= 67) {
    parts.add(l?.quickRecoveryHigh ?? 'A good day for a harder workout.');
    mood = MochiMood.happy;
  } else if (now >= 34) {
    parts.add(l?.quickRecoveryMid ?? 'A steady, moderate day suits you.');
    mood = MochiMood.talk;
  } else {
    parts.add(l?.quickRecoveryLow ??
        'Keep today easy: a walk, some stretching and an early night.');
    mood = MochiMood.sleepy;
  }
  final shown = _tail(days, 14);
  return (
    text: parts.join(' '),
    chart: ChartSpec(
      type: 'bar',
      title: l?.quickChartRecovery ?? 'Recovery, last 14 days',
      xLabels: _labels(today, shown.length, locale),
      series: [ChartSeries(name: l?.quickChartRecoveryName ?? 'Recovery', values: shown)],
      unit: '%',
    ),
    mood: mood,
  );
}

/// [days]: minutes asleep per night (the night is stamped on the day you woke),
/// ideally 14 slots: this week and the week before. [needMin] is the computed
/// sleep need, when the app has one.
QuickReply quickSleep(AppLocalizations? l, List<double?> days,
    {required DateTime today, double? needMin, String locale = 'en'}) {
  final week = _tail(days, 7);
  final nights = _vals(week);
  if (nights.length < 3) return _noData(l);
  final avg = _mean(week)!;
  final parts = <String>[
    l?.quickSleepAvg(hm(avg), '${nights.length}') ??
        'You slept ${hm(avg)} a night on average over your last ${nights.length} nights.',
  ];
  var mood = MochiMood.talk;
  if (needMin != null && needMin > 0) {
    final short = needMin - avg;
    if (short >= 20) {
      parts.add(l?.quickSleepShort(hm(short), hm(needMin)) ??
          'That is about ${hm(short)} less than the ${hm(needMin)} your body needs.');
      mood = MochiMood.sleepy;
    } else {
      parts.add(l?.quickSleepEnough(hm(needMin)) ??
          'That covers the ${hm(needMin)} your body needs.');
      mood = MochiMood.happy;
    }
  }
  final prev = _head(days, 7);
  if (_vals(prev).length >= 3) {
    final d = avg - _mean(prev)!;
    if (d.abs() >= 15) {
      parts.add(d > 0
          ? (l?.quickSleepMoreThanLast(hm(d)) ?? '${hm(d)} more than the week before.')
          : (l?.quickSleepLessThanLast(hm(-d)) ?? '${hm(-d)} less than the week before.'));
    }
  }
  var best = -1, worst = -1;
  for (var i = 0; i < week.length; i++) {
    final v = week[i];
    if (v == null) continue;
    if (best < 0 || v > week[best]!) best = i;
    if (worst < 0 || v < week[worst]!) worst = i;
  }
  if (best != worst) {
    final bd = _weekday(today, best, week.length, locale);
    final wd = _weekday(today, worst, week.length, locale);
    parts.add(l?.quickSleepBestWorst(hm(week[best]), bd, hm(week[worst]), wd) ??
        'Longest night: ${hm(week[best])} ($bd). Shortest: ${hm(week[worst])} ($wd).');
  }
  return (
    text: parts.join(' '),
    chart: ChartSpec(
      type: 'bar',
      title: l?.quickChartSleep ?? 'Time asleep, last 7 nights',
      xLabels: _labels(today, week.length, locale),
      series: [
        ChartSeries(
          name: l?.quickChartSleepName ?? 'Asleep',
          values: [for (final v in week) v == null ? null : (v / 6).round() / 10],
        ),
      ],
      unit: l?.quickUnitHours ?? 'h',
    ),
    mood: mood,
  );
}

/// [bedtimeMin]: tonight's recommended bedtime as a minute of the day;
/// [needMin]: the sleep need it was worked out for.
QuickReply quickBedtime(AppLocalizations? l, {double? bedtimeMin, double? needMin}) {
  if (bedtimeMin == null) {
    return (
      text: l?.quickBedtimeNone ??
          'I need a few more nights of sleep before I can work out your bedtime.',
      chart: null,
      mood: MochiMood.think,
    );
  }
  final time = formatClockMinute(bedtimeMin.round() % 1440);
  return (
    text: needMin != null && needMin > 0
        ? (l?.quickBedtimeNeed(hm(needMin), time) ??
            'To get the ${hm(needMin)} of sleep you need, be in bed by $time tonight.')
        : (l?.quickBedtime(time) ?? 'Aim to be in bed by $time tonight.'),
    chart: null,
    mood: MochiMood.sleepy,
  );
}

/// Recent week against the weeks before it, for a value where [higherIsBetter]
/// decides which direction is the good one. Null when there is too little.
({double now, double before, int dir})? _trend(List<double?> days,
    {required double steadyBand}) {
  final recent = _vals(_tail(days, 7));
  final before = _vals(_head(days, 7));
  if (recent.length < 3 || before.length < 5) return null;
  final n = _mean(recent)!, b = _mean(before)!;
  final dir = (n - b).abs() < steadyBand ? 0 : (n > b ? 1 : -1);
  return (now: n, before: b, dir: dir);
}

ChartSpec _monthLine(String title, String name, List<double?> days, DateTime today,
        String unit, String locale) =>
    ChartSpec(
      type: 'line',
      title: title,
      xLabels: _labels(today, days.length, locale),
      series: [ChartSeries(name: name, values: days)],
      unit: unit,
    );

/// [days]: nightly heart rate variability in ms, ideally 30 slots.
QuickReply quickHrv(AppLocalizations? l, List<double?> days,
    {required DateTime today, String locale = 'en'}) {
  final avgAll = _mean(_head(days, 7));
  final t = _trend(days, steadyBand: (avgAll ?? 50) * .05);
  if (t == null) return _noData(l);
  final now = '${t.now.round()}', before = '${t.before.round()}';
  final parts = <String>[
    l?.quickHrvRecent(now, before) ??
        'Your HRV over the last week averages $now ms, against $before ms in the weeks before.',
    switch (t.dir) {
      1 => l?.quickHrvUp ?? 'It is going up, a sign your body is handling the load well.',
      -1 => l?.quickHrvDown ??
          'It is going down. Stress, hard training, short sleep, alcohol or a cold '
              'coming on can all do this, so go a little easier.',
      _ => l?.quickSteady ?? 'It is steady.',
    },
  ];
  return (
    text: parts.join(' '),
    chart: _monthLine(l?.quickChartHrv ?? 'HRV, last 30 days', 'HRV', days, today,
        'ms', locale),
    mood: switch (t.dir) { 1 => MochiMood.happy, -1 => MochiMood.alert, _ => MochiMood.talk },
  );
}

/// [days]: resting heart rate in bpm, ideally 30 slots. Lower is the good way.
QuickReply quickRestingHr(AppLocalizations? l, List<double?> days,
    {required DateTime today, String locale = 'en'}) {
  final t = _trend(days, steadyBand: 2);
  if (t == null) return _noData(l);
  final now = '${t.now.round()}', before = '${t.before.round()}';
  final parts = <String>[
    l?.quickRhrRecent(now, before) ??
        'Your resting heart rate over the last week averages $now bpm, against $before bpm before.',
    switch (t.dir) {
      1 => l?.quickRhrUp ??
          'It is higher than usual. Tiredness, stress, heat or a cold coming on can do this.',
      -1 => l?.quickRhrDown ??
          'It is lower than usual, usually a sign of good recovery or better fitness.',
      _ => l?.quickSteady ?? 'It is steady.',
    },
  ];
  final bpm = l?.quickUnitBpm ?? 'bpm';
  return (
    text: parts.join(' '),
    chart: _monthLine(l?.quickChartRhr ?? 'Resting heart rate, last 30 days',
        l?.quickChartRhrName ?? 'Resting', days, today, bpm, locale),
    mood: switch (t.dir) { 1 => MochiMood.alert, -1 => MochiMood.happy, _ => MochiMood.talk },
  );
}

/// [days]: steps per day, 7 slots. [goal]: the user's daily step goal.
QuickReply quickSteps(AppLocalizations? l, List<double?> days,
    {required DateTime today, int? goal, String locale = 'en'}) {
  final week = _tail(days, 7);
  final counted = _vals(week);
  if (counted.length < 2) return _noData(l);
  final avg = _mean(week)!;
  final parts = <String>[
    l?.quickStepsAvg(thousands(avg.round())) ??
        'You walked ${thousands(avg.round())} steps a day on average this week.',
  ];
  var mood = MochiMood.talk;
  if (goal != null && goal > 0) {
    final hit = counted.where((v) => v >= goal).length;
    parts.add(l?.quickStepsGoal(thousands(goal), '$hit', '${counted.length}') ??
        'You reached your goal of ${thousands(goal)} on $hit of ${counted.length} days.');
    if (hit * 2 >= counted.length) mood = MochiMood.happy;
  }
  var best = -1;
  for (var i = 0; i < week.length; i++) {
    if (week[i] != null && (best < 0 || week[i]! > week[best]!)) best = i;
  }
  final bd = _weekday(today, best, week.length, locale);
  final bs = thousands(week[best]!.round());
  parts.add(l?.quickStepsBest(bd, bs) ?? 'Your best day was $bd, with $bs steps.');
  return (
    text: parts.join(' '),
    chart: ChartSpec(
      type: 'bar',
      title: l?.quickChartSteps ?? 'Steps, last 7 days',
      xLabels: _labels(today, week.length, locale),
      series: [ChartSeries(name: l?.quickChartStepsName ?? 'Steps', values: week)],
    ),
    mood: mood,
  );
}
