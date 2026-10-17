// HRV STATUS — this week's overnight HRV against your own longer baseline.
//
// The Garmin "HRV Status" idea, built from the published HRV-guided-training
// method it is based on (Plews et al. 2012, 2013; Kiviniemi et al. 2007):
//
//   * nightly RMSSD → ln(RMSSD), which makes its day-to-day noise symmetric;
//   * the 7-night rolling mean of ln(RMSSD) is the signal (single nights are
//     too noisy to act on — Plews 2012);
//   * the baseline is the [baselineDays] calendar days BEFORE that week, so the
//     week is never part of its own reference;
//   * the normal range is the baseline mean ± the smallest worthwhile change,
//     0.5 × the baseline's between-night SD (Plews 2013).
//
// Status: 'balanced' (inside the range), 'above' or 'below'. Never "good" or
// "bad": a week above baseline can follow a deload, a below-baseline week can
// follow hard training, illness, travel or alcohol — and nothing here can tell
// those apart.
//
// HONESTY: absent until the week has [minWeekNights] nights AND the baseline
// has [minBaselineNights]. A missing night is missing, never zero. PRV, not ECG.

import 'dart:math' as math;

import '../types.dart';
import '../util.dart';

const int hrvStatusWeekDays = 7;
const int hrvStatusBaselineDays = 60;
const int hrvStatusMinWeekNights = 4;
const int hrvStatusMinBaselineNights = 14;

/// Plews' smallest worthwhile change for ln(RMSSD), in baseline SDs.
const double hrvStatusSwcSd = 0.5;

class HrvStatus {
  final String status; // 'balanced' | 'above' | 'below'
  final double weekMeanMs; // e^(7-night mean ln RMSSD)
  final double baselineMeanMs; // e^(baseline mean ln RMSSD)
  final double rangeLowMs;
  final double rangeHighMs;
  final int weekNights;
  final int baselineNights;

  const HrvStatus({
    required this.status,
    required this.weekMeanMs,
    required this.baselineMeanMs,
    required this.rangeLowMs,
    required this.rangeHighMs,
    required this.weekNights,
    required this.baselineNights,
  });

  Map<String, dynamic> toJson() => {
        'status': status,
        'week_mean_ms': round6(weekMeanMs),
        'baseline_mean_ms': round6(baselineMeanMs),
        'range_low_ms': round6(rangeLowMs),
        'range_high_ms': round6(rangeHighMs),
        'week_nights': weekNights,
        'baseline_nights': baselineNights,
      };
}

/// HRV status from nightly RMSSD (ms), one slot per calendar day, OLDEST first,
/// with last night as the final slot. Null is a night with no value.
Metric<HrvStatus> hrvStatus(
  List<double?> nightlyRmssdMs, {
  int weekDays = hrvStatusWeekDays,
  int baselineDays = hrvStatusBaselineDays,
  int minWeekNights = hrvStatusMinWeekNights,
  int minBaselineNights = hrvStatusMinBaselineNights,
}) {
  const inputs = ['nightly_rmssd'];
  List<double> lnOf(Iterable<double?> xs) => [
        for (final v in xs)
          if (v != null && v.isFinite && v > 0) math.log(v)
      ];
  final n = nightlyRmssdMs.length;
  final week = lnOf(nightlyRmssdMs.sublist(math.max(0, n - weekDays)));
  final baseEnd = math.max(0, n - weekDays);
  final base = lnOf(
      nightlyRmssdMs.sublist(math.max(0, baseEnd - baselineDays), baseEnd));

  if (week.length < minWeekNights) {
    return Metric<HrvStatus>.absent(
      tier: Tier.high,
      inputs_used: inputs,
      note: needBaselineNote(have: week.length, need: minWeekNights),
    );
  }
  if (base.length < minBaselineNights) {
    return Metric<HrvStatus>.absent(
      tier: Tier.high,
      inputs_used: inputs,
      note: needBaselineNote(have: base.length, need: minBaselineNights),
    );
  }

  final wm = mean(week)!;
  final bm = mean(base)!;
  final swc = hrvStatusSwcSd * (stddev(base) ?? 0);
  final lo = bm - swc, hi = bm + swc;
  final status = wm < lo ? 'below' : (wm > hi ? 'above' : 'balanced');

  return Metric<HrvStatus>(
    value: HrvStatus(
      status: status,
      weekMeanMs: math.exp(wm),
      baselineMeanMs: math.exp(bm),
      rangeLowMs: math.exp(lo),
      rangeHighMs: math.exp(hi),
      weekNights: week.length,
      baselineNights: base.length,
    ),
    // Coverage of the week, the thinner and more decisive of the two windows.
    confidence: week.length / weekDays,
    tier: Tier.high,
    inputs_used: inputs,
  );
}
