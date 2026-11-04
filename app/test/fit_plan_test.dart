// The fit program: a day-by-day plan from the person's choices. Same choices,
// same plan; what is not there (a bar, a barbell) is never prescribed; the
// week meets the cardio guideline; and it grows, with a lighter fourth week.
import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/ui2/activity/catalogue.dart';
import 'package:projectfit/ui2/program/fit_plan.dart';

FitPlanConfig _cfg({
  int days = 30,
  FitGoal goal = FitGoal.general,
  FitStyle style = FitStyle.calisthenics,
  FitLevel level = FitLevel.beginner,
  int perWeek = 4,
  Set<Equip> equipment = const {},
}) =>
    FitPlanConfig(
        days: days,
        goal: goal,
        style: style,
        level: level,
        daysPerWeek: perWeek,
        equipment: equipment,
        start: DateTime(2026, 11, 9));

void main() {
  test('every exercise the plan can name is in the catalogue', () {
    expect(unresolvedPlanExercises(), isEmpty);
  });

  test('every cardio activity it names is a real activity', () {
    for (final eq in [<Equip>{}, gymEquipment, {Equip.jumpRope}]) {
      for (final level in FitLevel.values) {
        final plan = buildFitPlan(_cfg(
            days: 28, level: level, goal: FitGoal.fatLoss, perWeek: 6, equipment: eq));
        for (final d in plan) {
          for (final c in [d.cardio, d.finisher]) {
            if (c == null) continue;
            expect(activityByName(c.activityKey), isNotNull, reason: c.activityKey);
          }
        }
      }
    }
  });

  test('one day for each day of the program, training days as chosen', () {
    final plan = buildFitPlan(_cfg(days: 30, perWeek: 4));
    expect(plan, hasLength(30));
    expect(plan.first.date, DateTime(2026, 11, 9));
    expect(plan.last.date, DateTime(2026, 12, 8));
    final week1 = plan.take(7);
    expect(week1.where((d) => d.kind != DayKind.rest), hasLength(4));
    expect(week1.where((d) => d.kind == DayKind.strength), hasLength(2));
  });

  test('a calisthenics plan with no equipment never asks for any', () {
    final plan = buildFitPlan(_cfg(days: 56, perWeek: 5, level: FitLevel.intermediate));
    final keys = {for (final d in plan) for (final i in d.items) i.exerciseKey};
    expect(keys, isNotEmpty);
    for (final k in keys) {
      final e = exerciseByKey(k)!;
      expect(e.equipment.where((q) => q != 'none (bodyweight exercise)' && q != 'Gym mat'),
          isEmpty, reason: '$k needs ${e.equipment}');
    }
    expect(keys, isNot(contains('pull_up')));
  });

  test('a pull-up bar brings pulling; a beginner gets chin-ups, not pull-ups', () {
    final plan = buildFitPlan(_cfg(equipment: {Equip.pullUpBar}));
    final keys = {for (final d in plan) for (final i in d.items) i.exerciseKey};
    expect(keys, contains('chin_up'));
    expect(keys, isNot(contains('pull_up')));
    final mid = buildFitPlan(_cfg(equipment: {Equip.pullUpBar}, level: FitLevel.intermediate));
    expect({for (final d in mid) for (final i in d.items) i.exerciseKey}, contains('pull_up'));
  });

  test('a gym plan lifts; four strength days split upper and lower', () {
    final plan = buildFitPlan(_cfg(
        style: FitStyle.gym,
        equipment: gymEquipment,
        goal: FitGoal.strength,
        perWeek: 5,
        level: FitLevel.intermediate));
    final keys = {for (final d in plan) for (final i in d.items) i.exerciseKey};
    expect(keys, containsAll(['back_squat', 'bench_press']));
    expect({for (final d in plan) d.session}, containsAll([Session.upper, Session.lower]));
    final squat = plan.expand((d) => d.items).firstWhere((i) => i.exerciseKey == 'back_squat');
    expect(squat.reps, 6, reason: 'strength: fewer reps');
    expect(squat.sets, 4);
  });

  test('no exercise twice in one session', () {
    for (final style in FitStyle.values) {
      final plan = buildFitPlan(_cfg(
          style: style, equipment: defaultEquipment(style), days: 28, perWeek: 3));
      for (final d in plan.where((d) => d.kind == DayKind.strength)) {
        final ks = [for (final i in d.items) i.exerciseKey];
        expect(ks.toSet(), hasLength(ks.length), reason: '${d.index}: $ks');
        expect(ks.length, greaterThanOrEqualTo(4));
      }
    }
  });

  test('the cardio meets the guideline once ramped up; fat loss asks for more', () {
    final general = buildFitPlan(_cfg(days: 56, level: FitLevel.intermediate));
    // Week 3: ramped (80 % + 20 %), not a deload.
    expect(cardioMinutesInWeek(general, 3), inInclusiveRange(140, 200));
    final fat = buildFitPlan(_cfg(
        days: 56, goal: FitGoal.fatLoss, level: FitLevel.intermediate, perWeek: 5));
    expect(cardioMinutesInWeek(fat, 3), greaterThan(cardioMinutesInWeek(general, 3)));
    expect(fat.any((d) => d.cardio?.intervals ?? false), isTrue);
    // A beginner starts gentler and builds.
    final easy = buildFitPlan(_cfg(days: 56));
    expect(cardioMinutesInWeek(easy, 1), lessThan(cardioMinutesInWeek(easy, 3)));
    expect(easy.any((d) => d.cardio?.intervals ?? false), isFalse);
  });

  test('it grows across a block and the fourth week is lighter', () {
    final plan = buildFitPlan(_cfg(days: 35, perWeek: 3));
    int reps(int week) => plan
        .where((d) => d.week == week)
        .expand((d) => d.items)
        .firstWhere((i) => i.exerciseKey == 'push_up' || i.exerciseKey == 'incline_push_up')
        .reps!;
    int sets(int week) => plan.where((d) => d.week == week).expand((d) => d.items).first.sets;
    expect(reps(2), greaterThan(reps(1)));
    expect(sets(3), greaterThan(sets(2)));
    expect(plan.where((d) => d.week == 4).every((d) => d.deload), isTrue);
    expect(sets(4), lessThan(sets(3)));
    expect(reps(5), greaterThan(reps(1)), reason: 'the next block starts harder');
  });

  test('choices round-trip, and a broken record reads as none', () {
    final c = _cfg(style: FitStyle.gym, equipment: {Equip.dumbbells, Equip.bench});
    final back = FitPlanConfig.decode(c.encode())!;
    expect(back.toJson(), c.toJson());
    expect(FitPlanConfig.decode('{"days": "x"}'), isNull);
    expect(FitPlanConfig.decode(''), isNull);
  });

  test('today finds its day; outside the program there is none', () {
    final plan = buildFitPlan(_cfg(days: 14));
    expect(planDayOn(plan, DateTime(2026, 11, 10, 18))?.index, 1);
    expect(planDayOn(plan, DateTime(2026, 12, 1)), isNull);
  });
}
