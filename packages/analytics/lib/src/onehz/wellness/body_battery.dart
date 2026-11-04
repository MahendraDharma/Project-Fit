// BODY BATTERY — an energy-reserve gauge in the Garmin style, built from the
// band's own signals with every constant stated.
//
// OWNER DECISION (2026-11-01). Garmin/Firstbeat's Body Battery is not
// published: Firstbeat describes it as stress and recovery from HRV plus the
// physiological cost of activity, charging in sleep and rest and draining with
// activity and stress, and that is all. This file is a model OF THAT
// DESCRIPTION, not a copy of theirs, so its number is comparable only with
// itself. Every rate below is our choice, in the open, so it can be argued
// with and changed:
//
//   per five-minute slot (level clamped to [bodyBatteryMin, bodyBatteryMax]):
//     asleep        +bbSleepCharge × (1 − s/100)   s = that night's stress
//                                                   (unknown → bbSleepUnknownS)
//     awake, still  −bbAwakeDrain + bbRestCharge × (25 − s)/25   (s ≤ 25)
//                   −bbAwakeDrain − bbStressDrain × (s − 25)/75 (s > 25)
//     active        −(bbAwakeDrain + bbActiveDrain × x²),
//                   x = (hrr − 0.3)/0.7 clamped 0–1, hrr = heart-rate reserve
//     awake, other  −bbAwakeDrain (worn, but neither still nor active)
//     not worn      no change; the slot is a gap in the line
//   and every awake slot more than bbLateAfterHours after the last sleep
//   costs bbLateDrain more.
//
// With these: a good 7.5 h night (stress 25) charges ~68; a typical sixteen-
// hour day (mostly sitting, some of it relaxed, an hour of light activity)
// drains ~60, so a 95 morning ends near 35 at bedtime; an hour at 75 % of
// heart-rate reserve drains ~17; still being up at midnight keeps falling
// faster. Those are the shapes Garmin users report, which is the only target
// the constants were set against.
//
// REVISED 2026-11-04 (owner: "not slept, past midnight, 94 %"). The first
// constants let a still, relaxed waking slot CHARGE up to 3/h and made being
// up cost only 1.8/h, so a quiet day barely moved the gauge. Firstbeat's own
// description puts recovery mainly in sleep, with waking rest at most slowing
// the drain; resting awake now at best slows it to 1.4/h, and being up costs
// 3.6/h.
// The late-hours term follows the homeostatic sleep-pressure picture (Process
// S, Borbély 1982, Hum Neurobiol 1:195–204) and the performance cost of long
// wakefulness: 17 h awake impairs like a 0.05 % blood alcohol (Dawson & Reid
// 1997, Nature 388:235). Both are qualitative support for "later costs more",
// not sources for the number, which is ours.
//
// THE START LEVEL IS UNKNOWN, and the model says so: the caller runs it over
// several days ([bodyBatteryBurnInDays]) starting from bodyBatteryStart, and
// only the final day is shown. Each full night pulls the level towards what
// that night earned, so the guess at the start fades.
//
// Tier ESTIMATE. It invents no physiology beyond the published description,
// and the card says it is ProjectFit's own estimate.

import 'dart:math' as math;

import '../types.dart';
import '../util.dart';

const double bodyBatteryMin = 5, bodyBatteryMax = 100;
const double bodyBatteryStart = 50;
const int bodyBatteryBurnInDays = 3;
const int bodyBatterySlotSec = 300;

const double bbSleepCharge = 1.0; // per slot at stress 0 → 12/h
const double bbSleepUnknownS = 25; // a night whose stress was not measured
const double bbRestCharge = 0.18; // still and relaxed: offsets up to 2.2/h of being up
const double bbStressDrain = 0.6; // still and stressed → up to 7.2/h more
const double bbAwakeDrain = 0.3; // the cost of being up → 3.6/h
const double bbLateDrain = 0.25; // up past bbLateAfterHours → 3/h more
const double bbLateAfterHours = 16;
const double bbActiveDrain = 2.5; // + up to 30/h at maximum effort
const double bbActiveHrrFloor = 0.3; // below this, movement costs nothing extra

enum BatteryState { asleep, still, active, awake, notWorn }

class BatterySlot {
  final int tSec;
  final BatteryState state;

  /// 0–100 stress: the night's for [BatteryState.asleep], the window's for
  /// [BatteryState.still]. Null where it was not measured.
  final double? stress;

  /// Heart-rate reserve fraction, for [BatteryState.active].
  final double? hrr;
  const BatterySlot(this.tSec, this.state, {this.stress, this.hrr});
}

/// The change one slot makes, before clamping. [hoursAwake] is the time since
/// the last sleep ended (0 when unknown).
double batteryDelta(BatterySlot s, {double hoursAwake = 0}) {
  final late = hoursAwake > bbLateAfterHours ? bbLateDrain : 0.0;
  return switch (s.state) {
    BatteryState.asleep || BatteryState.notWorn => _baseDelta(s),
    _ => _baseDelta(s) - late,
  };
}

