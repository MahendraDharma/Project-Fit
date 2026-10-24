import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/ui2/screens/screens.dart';
import 'package:projectfit/ui2/ui2.dart';

void main() {
  final t0 = DateTime(2026, 10, 20, 18);
  DateTime after(int h) => t0.add(Duration(hours: h));

  test('six sets: 40 % recovered right after, 85 at 48 h, 92.5 at 72 h', () {
    final d = [(muscle: 'Quads', at: t0, sets: 6.0, toFailure: false)];
    expect(muscleRecovery(d, t0)['Quads'], closeTo(40, 1e-9));
    expect(muscleRecovery(d, after(48))['Quads'], closeTo(85, 1e-9));
    expect(muscleRecovery(d, after(72))['Quads'], closeTo(92.5, 1e-9));
  });

  test('to failure recovers slower', () {
    final easy = muscleRecovery([(muscle: 'Chest', at: t0, sets: 8.0, toFailure: false)], after(48))['Chest']!;
    final hard = muscleRecovery([(muscle: 'Chest', at: t0, sets: 8.0, toFailure: true)], after(48))['Chest']!;
    expect(hard, lessThan(easy));
  });

  test('sessions add up, and depletion is capped at all of it', () {
    final d = [
      (muscle: 'Lats', at: t0, sets: 10.0, toFailure: false),
      (muscle: 'Lats', at: t0, sets: 10.0, toFailure: false),
    ];
    expect(muscleRecovery(d, t0)['Lats'], 0);
  });

  test('a muscle with nothing logged has no estimate', () {
    expect(muscleRecovery(const [], t0), isEmpty);
  });

  test('state bands', () {
    expect([95.0, 80.0, 79.0, 50.0, 49.0].map(muscleState),
        [MuscleState.recovered, MuscleState.recovered, MuscleState.fatigued, MuscleState.fatigued, MuscleState.depleted]);
  });

  test('every catalogue muscle maps to regions the body map has', () {
    final keys = {for (final (k, _) in [...kBodyFront, ...kBodyBack]) k};
    for (final rs in kMuscleRegions.values) {
      for (final r in rs) {
        expect(keys, contains(r));
      }
    }
  });
}
