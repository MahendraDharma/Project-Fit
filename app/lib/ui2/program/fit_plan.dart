// FIT PROGRAM — "get fit in N days": a day-by-day schedule of strength,
// cardio and rest, built from what the person has (calisthenics or a gym, and
// which equipment) and how often they can train.
//
// Pure and deterministic: the same choices always give the same plan, so it is
// stored as its CHOICES and rebuilt, and it is tested like any other rule.
//
// The shape follows the public guidelines rather than inventing one:
//   • Aerobic work 150–300 min a week at moderate intensity (or 75–150 vigorous),
//     and muscle strengthening on 2 or more days a week — WHO 2020 guidelines
//     (Bull et al. 2020, Br J Sports Med 54:1451–1462).
//   • Resistance training for general fitness: 2–4 sets of 8–12 reps for each
//     major muscle group, 2–3 days a week, 48 h between sessions for the same
//     muscles; fewer reps and more sets for strength — ACSM position stand
//     (Garber et al. 2011, Med Sci Sports Exerc 43:1334–1359).
//   • More weekly sets per muscle gives more muscle, with diminishing returns
//     (Schoenfeld, Ogborn & Krieger 2017, J Sports Sci 35:1073–1082): hence
//     sets rise across a block.
//   • For weight loss, 150–250 min/week of moderate activity gives modest loss
//     and more than 250 min clinically significant loss — ACSM position stand
//     (Donnelly et al. 2009, Med Sci Sports Exerc 41:459–471): hence 225 for
//     the fat-loss goal.
//   • Progressive overload with a lighter fourth week (a deload), the common
//     periodisation practice; the 3:1 rhythm is our choice, not a finding.
//   Weekly cardio is planned against a target (WHO's 150, or 225 for fat loss),
//   an interval minute counting as two (WHO counts vigorous minutes double);
//   what the cardio days leave over is a short finisher after lifting. A
//   beginner starts at 60 % of it and adds 10 % a week.
// The numbers that turn those ranges into one plan (which minutes, which rep
// counts, the +2 reps a week) are ours, stated here, and can be changed.

import 'dart:convert';

import '../activity/catalogue.dart';

enum FitGoal { general, strength, fatLoss }

enum FitStyle { calisthenics, gym }

enum FitLevel { beginner, intermediate }

/// What the person has to train with. A gym implies most of these; at home
/// they tick what is there.
enum Equip {
  pullUpBar,
  dipBars,
  bench,
  dumbbells,
  kettlebell,
  barbell,
  cableMachine,
  machines,
  abWheel,
  jumpRope,
  treadmill,
  indoorBike,
  rower,
}

const Set<Equip> gymEquipment = {
  Equip.pullUpBar,
  Equip.dipBars,
  Equip.bench,
  Equip.dumbbells,
  Equip.kettlebell,
  Equip.barbell,
  Equip.cableMachine,
  Equip.machines,
  Equip.treadmill,
  Equip.indoorBike,
  Equip.rower,
};

/// The equipment a style starts with ticked: a gym has it all; calisthenics
/// starts with nothing and the person adds their bar, rings or rope.
Set<Equip> defaultEquipment(FitStyle s) =>
    s == FitStyle.gym ? gymEquipment : const {};

/// The person's choices. The plan is rebuilt from these.
class FitPlanConfig {
  final int days;
  final FitGoal goal;
  final FitStyle style;
  final FitLevel level;
  final int daysPerWeek; // training days, 3–6
  final Set<Equip> equipment;
  final DateTime start; // local date of day 1

  const FitPlanConfig({
    required this.days,
    required this.goal,
    required this.style,
    required this.level,
    required this.daysPerWeek,
    required this.equipment,
    required this.start,
  });

  Map<String, Object?> toJson() => {
        'days': days,
        'goal': goal.name,
        'style': style.name,
        'level': level.name,
        'per_week': daysPerWeek,
        'equipment': [for (final e in equipment) e.name],
        'start': '${start.year}-${start.month}-${start.day}',
      };