double _baseDelta(BatterySlot s) {
  switch (s.state) {
    case BatteryState.asleep:
      final st = (s.stress ?? bbSleepUnknownS).clamp(0.0, 100.0);
      return bbSleepCharge * (1 - st / 100);
    case BatteryState.still:
      final st = s.stress;
      if (st == null) return -bbAwakeDrain;
      return st <= 25
          ? -bbAwakeDrain + bbRestCharge * (25 - st) / 25
          : -bbAwakeDrain - bbStressDrain * (st - 25) / 75;
    case BatteryState.active:
      final x = (((s.hrr ?? bbActiveHrrFloor) - bbActiveHrrFloor) /
              (1 - bbActiveHrrFloor))
          .clamp(0.0, 1.0);
      return -(bbAwakeDrain + bbActiveDrain * x * x);
    case BatteryState.awake:
      return -bbAwakeDrain;
    case BatteryState.notWorn:
      return 0;
  }
}

class BatteryPoint {
  final int tSec;
  final double level;
  const BatteryPoint(this.tSec, this.level);
  Map<String, dynamic> toJson() => {'t': tSec, 'level': round6(level)};
}

class BodyBattery {
  /// Level at the end of every worn slot of the shown span (gaps omitted).
  final List<BatteryPoint> timeline;
  final double current;
  final double highest;
  final double lowest;
  final double charged; // sum of positive slot changes in the shown span
  final double drained; // sum of negative slot changes, as a positive number
  final int wornSlots;
  const BodyBattery({
    required this.timeline,
    required this.current,
    required this.highest,
    required this.lowest,
    required this.charged,
    required this.drained,
    required this.wornSlots,
  });
  Map<String, dynamic> toJson() => {
        'current': round6(current),
        'highest': round6(highest),
        'lowest': round6(lowest),
        'charged': round6(charged),
        'drained': round6(drained),
        'worn_slots': wornSlots,
        'timeline': [for (final p in timeline) p.toJson()],
      };
}

/// Run the battery over [slots] (any order; sorted here). Only slots at or
/// after [showFromSec] are reported — the rest is burn-in for the unknown
/// start level. Absent without a worn night in the burn-in (nothing has set the
/// level yet) or without [minShownWornSlots] worn slots in the shown span.
Metric<BodyBattery> bodyBattery(
  List<BatterySlot> slots, {
  required int showFromSec,
  double start = bodyBatteryStart,
  int minShownWornSlots = 12,
}) {
  const inputs = ['sleep_window', 'daytime_hrv', 'hr_curve', 'sleep_stress'];
  final xs = [...slots]..sort((a, b) => a.tSec.compareTo(b.tSec));
  final sleptBefore = xs.any((s) =>
      s.tSec < showFromSec && s.state == BatteryState.asleep);
  if (!sleptBefore) {
    return const Metric<BodyBattery>.absent(
      tier: Tier.estimate,
      inputs_used: inputs,
      note: 'need_input:name=sleep_night',
    );
  }
  var level = start;
  final pts = <BatteryPoint>[];
  var charged = 0.0, drained = 0.0;
  var worn = 0;
  int? lastSleepEnd; // when the most recent sleep slot ended
  for (final s in xs) {
    final before = level;
    if (s.state == BatteryState.asleep) lastSleepEnd = s.tSec + bodyBatterySlotSec;
    final awakeH = lastSleepEnd == null ? 0.0 : (s.tSec - lastSleepEnd) / 3600;
    level = (level + batteryDelta(s, hoursAwake: awakeH))
        .clamp(bodyBatteryMin, bodyBatteryMax)
        .toDouble();
    if (s.tSec < showFromSec || s.state == BatteryState.notWorn) continue;
    worn++;
    final d = level - before;
    if (d > 0) charged += d;
    if (d < 0) drained -= d;
    pts.add(BatteryPoint(s.tSec + bodyBatterySlotSec, level));
  }
  if (worn < minShownWornSlots) {
    return Metric<BodyBattery>.absent(
      tier: Tier.estimate,
      inputs_used: inputs,
      note: 'need_input:name=worn_slots,have=$worn,need=$minShownWornSlots',
    );
  }
  final levels = [for (final p in pts) p.level];
  return Metric<BodyBattery>(
    value: BodyBattery(
      timeline: pts,
      current: pts.last.level,
      highest: levels.reduce(math.max),
      lowest: levels.reduce(math.min),
      charged: charged,
      drained: drained,
      wornSlots: worn,
    ),
    confidence: math.min(1.0, worn / (24 * 3600 / bodyBatterySlotSec)),
    tier: Tier.estimate,
    inputs_used: inputs,
    note: 'ProjectFit model of the published Body Battery description; '
        'constants in body_battery.dart',
  );
}
