// Garmin-style surfaces from a WHOOP band: all-day stress, Body Battery,
// sleep score, and VO2max-from-routine with fitness age.
import 'package:test/test.dart';
import 'package:projectfit_analytics/onehz.dart';

List<double?> _nights(double v, [int n = 14]) =>
    [for (var i = 0; i < n; i++) v];

void main() {
  group('allDayStress', () {
    test('the stated mapping: night level 0, half 50, a quarter 100', () {
      expect(stressScoreOf(60, 60), 0);
      expect(stressScoreOf(30, 60), closeTo(50, 1e-9));
      expect(stressScoreOf(15, 60), closeTo(100, 1e-9));
      expect(stressScoreOf(90, 60),
          0); // calmer than a night is rest, not negative
      expect(stressScoreOf(5, 60), 100);
    });

    test('Garmin bands', () {
      expect([10.0, 25.0, 26.0, 50.0, 51.0, 76.0].map(stressBand),
          ['rest', 'rest', 'low', 'low', 'medium', 'high']);
    });

    test('scores still windows, sums band minutes, drops thin windows', () {
      final w = [
        for (var i = 0; i < 6; i++) QuietHrvWindow(i * 300, 30, 60),
        const QuietHrvWindow(9000, 60, 60),
        const QuietHrvWindow(9300, 10, 5), // too few pairs: not a reading
      ];
      final s = allDayStress(w, _nights(60)).value!;
      expect(s.timeline, hasLength(7));
      expect(s.bandMinutes, {'rest': 5, 'low': 30, 'medium': 0, 'high': 0});
      expect(s.average, closeTo(300 / 7, 1e-9));
      expect(s.restRmssdMs, 60);
    });

    test('abstains without enough nights or windows', () {
      final w = [for (var i = 0; i < 6; i++) QuietHrvWindow(i * 300, 30, 60)];
      final a = allDayStress(w, _nights(60, 6));
      expect(a.present, isFalse);
      expect(a.note, 'need_baseline:have=6,need=7');
      final b = allDayStress(w.take(5).toList(), _nights(60));
      expect(b.present, isFalse);
      expect(b.note, startsWith('need_input:name=still_windows'));
    });
  });

  group('bodyBattery', () {
    List<BatterySlot> span(int from, int n, BatteryState st,
            {double? stress, double? hrr}) =>
        [
          for (var i = 0; i < n; i++)
            BatterySlot(from + i * 300, st, stress: stress, hrr: hrr)
        ];

    test('a 7.5 h night at stress 25 charges about 68 from the start level',
        () {
      final slots = [
        ...span(0, 90, BatteryState.asleep, stress: 25),
        ...span(27000, 12, BatteryState.awake),
      ];
      final b = bodyBattery(slots, showFromSec: 27000).value!;
      // 50 + 67.5 clamps at 100, then 12 awake slots drain 1.8.
      expect(b.current, closeTo(100 - 12 * bbAwakeDrain, 1e-9));
    });

    test('activity drains with effort, stress drains, rest charges', () {
      expect(batteryDelta(const BatterySlot(0, BatteryState.active, hrr: 0.3)),
          closeTo(-bbAwakeDrain, 1e-12));
      expect(batteryDelta(const BatterySlot(0, BatteryState.active, hrr: 1)),
          closeTo(-(bbAwakeDrain + bbActiveDrain), 1e-12));
      expect(
          batteryDelta(const BatterySlot(0, BatteryState.still, stress: 100)),
          closeTo(-bbStressDrain, 1e-12));
      expect(batteryDelta(const BatterySlot(0, BatteryState.still, stress: 0)),
          closeTo(bbRestCharge, 1e-12));
      expect(batteryDelta(const BatterySlot(0, BatteryState.notWorn)), 0);
    });

    test('stays inside 5–100 and leaves unworn slots out of the line', () {
      final slots = [
        ...span(0, 10, BatteryState.asleep, stress: 0),
        ...span(3000, 200, BatteryState.active, hrr: 1),
        ...span(63000, 5, BatteryState.notWorn),
      ];
      final b = bodyBattery(slots, showFromSec: 3000).value!;
      expect(b.lowest, bodyBatteryMin);
      expect(b.timeline, hasLength(200));
    });

    test('abstains when no night has set the level yet', () {
      final b = bodyBattery(span(0, 50, BatteryState.awake), showFromSec: 0);
      expect(b.present, isFalse);
      expect(b.note, 'need_input:name=sleep_night');
    });
  });

  group('sleepScore', () {
    test('a full night inside every target scores 100', () {
      final s = sleepScore(
        asleepMin: 480,
        needMin: 480,
        deepMin: 100, // 20.8 %
        remMin: 110, // 22.9 %
        awakeMin: 10,
        restlessMin: 8, // 1 per hour
        sleepStress: 20,
      ).value!;
      expect(s.score, closeTo(100, 1e-9));
      expect(s.needFromGuideline, isFalse);
    });

    test('missing parts are dropped and the weights rescaled', () {
      final s = sleepScore(asleepMin: 360, needMin: 480).value!;
      expect(s.components.keys, ['duration']);
      expect(s.score, closeTo(75, 1e-9));
    });

    test('no learned need falls back to the 7 h guideline and says so', () {
      final s = sleepScore(asleepMin: 420).value!;
      expect(s.components['duration'], 100);
      expect(s.needFromGuideline, isTrue);
    });

    test('awake and restless time cost points on stated ramps', () {
      final s = sleepScore(
              asleepMin: 480, needMin: 480, awakeMin: 55, restlessMin: 56)
          .value!;
      expect(s.components['awake'], closeTo(50, 1e-9)); // 55 is halfway 20→90
      expect(s.components['restlessness'], closeTo(50, 1e-9)); // 7/h
    });

    test('abstains without a night', () {
      expect(sleepScore(asleepMin: null).present, isFalse);
    });
  });

  group('routineFitness (HUNT non-exercise)', () {
    test('PA index from four weeks of sessions', () {
      final pa = paIndexFromSessions([
        for (var i = 0; i < 12; i++) const RoutineSession(45, meanHrr: 0.6)
      ]);
      expect(pa.sessionsPerWeek, 3);
      expect(pa.value, 2.5 * 0.75 * 2);
      expect(paIndexFromSessions(const []).value, 0);
    });

    test('the published men\'s waist equation', () {
      final v = vo2maxHuntWaist(
          sex: 'male', age: 40, waistCm: 90, restingHr: 60, paIndex: 3.75);
      expect(
          v,
          closeTo(100.27 - 0.296 * 40 - 0.369 * 90 - 0.155 * 60 + 0.226 * 3.75,
              1e-9));
    });

    test('fitness age inverts the HUNT3 table', () {
      expect(fitnessAgeFor('male', 47), closeTo(45, 1e-9));
      expect(fitnessAgeFor('female', 36), closeTo(50, 1e-9));
      expect(fitnessAgeFor('male', 70), 20); // fitter than any decade: floor
      expect(huntAverageVo2max('male', 50), closeTo(44.5, 1e-9));
    });

    test('needs age, a waist or BMI, and a week of resting HR', () {
      final ok = routineFitness(
        age: 40,
        sex: 'male',
        waistCm: 90,
        nightlyRhr: _nights(55),
        sessions: const [],
      ).value!;
      expect(ok.fromWaist, isTrue);
      expect(ok.restingHr, 55);
      expect(ok.fitnessAge, inInclusiveRange(20, 90));
      expect(
          routineFitness(
              age: 40,
              sex: 'male',
              waistCm: null,
              nightlyRhr: _nights(55),
              sessions: const []).note,
          'need_input:name=waist_cm');
      expect(
          routineFitness(
              age: 40,
              sex: 'male',
              waistCm: 90,
              nightlyRhr: _nights(55, 3),
              sessions: const []).note,
          'need_baseline:have=3,need=7');
    });
  });
}