  static FitPlanConfig? fromJson(Object? j) {
    if (j is! Map) return null;
    T? pick<T extends Enum>(List<T> all, Object? n) {
      for (final v in all) {
        if (v.name == n) return v;
      }
      return null;
    }

    final start = '${j['start']}'.split('-').map(int.tryParse).toList();
    final goal = pick(FitGoal.values, j['goal']);
    final style = pick(FitStyle.values, j['style']);
    final level = pick(FitLevel.values, j['level']);
    final days = (j['days'] as num?)?.toInt();
    final per = (j['per_week'] as num?)?.toInt();
    if (goal == null ||
        style == null ||
        level == null ||
        days == null ||
        per == null ||
        start.length != 3 ||
        start.contains(null)) {
      return null;
    }
    return FitPlanConfig(
      days: days.clamp(7, 365),
      goal: goal,
      style: style,
      level: level,
      daysPerWeek: per.clamp(3, 6),
      equipment: {
        for (final n in (j['equipment'] as List? ?? const []))
          ?pick(Equip.values, n),
      },
      start: DateTime(start[0]!, start[1]!, start[2]!),
    );
  }

  String encode() => jsonEncode(toJson());
  static FitPlanConfig? decode(String s) {
    if (s.isEmpty) return null;
    try {
      return fromJson(jsonDecode(s));
    } catch (_) {
      return null;
    }
  }
}

enum DayKind { strength, cardio, rest }

/// Which strength session a day is.
enum Session { fullA, fullB, upper, lower }

/// One exercise on a strength day: [reps] or, for a hold, [seconds].
class PlanItem {
  final String exerciseKey;
  final int sets;
  final int? reps;
  final int? seconds;
  final int restSec;
  const PlanItem(this.exerciseKey,
      {required this.sets, this.reps, this.seconds, required this.restSec});
}

/// The cardio on a cardio day.
class PlanCardio {
  /// An [Activity] type key from the catalogue (`running`, `indoor_bike` …).
  final String activityKey;
  final int minutes;

  /// Intervals (1 min hard, 1 min easy) instead of a steady moderate pace.
  final bool intervals;
  const PlanCardio(this.activityKey, this.minutes, {this.intervals = false});
}

class PlanDay {
  final int index; // 0-based day of the program
  final DateTime date;
  final int week; // 1-based
  final DayKind kind;
  final Session? session;
  final List<PlanItem> items;
  final PlanCardio? cardio;

  /// Steady cardio after the lifting, on a strength day.
  final PlanCardio? finisher;

  /// The fourth week of each block, lighter on purpose.
  final bool deload;
  const PlanDay({
    required this.index,
    required this.date,
    required this.week,
    required this.kind,
    this.session,
    this.items = const [],
    this.cardio,
    this.finisher,
    this.deload = false,
  });
}

// ── what each slot of a session can be ──

enum Pattern { squat, hinge, lunge, pushH, pushV, pullV, pullH, core, arms, calves }

/// One candidate for a slot: an exercise ([key], or a catalogue [label] for
/// a wger row), what it needs, and whether it is too hard for a beginner.
class _Option {
  final String? key;
  final String? label;
  final Set<Equip> needs;
  final bool advanced;
  final bool hold; // timed, not counted
  const _Option.k(this.key, {this.needs = const {}, this.advanced = false, this.hold = false})
      : label = null;
  const _Option.l(this.label, {this.needs = const {}}) : key = null, advanced = false, hold = false;
}

const _gym = <Pattern, List<_Option>>{
  Pattern.squat: [
    _Option.k('back_squat', needs: {Equip.barbell}),
    _Option.k('leg_press', needs: {Equip.machines}),
    _Option.l('Dumbbell Goblet Squat', needs: {Equip.dumbbells}),
    _Option.k('bodyweight_squat'),
  ],
  Pattern.hinge: [
    _Option.k('romanian_deadlift', needs: {Equip.barbell}),
    _Option.l('Dumbbell Romanian Deadlift', needs: {Equip.dumbbells}),
    _Option.l('Kettlebell deadlifts', needs: {Equip.kettlebell}),
    _Option.k('glute_bridge'),
  ],
  Pattern.lunge: [
    _Option.l('Bulgarian Squat with Dumbbells', needs: {Equip.dumbbells, Equip.bench}),
    _Option.l('Dumbbell Lunges Walking', needs: {Equip.dumbbells}),
    _Option.k('lunge'),
  ],
  Pattern.pushH: [
    _Option.k('bench_press', needs: {Equip.barbell, Equip.bench}),
    _Option.l('Benchpress Dumbbells', needs: {Equip.dumbbells, Equip.bench}),
    _Option.l('Machine Chest Press', needs: {Equip.machines}),
    _Option.k('push_up'),
  ],
  Pattern.pushV: [
    _Option.k('overhead_press', needs: {Equip.barbell}),
    _Option.l('Shoulder Press, Dumbbells', needs: {Equip.dumbbells}),
    _Option.l('Shoulder Press, on Machine', needs: {Equip.machines}),
    _Option.k('pike_push_up'),
  ],
  Pattern.pullV: [
    _Option.k('lat_pulldown', needs: {Equip.cableMachine}),
    _Option.k('pull_up', needs: {Equip.pullUpBar}, advanced: true),
    _Option.l('Machine Lat Pulldown', needs: {Equip.machines}),
    _Option.k('chin_up', needs: {Equip.pullUpBar}),
    _Option.l('Bent Over Dumbbell Rows (Single Arm)', needs: {Equip.dumbbells}),
    _Option.k('superman'),
  ],
  Pattern.pullH: [
    _Option.k('barbell_row', needs: {Equip.barbell}),
    _Option.l('Seated Cable Row', needs: {Equip.cableMachine}),
    _Option.l('Bent Over Dumbbell Rows (Single Arm)', needs: {Equip.dumbbells}),
    _Option.k('inverted_row', needs: {Equip.pullUpBar}),
    _Option.k('superman'),
  ],
  Pattern.core: [
    _Option.k('hanging_leg_raise', needs: {Equip.pullUpBar}, advanced: true),
    _Option.k('plank', hold: true),
    _Option.k('dead_bug'),
    _Option.k('side_plank', hold: true),
  ],
  Pattern.arms: [
    _Option.l('Dumbbell Curl', needs: {Equip.dumbbells}),
    _Option.k('barbell_curl', needs: {Equip.barbell}),
    _Option.k('triceps_pushdown', needs: {Equip.cableMachine}),
    _Option.k('bench_dip', needs: {Equip.bench}),
    _Option.k('diamond_push_up'),
  ],
  Pattern.calves: [_Option.k('calf_raise')],
};

