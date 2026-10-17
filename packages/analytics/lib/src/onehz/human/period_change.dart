// PERIOD CHANGE — this month against the one before, for one daily metric.
//
// The question a monthly assessment answers is "did anything actually move?",
// and most month-to-month differences are day-to-day noise. So a change is
// called only when the difference between the two period means exceeds the
// smallest worthwhile change: 0.2 × the between-day SD of the EARLIER period
// (Hopkins 2004, "How to interpret changes in an athletic performance test").
// The earlier period is the reference because it is the one the current
// period is being judged against; using the pooled SD would let a chaotic new
// month widen its own goalposts.
//
// HONESTY: needs [minDays] measured days in EACH period (a day with no value is
// missing, never zero); absent otherwise. Says up / down / steady, never good
// or bad: whether a higher number is better is the caller's to know.

import '../types.dart';
import '../util.dart';

/// Minimum measured days per period before a comparison is made.
const int periodChangeMinDays = 10;

/// Hopkins' smallest worthwhile change, as a fraction of the between-day SD.
const double smallestWorthwhileChangeSd = 0.2;

class PeriodChange {
  final double previousMean;
  final double currentMean;
  final int previousDays;
  final int currentDays;

  /// currentMean − previousMean.
  final double delta;

  /// 0.2 × SD of the previous period's days.
  final double swc;

  /// 'up' | 'down' | 'steady'
  final String direction;

  const PeriodChange({
    required this.previousMean,
    required this.currentMean,
    required this.previousDays,
    required this.currentDays,
    required this.delta,
    required this.swc,
    required this.direction,
  });

  Map<String, dynamic> toJson() => {
        'previous_mean': round6(previousMean),
        'current_mean': round6(currentMean),
        'previous_days': previousDays,
        'current_days': currentDays,
        'delta': round6(delta),
        'swc': round6(swc),
        'direction': direction,
      };
}

/// Compare [current] with [previous], two windows of daily values in which
/// null is a day with no measurement.
Metric<PeriodChange> periodChange(
  List<double?> previous,
  List<double?> current, {
  int minDays = periodChangeMinDays,
}) {
  const inputs = ['daily_series'];
  final prev = [for (final v in previous) if (v != null && v.isFinite) v];
  final cur = [for (final v in current) if (v != null && v.isFinite) v];
  final have = prev.length < cur.length ? prev.length : cur.length;
  if (have < minDays) {
    return Metric<PeriodChange>.absent(
      tier: Tier.relative,
      inputs_used: inputs,
      note: needBaselineNote(have: have, need: minDays),
    );
  }
  final pm = mean(prev)!, cm = mean(cur)!;
  final sd = stddev(prev) ?? 0;
  final swc = smallestWorthwhileChangeSd * sd;
  final delta = cm - pm;
  final direction = delta.abs() <= swc
      ? 'steady'
      : (delta > 0 ? 'up' : 'down');
  return Metric<PeriodChange>(
    value: PeriodChange(
      previousMean: pm,
      currentMean: cm,
      previousDays: prev.length,
      currentDays: cur.length,
      delta: delta,
      swc: swc,
      direction: direction,
    ),
    // Coverage of the thinner period over a 30-day month.
    confidence: (have / 30).clamp(0, 1).toDouble(),
    tier: Tier.relative,
    inputs_used: inputs,
  );
}
