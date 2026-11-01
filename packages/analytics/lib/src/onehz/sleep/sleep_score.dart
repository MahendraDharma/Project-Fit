// SLEEP SCORE 0–100 — Garmin's components, our open weights.
//
// OWNER DECISION (2026-11-01): a single 0–100 sleep score, shown WITH the
// existing sleep performance, never instead of it. Garmin names its inputs
// (duration, stress during sleep, time in each stage — deep 17–35 % —, time
// awake, restlessness) and publishes no weights. These are ours, stated whole,
// and every component is returned so the screen can show what moved the total:
//
//   component      weight  100 when                     0 when
//   duration         35    asleep ≥ need                asleep = 0 (linear)
//   stages           20    deep 17–35 %, REM 18–28 %    deep/REM at 0 % or ≥ 60/50 %
//   awake            15    ≤ 20 min awake after onset   ≥ 90 min
//   restlessness     15    ≤ 2 restless min per hour     ≥ 12 per hour
//   stress           15    sleep stress ≤ 25            sleep stress 100
//
// A component whose input is missing is DROPPED and the remaining weights are
// rescaled; duration is required. With no learned sleep need the duration
// target is 7 h, the AASM/SRS adult minimum (Watson 2015), and the result
// says so ([SleepScore.needFromGuideline]).
//
// Stages come from a wrist estimate without EEG (REM is the weakest stage for
// every wrist device, WHOOP and Garmin included), so they carry 20, not more.

import 'dart:math' as math;

import '../types.dart';
import '../util.dart';

const Map<String, double> sleepScoreWeights = {
  'duration': 35,
  'stages': 20,
  'awake': 15,
  'restlessness': 15,
  'stress': 15,
};

/// AASM/SRS: adults need 7 h or more (Watson et al. 2015).
const double sleepScoreGuidelineNeedMin = 420;

class SleepScore {
  final double score; // 0–100
  final Map<String, double> components; // each 0–100, present ones only
  final bool needFromGuideline;
  const SleepScore(this.score, this.components, this.needFromGuideline);
  Map<String, dynamic> toJson() => {
        'score': round6(score),
        'components': {
          for (final e in components.entries) e.key: round6(e.value)
        },
        'need_from_guideline': needFromGuideline,
      };
}

/// Garmin's word for a 0–100 sleep score band.
String sleepScoreBand(double s) => s >= 90
    ? 'excellent'
    : (s >= 80 ? 'good' : (s >= 60 ? 'fair' : 'poor'));

double _ramp(double x, double zeroAt, double fullAt) {
  final t = (x - zeroAt) / (fullAt - zeroAt);
  return (100 * t).clamp(0.0, 100.0).toDouble();
}

/// 100 inside [lo, hi], falling linearly to 0 at 0 % and at [zeroHigh] %.
double _band(double pct, double lo, double hi, double zeroHigh) {
  if (pct < lo) return _ramp(pct, 0, lo);
  if (pct > hi) return _ramp(pct, zeroHigh, hi);
  return 100;
}

Metric<SleepScore> sleepScore({
  required double? asleepMin,
  double? needMin,
  double? deepMin,
  double? remMin,
  double? awakeMin,
  double? restlessMin,
  double? sleepStress, // 0–100, the night's stress
}) {
  const inputs = ['sleep_accounting', 'sleep_need', 'restlessness', 'sleep_stress'];
  if (asleepMin == null || !asleepMin.isFinite || asleepMin <= 0) {
    return const Metric<SleepScore>.absent(
      tier: Tier.estimate,
      inputs_used: inputs,
      note: 'need_input:name=sleep_night',
    );
  }
  final guideline = needMin == null || needMin <= 0;
  final need = guideline ? sleepScoreGuidelineNeedMin : needMin;
  final c = <String, double>{
    'duration': (100 * asleepMin / need).clamp(0.0, 100.0).toDouble(),
  };
  final stage = <double>[
    if (deepMin != null) _band(100 * deepMin / asleepMin, 17, 35, 60),
    if (remMin != null) _band(100 * remMin / asleepMin, 18, 28, 50),
  ];
  if (stage.isNotEmpty) c['stages'] = mean(stage)!;
  if (awakeMin != null) c['awake'] = _ramp(awakeMin, 90, 20);
  if (restlessMin != null) {
    c['restlessness'] = _ramp(restlessMin / (asleepMin / 60), 12, 2);
  }
  if (sleepStress != null && sleepStress.isFinite) {
    c['stress'] = _ramp(sleepStress, 100, 25);
  }
  var w = 0.0, sum = 0.0;
  for (final e in c.entries) {
    final k = sleepScoreWeights[e.key]!;
    w += k;
    sum += k * e.value;
  }
  final total = sleepScoreWeights.values.reduce((a, b) => a + b);
  return Metric<SleepScore>(
    value: SleepScore(sum / w, c, guideline),
    // The share of the full weight that was actually scored.
    confidence: math.min(1.0, w / total),
    tier: Tier.estimate,
    inputs_used: inputs,
  );
}
