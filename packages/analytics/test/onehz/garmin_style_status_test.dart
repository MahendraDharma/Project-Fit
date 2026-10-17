// HRV status (7 nights vs 60-day baseline) and the acute:chronic load ratio.
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:projectfit_analytics/onehz.dart';

/// 60 baseline nights wobbling ±10% around [base] ms, then 7 nights at [week].
List<double?> _nights(double base, double week) => [
      for (var i = 0; i < 60; i++) base * (i.isEven ? 1.1 : 0.9),
      for (var i = 0; i < 7; i++) week,
    ];

void main() {
  group('hrvStatus', () {
    test('a week at baseline is balanced, with the range around it', () {
      final v = hrvStatus(_nights(50, 50)).value!;
      expect(v.status, 'balanced');
      expect(v.rangeLowMs, lessThan(50));
      expect(v.rangeHighMs, greaterThan(50));
      expect(v.weekNights, 7);
      expect(v.baselineNights, 60);
    });

    test('a clearly lower or higher week leaves the range', () {
      expect(hrvStatus(_nights(50, 40)).value!.status, 'below');
      expect(hrvStatus(_nights(50, 62)).value!.status, 'above');
    });

    test('the week is not part of its own baseline', () {
      final v = hrvStatus(_nights(50, 30)).value!;
      // Baseline geometric mean of 55 and 45 ≈ 49.7, untouched by the 30s.
      expect(v.baselineMeanMs, closeTo(math.sqrt(55 * 45), 0.01));
    });

    test('too few nights in the week or the baseline is absent', () {
      final thinWeek = <double?>[..._nights(50, 50).sublist(0, 60), 50, null, null, null, null, 50, 50];
      expect(hrvStatus(thinWeek).note,
          needBaselineNote(have: 3, need: hrvStatusMinWeekNights));
      final thinBase = <double?>[...List<double?>.filled(55, null), 50, 50, ...List.filled(7, 50.0)];
      expect(hrvStatus(thinBase).note,
          needBaselineNote(have: 2, need: hrvStatusMinBaselineNights));
    });

    test('a missing night is skipped, never read as zero', () {
      final xs = _nights(50, 50)..[63] = null;
      final v = hrvStatus(xs).value!;
      expect(v.weekNights, 6);
      expect(v.weekMeanMs, closeTo(50, 1e-9));
    });
  });

  group('loadRatio', () {
    test("Gabbett's zones", () {
      expect(loadRatioZone(0.7), 'low');
      expect(loadRatioZone(0.8), 'optimal');
      expect(loadRatioZone(1.3), 'optimal');
      expect(loadRatioZone(1.4), 'high');
      expect(loadRatioZone(1.6), 'very_high');
    });

    test('ratio is acute over chronic', () {
      final v = loadRatio(atl: 60, ctl: 50).value!;
      expect(v.ratio, closeTo(1.2, 1e-9));
      expect(v.zone, 'optimal');
    });

    test('no chronic load, no ratio', () {
      expect(loadRatio(atl: 10, ctl: 0).present, isFalse);
      expect(loadRatio(atl: null, ctl: 40).present, isFalse);
    });
  });
}
