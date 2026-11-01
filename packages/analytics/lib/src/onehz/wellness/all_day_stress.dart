// ALL-DAY STRESS 0–100 — the Garmin-style stress level, from still minutes only.
//
// OWNER DECISION (2026-11-01). The derivation engine refused this surface for
// two reasons that still hold, so they are written on the result rather than
// argued away: (1) wrist beat timing is worst exactly in waking hours, and gen4
// has no per-beat quality flag; (2) no vendor stress composite has independent
// peer-reviewed validation. The owner chose to have the number anyway. What
// keeps it honest:
//
//   * Only STILL five-minute windows enter (the engine's motion-gated
//     `daytime_hrv` bins). Moving time is not stress and is not scored — it is
//     a gap, which is also what Garmin does with activity.
//   * The reference is the wearer's OWN overnight variability: the median
//     nightly RMSSD of the prior [allDayStressBaselineNights] nights. Night is
//     the most relaxed state the band sees, so it anchors "rest".
//   * The mapping is stated whole, with its constant in the open:
//
//         score = 100 · ln(rest / rmssd) / ln(allDayStressFloorRatio)
//
//     clamped to 0–100. A still window as variable as your nights reads 0; one
//     at half your night level reads 50; one at a quarter or less reads 100.
//     [allDayStressFloorRatio] = 4 is OUR choice, not Garmin's or Firstbeat's
//     (neither is published), so the number is comparable only with itself.
//   * Bands are Garmin's published labels: 0–25 rest, 26–50 low, 51–75 medium,
//     76–100 high.
//
// HONESTY: absent below [allDayStressMinBaselineNights] nights of reference or
// [allDayStressMinWindows] scored windows. Tier ESTIMATE.

import 'dart:math' as math;

import '../types.dart';
import '../util.dart';

/// Night median RMSSD ÷ this = a window that scores 100. Our constant.
const double allDayStressFloorRatio = 4.0;

/// Prior nights the rest reference is the median of (WHOOP uses 14 days).
const int allDayStressBaselineNights = 14;
const int allDayStressMinBaselineNights = 7;

/// Quiet beat-pairs a five-minute window needs before it is a reading.
const int allDayStressMinPairs = 30;

/// Scored windows a day needs before it has a daily figure (= 30 minutes).
const int allDayStressMinWindows = 6;

/// Length of one window, seconds (the engine's `daytime_hrv` bin).
const int allDayStressWindowSec = 300;

/// One still five-minute window from `daytime_hrv.timeline`.
class QuietHrvWindow {
  final int tSec; // window start, epoch seconds
  final double rmssdMs;
  final int pairs; // quiet beat-pairs it was built from
  const QuietHrvWindow(this.tSec, this.rmssdMs, this.pairs);
}

class StressPoint {
  final int tSec;
  final double score; // 0–100
  const StressPoint(this.tSec, this.score);
  Map<String, dynamic> toJson() => {'t': tSec, 'score': round6(score)};
}

/// Garmin's published band for a 0–100 stress level.
String stressBand(double score) => score <= 25
    ? 'rest'
    : (score <= 50 ? 'low' : (score <= 75 ? 'medium' : 'high'));

class AllDayStress {
  final List<StressPoint> timeline;
  final double average; // mean of the scored windows
  final double highest;
  final double restRmssdMs; // the reference
  /// Minutes in each of Garmin's bands: rest, low, medium, high.
  final Map<String, int> bandMinutes;
  final int scoredMinutes;
  const AllDayStress({
    required this.timeline,
    required this.average,
    required this.highest,
    required this.restRmssdMs,
    required this.bandMinutes,
    required this.scoredMinutes,
  });
  Map<String, dynamic> toJson() => {
        'average': round6(average),
        'highest': round6(highest),
        'rest_rmssd_ms': round6(restRmssdMs),
        'band_minutes': bandMinutes,
        'scored_minutes': scoredMinutes,
        'timeline': [for (final p in timeline) p.toJson()],
      };
}

/// The 0–100 score of one still window against a rest reference.
double stressScoreOf(double rmssdMs, double restRmssdMs) {
  if (rmssdMs <= 0 || restRmssdMs <= 0) return 100;
  final s = 100 *
      math.log(restRmssdMs / rmssdMs) /
      math.log(allDayStressFloorRatio);
  return s.clamp(0.0, 100.0).toDouble();
}

/// The median nightly RMSSD of the last [allDayStressBaselineNights] values
/// (oldest first; nulls are missing nights), or null below the minimum.
double? restReferenceRmssd(List<double?> priorNightlyRmssdMs) {
  final n = priorNightlyRmssdMs.length;
  final xs = [
    for (final v in priorNightlyRmssdMs
        .sublist(math.max(0, n - allDayStressBaselineNights)))
      if (v != null && v.isFinite && v > 0) v
  ];
  if (xs.length < allDayStressMinBaselineNights) return null;
  return median(xs);
}

/// Today's stress from its still windows. [priorNightlyRmssdMs] is the nights
/// BEFORE today, oldest first.
Metric<AllDayStress> allDayStress(
  List<QuietHrvWindow> windows,
  List<double?> priorNightlyRmssdMs,
) {
  const inputs = ['daytime_hrv', 'nightly_rmssd'];
  final nights = priorNightlyRmssdMs
      .sublist(math.max(0, priorNightlyRmssdMs.length - allDayStressBaselineNights))
      .where((v) => v != null && v.isFinite && v > 0)
      .length;
  final rest = restReferenceRmssd(priorNightlyRmssdMs);
  if (rest == null) {
    return Metric<AllDayStress>.absent(
      tier: Tier.estimate,
      inputs_used: inputs,
      note: needBaselineNote(have: nights, need: allDayStressMinBaselineNights),
    );
  }
  final usable = [
    for (final w in windows)
      if (w.pairs >= allDayStressMinPairs && w.rmssdMs.isFinite && w.rmssdMs > 0)
        w
  ]..sort((a, b) => a.tSec.compareTo(b.tSec));
  if (usable.length < allDayStressMinWindows) {
    return Metric<AllDayStress>.absent(
      tier: Tier.estimate,
      inputs_used: inputs,
      note: 'need_input:name=still_windows,'
          'have=${usable.length},need=$allDayStressMinWindows',
    );
  }
  final pts = [
    for (final w in usable) StressPoint(w.tSec, stressScoreOf(w.rmssdMs, rest))
  ];
  final minutes = <String, int>{'rest': 0, 'low': 0, 'medium': 0, 'high': 0};
  const winMin = allDayStressWindowSec ~/ 60;
  for (final p in pts) {
    final b = stressBand(p.score);
    minutes[b] = minutes[b]! + winMin;
  }
  final scores = [for (final p in pts) p.score];
  return Metric<AllDayStress>(
    value: AllDayStress(
      timeline: pts,
      average: mean(scores)!,
      highest: scores.reduce(math.max),
      restRmssdMs: rest,
      bandMinutes: minutes,
      scoredMinutes: pts.length * winMin,
    ),
    // Coverage of a 16-hour waking day by still, scored windows — the honest
    // limit on how much of the day the average speaks for.
    confidence: math.min(1.0, pts.length * winMin / (16 * 60)),
    tier: Tier.estimate,
    inputs_used: inputs,
    note: 'still windows only; rest = median night RMSSD of prior '
        '$allDayStressBaselineNights nights; score = 100·ln(rest/rmssd)/'
        'ln($allDayStressFloorRatio)',
  );
}