const _cali = <Pattern, List<_Option>>{
  Pattern.squat: [
    _Option.k('pistol_squat', advanced: true),
    _Option.k('jump_squat', advanced: true),
    _Option.k('bodyweight_squat'),
  ],
  Pattern.hinge: [
    _Option.l('Kettlebell deadlifts', needs: {Equip.kettlebell}),
    _Option.l('Dumbbell Romanian Deadlift', needs: {Equip.dumbbells}),
    _Option.k('glute_bridge'),
    _Option.k('superman'),
  ],
  Pattern.lunge: [
    _Option.l('Bulgarian Squat with Dumbbells', needs: {Equip.dumbbells, Equip.bench}),
    _Option.k('lunge'),
  ],
  Pattern.pushH: [
    _Option.k('dip', needs: {Equip.dipBars}, advanced: true),
    _Option.k('diamond_push_up', advanced: true),
    _Option.k('push_up'),
    _Option.k('incline_push_up'),
  ],
  Pattern.pushV: [
    _Option.k('handstand_push_up', advanced: true),
    _Option.k('pike_push_up'),
  ],
  Pattern.pullV: [
    _Option.k('pull_up', needs: {Equip.pullUpBar}, advanced: true),
    _Option.k('chin_up', needs: {Equip.pullUpBar}),
    _Option.l('Bent Over Dumbbell Rows (Single Arm)', needs: {Equip.dumbbells}),
    _Option.k('superman'),
  ],
  Pattern.pullH: [
    _Option.k('inverted_row', needs: {Equip.pullUpBar}),
    _Option.l('Bent Over Dumbbell Rows (Single Arm)', needs: {Equip.dumbbells}),
    _Option.k('superman'),
  ],
  Pattern.core: [
    _Option.k('hanging_leg_raise', needs: {Equip.pullUpBar}, advanced: true),
    _Option.k('ab_wheel_rollout', needs: {Equip.abWheel}, advanced: true),
    _Option.k('plank', hold: true),
    _Option.k('dead_bug'),
    _Option.k('side_plank', hold: true),
    _Option.k('mountain_climber'),
  ],
  Pattern.arms: [
    _Option.k('chin_up', needs: {Equip.pullUpBar}),
    _Option.k('bench_dip', needs: {Equip.bench}),
    _Option.k('diamond_push_up'),
  ],
  Pattern.calves: [_Option.k('calf_raise')],
};

const _sessions = <Session, List<Pattern>>{
  Session.fullA: [Pattern.squat, Pattern.pushH, Pattern.pullV, Pattern.hinge, Pattern.core],
  Session.fullB: [Pattern.lunge, Pattern.pushV, Pattern.pullH, Pattern.hinge, Pattern.core],
  Session.upper: [Pattern.pushH, Pattern.pullV, Pattern.pushV, Pattern.pullH, Pattern.arms, Pattern.core],
  Session.lower: [Pattern.squat, Pattern.hinge, Pattern.lunge, Pattern.calves, Pattern.core],
};

