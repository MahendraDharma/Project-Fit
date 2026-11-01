// VO2MAX FROM ROUTINE + FITNESS AGE — the HUNT Study's non-exercise model.
//
// OWNER DECISION (2026-11-01): VO2max from the band alone (no phone GPS),
// taken from the wearer's routine, plus a fitness age. The one published way
// to do that without an exercise test is a non-exercise prediction model.
//
// MODEL — Nes BM et al., "Estimating VO2peak from a nonexercise prediction
// model: the HUNT Study, Norway", Med Sci Sports Exerc 2011;43(11):2024–30.
// 4,637 healthy adults with directly measured VO2peak; age, waist, leisure
// activity and resting HR were the strongest predictors; R² 0.61 (men) and
// 0.56 (women), SEE 5.70 and 5.14 mL/kg/min. Waist-circumference form:
//
//   men    100.27 − 0.296·age − 0.369·waist − 0.155·RHR + 0.226·PA
//   women  74.736 − 0.247·age − 0.259·waist − 0.114·RHR + 0.198·PA
//
// Coefficients checked against the peer-reviewed reprint of the equation in
// Table 1 of "Accuracy of Nonexercise Prediction Equations for Assessing
// Longitudinal Changes to Cardiorespiratory Fitness", J Am Heart Assoc 2020
// (PMC7428991); the women's constant there is 74.736. The BMI form
// (Jalene et al. 2019, Front Physiol 10:1191, quoting Nes et al.) is kept as
// [vo2maxHuntBmi] for a profile without a waist.
//
// PA INDEX — HUNT's questionnaire, as the HUNT group itself defines it
// (Nauman et al. 2012, PLoS One, PMC3445602; Loe et al. 2013, PLoS One,
// PMC3654926): frequency (0, 0, 1, 2.5, 5 for never, < 1, 1, 2–3 a week,
// almost every day) × intensity (1, 2, 3: easy, breathless and sweating, near
// exhaustion) × duration (0.10, 0.38, 0.75, 1.0 for < 15, 15–29, 30–60,
// > 60 min), 0–15. (JAHA 2020 tabulates a 0–45 scale; that is its own
// conversion, not the index.) HERE IT IS READ OFF THE BAND, NOT ASKED:
// the last 4 weeks of sessions give the frequency and the median duration,
// and each session's mean heart-rate reserve gives the intensity — under 50 %
// is "easy", 50–75 % "breathless", 75 % and over "near exhaustion". Those three
// cut-offs and "4+ a week = almost every day" are OUR mapping.
//
// KNOWN BIAS, written where it bites: HUNT measured resting HR seated; the band
// gives the overnight one, typically a few beats lower, which moves VO2max up
// by ~0.1–0.15 mL/kg/min per beat. Like every non-exercise model this one also
// overestimates the least fit (Nes 2011; Jackson-model validations).
//
// FITNESS AGE — the age whose HUNT3 average VO2max equals the estimate, read
// off NTNU CERG's published means (20–29 … over 70) by straight lines between
// decade midpoints. Not Garmin's model (unpublished) nor a calculator's
// "0.3 per year" convention.
//
// NO DOUBLE COUNTING. Resting HR is an input here and is shown on its own
// elsewhere; this estimate must never feed Readiness or any score that already
// uses resting HR (the reason OpenStrap deleted its k·HRmax/RHR "VO2max").

import 'dart:math' as math;

import '../types.dart';
import '../util.dart';

/// One session of the last four weeks.
class RoutineSession {
  final double minutes;

  /// Mean heart-rate reserve fraction over the session, 0–1; null unknown.
  final double? meanHrr;
  const RoutineSession(this.minutes, {this.meanHrr});
}

const int paIndexWindowDays = 28;

class PaIndex {
  final double frequency, duration, intensity;
  final double sessionsPerWeek;
  const PaIndex(
      this.frequency, this.duration, this.intensity, this.sessionsPerWeek);
  double get value => frequency * duration * intensity;
  Map<String, dynamic> toJson() => {
        'value': round6(value),
        'frequency': frequency,
        'duration': duration,
        'intensity': intensity,
        'sessions_per_week': round6(sessionsPerWeek),
      };
}

