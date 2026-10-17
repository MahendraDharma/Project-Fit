// Muscle volume — fractional set counting, hard sets, tonnage.
import 'package:test/test.dart';
import 'package:projectfit_analytics/onehz.dart';

StrengthSetInput _set(String key, int reps,
        {double? kg, int? rpe, List<String> p = const [], List<String> s = const []}) =>
    StrengthSetInput(
        exerciseKey: key, reps: reps, loadKg: kg, rpe: rpe,
        primaryMuscles: p, secondaryMuscles: s);

void main() {
  test('no sets is absent, never zero', () {
    final m = muscleVolume(const []);
    expect(m.present, isFalse);
    expect(m.confidence, 0);
  });

  test('a set with zero reps does not count', () {
    expect(muscleVolume([_set('bench', 0, p: ['Chest'])]).present, isFalse);
  });

  test('primary counts 1, secondary 0.5', () {
    final v = muscleVolume([
      for (var i = 0; i < 3; i++)
        _set('bench', 8, kg: 60, p: ['Chest'], s: ['Triceps', 'Shoulders']),
      _set('pushdown', 12, kg: 20, p: ['Triceps']),
    ]).value!;
    expect(v.setsByMuscle['Chest'], 3);
    expect(v.setsByMuscle['Triceps'], 2.5);
    expect(v.setsByMuscle['Shoulders'], 1.5);
    expect(v.totalSets, 4);
    expect(v.tonnageKg, 3 * 8 * 60 + 12 * 20);
  });

  test('a muscle listed as primary and secondary counts once, as primary', () {
    final v = muscleVolume([_set('row', 10, p: ['Lats'], s: ['Lats', 'Biceps'])]).value!;
    expect(v.setsByMuscle, {'Lats': 1.0, 'Biceps': 0.5});
  });

  test('hard sets need an RPE; unrated sets are not counted as easy', () {
    final v = muscleVolume([
      _set('squat', 5, kg: 100, rpe: 8, p: ['Quads']),
      _set('squat', 5, kg: 100, rpe: 6, p: ['Quads']),
      _set('squat', 5, kg: 100, p: ['Quads']),
    ]).value!;
    expect(v.setsByMuscle['Quads'], 3);
    expect(v.hardSetsByMuscle, {'Quads': 1.0});
    expect(v.ratedSets, 2);
  });

  test('no RPE anywhere means hard sets are unknown, not zero', () {
    final v = muscleVolume([_set('squat', 5, kg: 100, p: ['Quads'])]).value!;
    expect(v.hardSetsByMuscle, isNull);
    expect(v.toJson().containsKey('hard_sets_by_muscle'), isFalse);
  });

  test('bodyweight sets count as sets but stay out of tonnage', () {
    final v = muscleVolume([
      _set('pullup', 8, p: ['Lats']),
      _set('pullup', 8, p: ['Lats']),
    ]).value!;
    expect(v.setsByMuscle['Lats'], 2);
    expect(v.tonnageKg, isNull);
    expect(v.unloadedSets, 2);
  });

  test('an exercise with no muscles is counted and reported as unmapped', () {
    final m = muscleVolume([_set('custom', 10, kg: 10)]);
    expect(m.value!.totalSets, 1);
    expect(m.value!.unmappedSets, 1);
    expect(m.value!.setsByMuscle, isEmpty);
    expect(m.note, 'unmapped_sets=1');
  });
}
