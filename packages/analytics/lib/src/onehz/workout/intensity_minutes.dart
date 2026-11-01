// INTENSITY MINUTES — Garmin's weekly activity goal, from the band's minute HR.
//
// The goal itself is the WHO / ACSM one: 150 minutes of moderate activity a
// week, or 75 vigorous, a vigorous minute counting as two (WHO 2020 guidelines;
// Garber et al. 2011, ACSM position stand, Med Sci Sports Exerc 43:1334).
//
// Which minutes count — every rule stated:
//   * intensity from heart-rate reserve, ACSM's bands: moderate 40–59 % HRR,
//     vigorous 60 % and up (Garber 2011, Table 1);
//   * only inside a bout of at least [imMinBoutMinutes] consecutive minutes at
//     moderate or above, as Garmin counts them (WHO 2020 dropped the bout rule;
//     Garmin kept it, and so does this, so a flight of stairs is not exercise);
//   * a minute with no heart-rate reading ends the bout — a gap is not effort.
//
// Garmin's default compares heart rate with resting heart rate in the same
// spirit; its exact cut-offs are not published, so these are ACSM's, not
// Garmin's. Tier ESTIMATE: wrist optical HR, Tanaka-estimated ceiling unless
// the caller has a better one.

import 'dart:math' as math;

import '../types.dart';

const double imModerateHrr = 0.40;
const double imVigorousHrr = 0.60;
const int imMinBoutMinutes = 10;
const int imWeeklyTarget = 150;

class IntensityDay {
  final int moderate; // minutes
  final int vigorous; // minutes
  const IntensityDay(this.moderate, this.vigorous);

  /// Moderate-equivalent minutes: a vigorous minute counts as two.
  int get total => moderate + 2 * vigorous;
  Map<String, dynamic> toJson() =>
      {'moderate': moderate, 'vigorous': vigorous, 'total': total};
}

/// One day's intensity minutes from its minute heart rate ([minuteHr], epoch
/// seconds on minute boundaries; any order).
IntensityDay intensityMinutesOfDay(
  List<({int tSec, double bpm})> minuteHr, {
  required double restingHr,
  required double maxHr,
}) {
  if (maxHr <= restingHr) return const IntensityDay(0, 0);
  final xs = [...minuteHr]..sort((a, b) => a.tSec.compareTo(b.tSec));
  var mod = 0, vig = 0;
  var runMod = 0, runVig = 0;
  int? prevT;
  void close() {
    if (runMod + runVig >= imMinBoutMinutes) {
      mod += runMod;
      vig += runVig;
    }
    runMod = 0;
    runVig = 0;
  }

  for (final m in xs) {
    final hrr = (m.bpm - restingHr) / (maxHr - restingHr);
    final contiguous = prevT != null && m.tSec - prevT == 60;
    if (!contiguous) close();
    if (hrr >= imVigorousHrr) {
      runVig++;
    } else if (hrr >= imModerateHrr) {
      runMod++;
    } else {
      close();
    }
    prevT = m.tSec;
  }
  close();
  return IntensityDay(mod, vig);
}

class IntensityWeek {
  final List<IntensityDay?> days; // oldest first; null = no heart rate that day
  const IntensityWeek(this.days);
  int get total => days.fold(0, (s, d) => s + (d?.total ?? 0));
  int get moderate => days.fold(0, (s, d) => s + (d?.moderate ?? 0));
  int get vigorous => days.fold(0, (s, d) => s + (d?.vigorous ?? 0));
  Map<String, dynamic> toJson() => {
        'total': total,
        'moderate': moderate,
        'vigorous': vigorous,
        'target': imWeeklyTarget,
        'days': [for (final d in days) d?.toJson()],
      };
}

/// The week's figure. Absent with no measured day at all — a week the band was
/// off is not a week of zero activity.
Metric<IntensityWeek> intensityWeek(List<IntensityDay?> days) {
  const inputs = ['hr_curve', 'resting_hr', 'max_hr'];
  final measured = days.where((d) => d != null).length;
  if (measured == 0) {
    return const Metric<IntensityWeek>.absent(
      tier: Tier.estimate,
      inputs_used: inputs,
      note: 'need_input:name=wake_hr',
    );
  }
  return Metric<IntensityWeek>(
    value: IntensityWeek(days),
    confidence: math.min(1.0, measured / math.max(1, days.length)),
    tier: Tier.estimate,
    inputs_used: inputs,
  );
}