double paFrequencyScore(double perWeek) => perWeek < 1
    ? 0
    : (perWeek < 2 ? 1 : (perWeek < 4 ? 2.5 : 5));

double paDurationScore(double minutes) => minutes < 15
    ? 0.10
    : (minutes < 30 ? 0.38 : (minutes <= 60 ? 0.75 : 1.0));

double paIntensityScore(double meanHrr) =>
    meanHrr < 0.5 ? 1 : (meanHrr < 0.75 ? 2 : 3);

/// The PA index from the sessions of the last [paIndexWindowDays] days.
/// No sessions is a real answer (index 0), not a missing one. Sessions without
/// a heart-rate reading do not vote on intensity; with none, intensity is 1.
PaIndex paIndexFromSessions(List<RoutineSession> sessions) {
  final perWeek = sessions.length / (paIndexWindowDays / 7);
  final f = paFrequencyScore(perWeek);
  if (sessions.isEmpty) return PaIndex(0, 0.10, 1, 0);
  final d = paDurationScore(median([for (final s in sessions) s.minutes])!);
  final hrrs = [
    for (final s in sessions)
      if (s.meanHrr != null && s.meanHrr!.isFinite) s.meanHrr!
  ];
  final i = hrrs.isEmpty ? 1.0 : paIntensityScore(median(hrrs)!);
  return PaIndex(f, d, i, perWeek);
}

/// HUNT waist model. [sex] 'male' | 'female' | 'nonbinary' (mean of the two,
/// the app's convention for coefficient tables).
double vo2maxHuntWaist({
  required String sex,
  required double age,
  required double waistCm,
  required double restingHr,
  required double paIndex,
}) {
  double men() =>
      100.27 - 0.296 * age - 0.369 * waistCm - 0.155 * restingHr + 0.226 * paIndex;
  double women() =>
      74.736 - 0.247 * age - 0.259 * waistCm - 0.114 * restingHr + 0.198 * paIndex;
  return switch (sex) {
    'male' => men(),
    'female' => women(),
    _ => (men() + women()) / 2,
  };
}

/// HUNT BMI model (Jalene et al. 2019 quoting Nes et al.).
double vo2maxHuntBmi({
  required String sex,
  required double age,
  required double bmi,
  required double restingHr,
  required double paIndex,
}) {
  double men() =>
      92.05 - 0.327 * age - 0.933 * bmi - 0.167 * restingHr + 0.257 * paIndex;
  double women() =>
      70.77 - 0.244 * age - 0.749 * bmi - 0.107 * restingHr + 0.213 * paIndex;
  return switch (sex) {
    'male' => men(),
    'female' => women(),
    _ => (men() + women()) / 2,
  };
}

/// HUNT3 mean VO2max (mL/kg/min) by decade, NTNU CERG "Fitness numbers":
/// 20–29, 30–39, 40–49, 50–59, 60–69, over 70. Placed at decade midpoints.
const List<double> huntDecadeMid = [25, 35, 45, 55, 65, 75];
const List<double> huntMeanMen = [54, 49, 47, 42, 39, 34];
const List<double> huntMeanWomen = [43, 40, 38, 34, 31, 27];

List<double> _meansFor(String sex) => switch (sex) {
      'male' => huntMeanMen,
      'female' => huntMeanWomen,
      _ => [
          for (var i = 0; i < huntMeanMen.length; i++)
            (huntMeanMen[i] + huntMeanWomen[i]) / 2
        ],
    };

/// HUNT3 average VO2max at [age] (straight lines between decade midpoints,
/// extended past the ends with the end slopes).
double huntAverageVo2max(String sex, double age) {
  final m = _meansFor(sex);
  const x = huntDecadeMid;
  var i = 0;
  while (i < x.length - 2 && age > x[i + 1]) {
    i++;
  }
  final t = (age - x[i]) / (x[i + 1] - x[i]);
  return m[i] + t * (m[i + 1] - m[i]);
}

