// MUSCLE VOLUME — sets per muscle group from logged strength sets.
//
// Counting rule: resistance-training volume is counted in SETS, the unit the
// dose-response literature uses (Schoenfeld, Ogborn & Krieger 2017,
// J Sports Sci; Pelland et al. 2024, "The Resistance Training Dose Response").
// A set counts 1 for each of its exercise's PRIMARY muscles and 0.5 for each
// SECONDARY muscle — the "fractional" counting Pelland et al. found to fit
// better than counting only direct work. How heavy the set was does not change
// how many sets it is; tonnage (load × reps) is reported beside it, and only
// over the sets whose load was actually recorded.
//
// HARD sets: a set logged at RPE ≥ 7, i.e. about three or fewer reps in reserve
// on the RIR-based RPE scale (Zourdos et al. 2016). A set with no RPE is
// neither hard nor easy: hard-set counts are null, not zero, when no set in the
// window carried an RPE.
//
// HONESTY: this counts what was logged. It does not estimate effort for sets
// nobody rated, invent a load for bodyweight work, or fold muscular work into
// the cardiovascular strain score (there is no published exchange rate between
// the two, so any such blend would be a constant chosen by nobody).

import '../types.dart';
import '../util.dart' show round6;

/// RPE at or above which a set counts as hard (≈ ≤3 reps in reserve).
const int hardSetMinRpe = 7;

/// Weight of a set for each secondary muscle of its exercise.
const double secondaryMuscleSetWeight = 0.5;

/// One logged set, with its exercise's muscles already resolved.
class StrengthSetInput {
  final String exerciseKey;
  final int reps;
  final double? loadKg; // null: not recorded (e.g. bodyweight work)
  final int? rpe; // null: not rated
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;

  const StrengthSetInput({
    required this.exerciseKey,
    required this.reps,
    this.loadKg,
    this.rpe,
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
  });
}

class MuscleVolume {
  /// Fractional sets per muscle (primary 1, secondary 0.5).
  final Map<String, double> setsByMuscle;

  /// Fractional HARD sets per muscle, or null when no set carried an RPE.
  final Map<String, double>? hardSetsByMuscle;

  final int totalSets;
  final int ratedSets; // sets with an RPE
  final int unmappedSets; // sets whose exercise names no muscle

  /// Σ load × reps over the sets with a recorded load, or null when none had one.
  final double? tonnageKg;
  final int unloadedSets; // sets left out of [tonnageKg]

  const MuscleVolume({
    required this.setsByMuscle,
    required this.hardSetsByMuscle,
    required this.totalSets,
    required this.ratedSets,
    required this.unmappedSets,
    required this.tonnageKg,
    required this.unloadedSets,
  });

  Map<String, dynamic> toJson() => {
        'sets_by_muscle': {
          for (final e in setsByMuscle.entries) e.key: round6(e.value)
        },
        if (hardSetsByMuscle != null)
          'hard_sets_by_muscle': {
            for (final e in hardSetsByMuscle!.entries) e.key: round6(e.value)
          },
        'total_sets': totalSets,
        'rated_sets': ratedSets,
        'unmapped_sets': unmappedSets,
        if (tonnageKg != null) 'tonnage_kg': round6(tonnageKg!),
        'unloaded_sets': unloadedSets,
      };
}

/// Sets per muscle group over [sets] (any window: one session or a week).
///
/// Absent when there are no sets with at least one rep.
Metric<MuscleVolume> muscleVolume(List<StrengthSetInput> sets) {
  const inputs = ['strength_sets', 'exercise_muscles'];
  final counted = [for (final s in sets) if (s.reps > 0) s];
  if (counted.isEmpty) {
    return const Metric<MuscleVolume>.absent(
      tier: Tier.auth,
      inputs_used: inputs,
      note: 'no_strength_sets',
    );
  }

  final bySets = <String, double>{};
  final byHard = <String, double>{};
  var rated = 0, unmapped = 0, unloaded = 0;
  double? tonnage;

  void add(Map<String, double> into, String muscle, double w) =>
      into[muscle] = (into[muscle] ?? 0) + w;

  for (final s in counted) {
    // A muscle listed as both primary and secondary counts once, as primary.
    final primary = s.primaryMuscles.toSet();
    final secondary = s.secondaryMuscles.toSet().difference(primary);
    if (primary.isEmpty && secondary.isEmpty) unmapped++;
    final hard = s.rpe != null && s.rpe! >= hardSetMinRpe;
    if (s.rpe != null) rated++;
    for (final m in primary) {
      add(bySets, m, 1);
      if (hard) add(byHard, m, 1);
    }
    for (final m in secondary) {
      add(bySets, m, secondaryMuscleSetWeight);
      if (hard) add(byHard, m, secondaryMuscleSetWeight);
    }
    if (s.loadKg == null) {
      unloaded++;
    } else {
      tonnage = (tonnage ?? 0) + s.loadKg! * s.reps;
    }
  }

  return Metric<MuscleVolume>(
    value: MuscleVolume(
      setsByMuscle: bySets,
      hardSetsByMuscle: rated == 0 ? null : byHard,
      totalSets: counted.length,
      ratedSets: rated,
      unmappedSets: unmapped,
      tonnageKg: tonnage,
      unloadedSets: unloaded,
    ),
    // Counted from the user's own log: exact for what was logged.
    confidence: 1,
    tier: Tier.auth,
    inputs_used: inputs,
    note: unmapped > 0 ? 'unmapped_sets=$unmapped' : null,
  );
}
