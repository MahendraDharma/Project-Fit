// TRAINING LOAD FOCUS — Garmin's split of four weeks of load into low aerobic,
// high aerobic and anaerobic, from the band's own session zone minutes.
//
// Garmin splits EPOC (Firstbeat, unpublished). This splits a published load
// instead: Edwards' summated heart-rate-zone score — minutes in zone n count n
// (Edwards 1993, "High performance training and racing") — over each session's
// five-zone minutes, the same zones the app shows (edges at 50/60/70/80/90 %).
//
// The three buckets follow the three-zone model of endurance training (Seiler
// & Kjerland 2006, Scand J Med Sci Sports 16:49; Seiler 2010, IJSPP 5:276),
// whose thresholds sit near 82 % and 87 % of maximum heart rate; the nearest
// zone edges are used:
//   low aerobic  = zones 1–3  (< 80 %)
//   high aerobic = zone 4     (80–90 %)
//   anaerobic    = zone 5     (≥ 90 %)
//
// No "shortage" verdict: Garmin's target ranges are not published, and the
// research behind them (polarised training, roughly 80 % of sessions easy) is
// a description of elite endurance athletes, not a prescription for everyone.
// The card names it as a reference only.

import '../types.dart';
import '../util.dart';

const int loadFocusWindowDays = 28;
const List<int> edwardsZoneWeights = [1, 2, 3, 4, 5];

class LoadFocus {
  final double lowAerobic, highAerobic, anaerobic; // Edwards load units
  final int sessions;
  const LoadFocus(
      this.lowAerobic, this.highAerobic, this.anaerobic, this.sessions);
  double get total => lowAerobic + highAerobic + anaerobic;
  double share(double x) => total <= 0 ? 0 : x / total;
  Map<String, dynamic> toJson() => {
        'low_aerobic': round6(lowAerobic),
        'high_aerobic': round6(highAerobic),
        'anaerobic': round6(anaerobic),
        'sessions': sessions,
      };
}

/// [sessionZoneMinutes]: each session's minutes in zones 1–5 (shorter lists are
/// padded with zero), sessions of the last [loadFocusWindowDays] days only.
Metric<LoadFocus> loadFocus(List<List<num>> sessionZoneMinutes) {
  const inputs = ['session_zone_minutes'];
  var low = 0.0, high = 0.0, ana = 0.0;
  var n = 0;
  for (final z in sessionZoneMinutes) {
    double w(int i) =>
        i < z.length ? z[i].toDouble() * edwardsZoneWeights[i] : 0.0;
    final l = w(0) + w(1) + w(2), h = w(3), a = w(4);
    if (l + h + a <= 0) continue;
    low += l;
    high += h;
    ana += a;
    n++;
  }
  if (n == 0) {
    return const Metric<LoadFocus>.absent(
      tier: Tier.estimate,
      inputs_used: inputs,
      note: 'need_input:name=sessions',
    );
  }
  return Metric<LoadFocus>(
    value: LoadFocus(low, high, ana, n),
    // A handful of sessions is a thin month; eight or more is a fair picture.
    confidence: n >= 8 ? 1.0 : n / 8,
    tier: Tier.estimate,
    inputs_used: inputs,
  );
}
