// Health Snapshot: a spot-check turns into an entry only when it is a reading.
import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/ui2/screens/health_snapshot.dart';

void main() {
  const good = {
    'ok': true,
    'rmssd': 30,
    'sdnn': 44,
    'mean_hr': 66,
    'resp_brpm': 14.5,
    'n_beats': 130,
    'clean_fraction': 0.95,
  };

  test('a clean two minutes becomes an entry, stress against the nights', () {
    final s = snapshotOf(good, 60, 1000)!;
    expect(s['rmssd'], 30);
    expect(s['stress'], 50); // half the night level on the Stress card's scale
    expect(s['resp'], 14.5);
    expect(s['t'], 1000);
  });

  test('no nights: no stress, the rest still stands', () {
    final s = snapshotOf(good, null, 1000)!;
    expect(s['stress'], isNull);
    expect(s['hr'], 66);
  });

  test('too few or too dirty beats is not a reading', () {
    expect(snapshotOf({...good, 'n_beats': 40}, 60, 0), isNull);
    expect(snapshotOf({...good, 'clean_fraction': 0.6}, 60, 0), isNull);
    expect(snapshotOf(const {'ok': false}, 60, 0), isNull);
  });
}
