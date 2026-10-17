// Period change — month vs month with Hopkins' smallest worthwhile change.
import 'package:test/test.dart';
import 'package:projectfit_analytics/onehz.dart';

List<double?> _days(List<double> pattern, int n) =>
    [for (var i = 0; i < n; i++) pattern[i % pattern.length]];

void main() {
  test('too few measured days in either period is absent', () {
    final m = periodChange(_days([60], 30), [...List.filled(25, null), ..._days([65], 9)]);
    expect(m.present, isFalse);
    expect(m.note, needBaselineNote(have: 9, need: periodChangeMinDays));
  });

  test('a missing day is missing, not zero', () {
    final cur = <double?>[for (var i = 0; i < 30; i++) i.isEven ? 60 : null];
    final v = periodChange(_days([58, 62], 30), cur).value!;
    expect(v.currentDays, 15);
    expect(v.currentMean, 60);
  });

  test('a shift larger than 0.2 SD is called, with its direction', () {
    // Previous: 55..65 alternating (SD ≈ 5.1, SWC ≈ 1.0). Current: +3.
    final v = periodChange(_days([55, 65], 30), _days([58, 68], 30)).value!;
    expect(v.delta, closeTo(3, 1e-9));
    expect(v.swc, closeTo(0.2 * 5.085, 0.01));
    expect(v.direction, 'up');
    expect(periodChange(_days([58, 68], 30), _days([55, 65], 30)).value!.direction,
        'down');
  });

  test('a shift inside the noise is steady', () {
    final v = periodChange(_days([50, 70], 30), _days([50.5, 70.5], 30)).value!;
    expect(v.direction, 'steady');
  });
}