/// The catalogue key behind an option, or null when it is not in the
/// catalogue (a wger row renamed upstream).
String? _resolve(_Option o) {
  if (o.key != null) return exerciseByKey(o.key!) == null ? null : o.key;
  String norm(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  final want = norm(o.label!);
  for (final e in exerciseLibrary) {
    if (norm(e.label) == want) return e.key;
  }
  return null;
}

/// Every exercise the tables name resolves in the catalogue (a test holds it).
List<String> unresolvedPlanExercises() => [
      for (final table in [_gym, _cali])
        for (final opts in table.values)
          for (final o in opts)
            if (_resolve(o) == null) o.key ?? o.label!,
    ];

/// Pick the exercise for [p]: the first the equipment and level allow. [alt]
/// takes the second allowed one when there is one, so two sessions of the
/// same pattern in a week are not the same lift.
(String, bool)? _pick(FitPlanConfig c, Pattern p, {bool alt = false}) {
  final table = c.style == FitStyle.gym ? _gym : _cali;
  final ok = [
    for (final o in table[p]!)
      if (c.equipment.containsAll(o.needs) &&
          (c.level == FitLevel.intermediate || !o.advanced))
        if (_resolve(o) case final k?) (k, o.hold),
  ];
  if (ok.isEmpty) return null;
  return alt && ok.length > 1 ? ok[1] : ok.first;
}

/// Which weekdays (0 = the plan's first weekday) train, and how: S strength,
/// C cardio. The rest are rest days.
List<DayKind?> _week(FitGoal g, int n) {
  const at = {
    3: [0, 2, 4],
    4: [0, 1, 3, 4],
    5: [0, 1, 2, 4, 5],
    6: [0, 1, 2, 3, 4, 5],
  };
  const s = DayKind.strength, k = DayKind.cardio;
  final kinds = switch (g) {
    FitGoal.strength => {3: [s, s, s], 4: [s, s, k, s], 5: [s, s, k, s, s], 6: [s, s, k, s, s, k]},
    FitGoal.fatLoss => {3: [s, k, s], 4: [s, k, s, k], 5: [k, s, k, s, k], 6: [s, k, s, k, s, k]},
    FitGoal.general => {3: [s, k, s], 4: [s, k, s, k], 5: [s, k, s, k, s], 6: [s, k, s, k, s, k]},
  }[n]!;
  final out = List<DayKind?>.filled(7, null);
  for (var i = 0; i < kinds.length; i++) {
    out[at[n]![i]] = kinds[i];
  }
  return out;
}

/// Sets, reps or seconds, and rest for an exercise in [week] (1-based).
PlanItem _dose(FitPlanConfig c, String key, bool hold, int week, bool deload) {
  final block = (week - 1) % 4; // 0,1,2 build; 3 deload
  final base = switch (c.goal) {
    FitGoal.strength => (sets: 4, reps: 6, rest: 150),
    FitGoal.fatLoss => (sets: 3, reps: 12, rest: 60),
    FitGoal.general => (sets: 3, reps: 10, rest: 90),
  };
  var sets = base.sets - (c.level == FitLevel.beginner ? 1 : 0);
  if (block == 2) sets += 1; // the third week adds a set
  if (deload) sets = (sets - 1).clamp(1, 9);
  final body = exerciseByKey(key)?.bodyweight ?? false;
  final blocksDone = (week - 1) ~/ 4; // each block starts a little harder
  if (hold) {
    final sec = (20 + 5 * blocksDone + 5 * (deload ? 0 : block)).clamp(20, 90);
    return PlanItem(key, sets: sets, seconds: sec, restSec: 45);
  }
  // A load can grow; a bodyweight move grows in reps instead, two a week.
  final reps = body
      ? (base.reps + 2 * (deload ? 0 : block) + 2 * blocksDone).clamp(5, 25)
      : base.reps;
  return PlanItem(key, sets: sets, reps: reps, restSec: base.rest);
}

/// The steady cardio activity the equipment allows.
String _steady(FitPlanConfig c) {
  final e = c.equipment;
  return e.contains(Equip.treadmill)
      ? 'treadmill'
      : e.contains(Equip.indoorBike)
          ? 'indoor_bike'
          : e.contains(Equip.rower)
              ? 'rowing'
              : c.level == FitLevel.beginner
                  ? 'walking'
                  : 'running';
}

/// Moderate-equivalent cardio minutes the week aims for.
double _weeklyTarget(FitPlanConfig c, int week, bool deload) {
  final full = c.goal == FitGoal.fatLoss ? 225.0 : 150.0;
  final start = c.level == FitLevel.beginner ? 0.6 : 0.8;
  final ramp = (start + 0.1 * (week - 1)).clamp(0.0, 1.0);
  return full * ramp * (deload ? 0.7 : 1);
}

int _five(double m) => (m / 5).round() * 5;

/// The whole plan, day by day.
List<PlanDay> buildFitPlan(FitPlanConfig c) {
  final perWeek = c.daysPerWeek.clamp(3, 6);
  final template = _week(c.goal, perWeek);
  final strengthPerWeek = template.where((k) => k == DayKind.strength).length;
  final cardioPerWeek = template.where((k) => k == DayKind.cardio).length;
  final split = strengthPerWeek >= 4
      ? const [Session.upper, Session.lower]
      : const [Session.fullA, Session.fullB];
  final out = <PlanDay>[];
  var sessionN = 0;
  for (var i = 0; i < c.days; i++) {
    final week = i ~/ 7 + 1;
    final deload = week % 4 == 0;
    final date = DateTime(c.start.year, c.start.month, c.start.day + i);
    final kind = template[i % 7];

    // This week's cardio budget: cardio days carry 80 % of it, and an
    // interval minute counts as two; the rest is split over the strength days.
    final target = _weeklyTarget(c, week, deload);
    final steadyMin = cardioPerWeek == 0
        ? 0
        : _five(target * 0.8 / cardioPerWeek).clamp(20, 60);
    final intervalMin = _five(steadyMin * 0.6).clamp(15, 40);
    final weekIntervals = !deload &&
            c.level == FitLevel.intermediate &&
            c.goal != FitGoal.strength
        ? cardioPerWeek ~/ 2
        : 0;
    final covered = (cardioPerWeek - weekIntervals) * steadyMin +
        weekIntervals * intervalMin * 2;
    final finisherMin = strengthPerWeek == 0
        ? 0
        : _five((target - covered) / strengthPerWeek).clamp(0, 20);

    if (kind == null) {
      out.add(PlanDay(index: i, date: date, week: week, kind: DayKind.rest, deload: deload));
      continue;
    }
    if (kind == DayKind.cardio) {
      // Every second cardio day of the week is intervals, when the week has any.
      final nthInWeek = [
        for (var d = 0; d < i % 7; d++)
          if (template[d] == DayKind.cardio) d
      ].length;
      final intervals = weekIntervals > 0 && nthInWeek.isOdd;
      out.add(PlanDay(
          index: i,
          date: date,
          week: week,
          kind: DayKind.cardio,
          cardio: intervals
              ? PlanCardio(
                  c.equipment.contains(Equip.jumpRope) ? 'jump_rope' : _steady(c),
                  intervalMin,
                  intervals: true)
              : PlanCardio(_steady(c), steadyMin),
          deload: deload));
      continue;
    }
    final session = split[sessionN % split.length];
    final alt = (sessionN ~/ split.length).isOdd;
    sessionN++;
    final items = <PlanItem>[];
    final used = <String>{};
    for (final p in _sessions[session]!) {
      // A repeat (the hinge twice in a full-body pair) takes the next lift.
      var picked = _pick(c, p, alt: alt);
      if (picked != null && used.contains(picked.$1)) picked = _pick(c, p, alt: !alt);
      if (picked == null || used.contains(picked.$1)) continue;
      used.add(picked.$1);
      items.add(_dose(c, picked.$1, picked.$2, week, deload));
    }
    out.add(PlanDay(
        index: i,
        date: date,
        week: week,
        kind: DayKind.strength,
        session: session,
        items: items,
        finisher: finisherMin >= 10 ? PlanCardio(_steady(c), finisherMin) : null,
        deload: deload));
  }
  return out;
}

/// The plan day for [today], or null outside the program.
PlanDay? planDayOn(List<PlanDay> plan, DateTime today) {
  for (final d in plan) {
    if (d.date.year == today.year && d.date.month == today.month && d.date.day == today.day) {
      return d;
    }
  }
  return null;
}

/// Weekly moderate-equivalent cardio minutes (an interval minute counts
/// twice, as WHO counts vigorous), finishers included, for [week].
int cardioMinutesInWeek(List<PlanDay> plan, int week) {
  var m = 0;
  for (final d in plan.where((d) => d.week == week)) {
    for (final x in [d.cardio, d.finisher]) {
      if (x != null) m += x.minutes * (x.intervals ? 2 : 1);
    }
  }
  return m;
}