/// The age at which the HUNT3 average equals [vo2max], clamped to 20–90.
double fitnessAgeFor(String sex, double vo2max) {
  final m = _meansFor(sex);
  const x = huntDecadeMid;
  // Means fall with age, so find the segment that brackets vo2max.
  var i = 0;
  while (i < x.length - 2 && vo2max < m[i + 1]) {
    i++;
  }
  final t = (vo2max - m[i]) / (m[i + 1] - m[i]);
  return (x[i] + t * (x[i + 1] - x[i])).clamp(20.0, 90.0).toDouble();
}

class RoutineFitness {
  final double vo2max; // mL/kg/min
  final double seeMlKgMin; // the model's standard error of estimate
  final double fitnessAge;
  final double averageForAge; // HUNT3 mean at the wearer's age
  final PaIndex pa;
  final double restingHr;
  final bool fromWaist; // false = BMI form
  const RoutineFitness({
    required this.vo2max,
    required this.seeMlKgMin,
    required this.fitnessAge,
    required this.averageForAge,
    required this.pa,
    required this.restingHr,
    required this.fromWaist,
  });
  Map<String, dynamic> toJson() => {
        'vo2max': round6(vo2max),
        'see': seeMlKgMin,
        'fitness_age': round6(fitnessAge),
        'average_for_age': round6(averageForAge),
        'pa_index': pa.toJson(),
        'resting_hr': round6(restingHr),
        'model': fromWaist ? 'hunt_waist' : 'hunt_bmi',
      };
}

/// The minimum overnight resting-HR nights the estimate reads (median).
const int routineFitnessMinRhrNights = 7;

/// VO2max from routine and fitness age. [nightlyRhr] is recent nights, oldest
/// first (the median of the last 14 is used). [waistCm] preferred; [bmi] is
/// the fallback. Absent without age, sex-free tables are not guessed: an
/// unknown sex uses the mean of the two published sets, as elsewhere.
Metric<RoutineFitness> routineFitness({
  required double? age,
  required String sex,
  required double? waistCm,
  double? bmi,
  required List<double?> nightlyRhr,
  required List<RoutineSession> sessions,
}) {
  const inputs = ['age', 'sex', 'waist_cm', 'nightly_rhr', 'sessions'];
  if (age == null || age < 18) {
    return const Metric<RoutineFitness>.absent(
        tier: Tier.estimate, inputs_used: inputs, note: 'need_input:name=age');
  }
  if (waistCm == null && bmi == null) {
    return const Metric<RoutineFitness>.absent(
        tier: Tier.estimate,
        inputs_used: inputs,
        note: 'need_input:name=waist_cm');
  }
  final rhrs = [
    for (final v in nightlyRhr.sublist(math.max(0, nightlyRhr.length - 14)))
      if (v != null && v.isFinite && v > 25 && v < 120) v
  ];
  if (rhrs.length < routineFitnessMinRhrNights) {
    return Metric<RoutineFitness>.absent(
      tier: Tier.estimate,
      inputs_used: inputs,
      note: needBaselineNote(have: rhrs.length, need: routineFitnessMinRhrNights),
    );
  }
  final rhr = median(rhrs)!;
  final pa = paIndexFromSessions(sessions);
  final fromWaist = waistCm != null;
  final v = fromWaist
      ? vo2maxHuntWaist(
          sex: sex, age: age, waistCm: waistCm, restingHr: rhr, paIndex: pa.value)
      : vo2maxHuntBmi(
          sex: sex, age: age, bmi: bmi!, restingHr: rhr, paIndex: pa.value);
  final see = sex == 'female' ? 5.14 : (sex == 'male' ? 5.70 : 5.42);
  return Metric<RoutineFitness>(
    value: RoutineFitness(
      vo2max: v,
      seeMlKgMin: see,
      fitnessAge: fitnessAgeFor(sex, v),
      averageForAge: huntAverageVo2max(sex, age),
      pa: pa,
      restingHr: rhr,
      fromWaist: fromWaist,
    ),
    // R² of the model: the share of VO2max it explains at best.
    confidence: sex == 'female' ? 0.56 : 0.61,
    tier: Tier.estimate,
    inputs_used: inputs,
  );
}
