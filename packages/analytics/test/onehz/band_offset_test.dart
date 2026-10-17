import 'package:test/test.dart';
import 'package:openstrap_analytics/onehz.dart';

const int _t0 = 1700000000;

/// Positional ts/band arrays from (state, seconds) runs. state -1 = row present
/// but band state absent; state null = no row at all (a hole in tsSec).
({List<int> ts, List<int> band, int end}) _night(List<(int?, int)> runs) {
  final ts = <int>[], band = <int>[];
  var t = _t0;
  for (final (s, n) in runs) {
    for (var i = 0; i < n; i++, t++) {
      if (s == null) continue;
      ts.add(t);
      band.add(s);
    }
  }
  return (ts: ts, band: band, end: t);
}

int? _trim(({List<int> ts, List<int> band, int end}) n) => bandTrimmedOffsetSec(
    startSec: _t0, endSec: n.end, tsSec: n.ts, bandState: n.band);

void main() {
  test('lie-in after waking: end moves to last SLEEP second + 1', () {
    final n = _night([(2, 8 * 3600), (3, 70 * 60)]); // lie-in after waking
    expect(_trim(n), _t0 + 8 * 3600);
  });

  test('UP then WAKE tail also trims', () {
    final n = _night([(2, 8 * 3600), (3, 30 * 60), (0, 20 * 60)]);
    expect(_trim(n), _t0 + 8 * 3600);
  });

  test('mid-night UP then SLEEP again: only the trailing UP is trimmed', () {
    final n = _night([(2, 4 * 3600), (3, 19 * 60), (2, 3 * 3600), (3, 48 * 60)]);
    expect(_trim(n), _t0 + 4 * 3600 + 19 * 60 + 3 * 3600);
  });

  test('mid-night UP then SLEEP to the end: no trim', () {
    expect(_trim(_night([(2, 4 * 3600), (3, 28 * 60), (2, 3 * 3600)])), isNull);
  });

  test('tail shorter than 10 min: no trim', () {
    expect(_trim(_night([(2, 7 * 3600), (3, 9 * 60)])), isNull);
  });

  test('band never SLEEP in the window: no trim (no veto in this plan)', () {
    expect(_trim(_night([(0, 2 * 3600), (1, 3600), (3, 5 * 3600)])), isNull);
  });

  // Each gap case below has EXACTLY 95 % tail coverage (114 of 120 min), so it
  // passes the coverage gate and fails only on the 6-min (> 5 min) hole.
  test('trailing gap > 5 min: no trim (could hide a return to SLEEP)', () {
    expect(_trim(_night([(2, 7 * 3600), (3, 114 * 60), (null, 6 * 60)])), isNull);
  });

  test('leading gap > 5 min right after last SLEEP: no trim', () {
    expect(_trim(_night([(2, 7 * 3600), (null, 6 * 60), (3, 114 * 60)])), isNull);
  });

  test('internal gap > 5 min: no trim', () {
    expect(_trim(_night([(2, 7 * 3600), (3, 60 * 60), (-1, 6 * 60), (3, 54 * 60)])),
        isNull);
  });

  test('control: same 2 h tail without the hole trims', () {
    expect(_trim(_night([(2, 7 * 3600), (3, 120 * 60)])), _t0 + 7 * 3600);
  });

  test('short gaps (<= 5 min) at >= 95 % tail coverage still trim', () {
    final n = _night([(2, 7 * 3600), (3, 30 * 60), (null, 2 * 60), (3, 38 * 60)]);
    expect(_trim(n), _t0 + 7 * 3600);
  });

  test('STILL in the tail (re-settling) > 60 s: no trim', () {
    expect(_trim(_night([(2, 7 * 3600), (3, 30 * 60), (1, 10 * 60), (0, 5 * 60)])),
        isNull);
  });

  test('whole-window coverage below 80 %: no trim', () {
    expect(_trim(_night([(-1, 6 * 3600), (2, 2 * 3600), (3, 60 * 60)])), isNull);
  });

  test('trim would drop below 3 h: no trim', () {
    expect(_trim(_night([(2, 2 * 3600 + 50 * 60), (3, 60 * 60)])), isNull);
  });

  test('all absent (-1, gen4): no trim', () {
    expect(_trim(_night([(-1, 9 * 3600)])), isNull);
  });

  test('length mismatch or empty window: no trim', () {
    expect(bandTrimmedOffsetSec(
        startSec: _t0, endSec: _t0 + 10, tsSec: const [1, 2], bandState: const [2]),
        isNull);
    expect(bandTrimmedOffsetSec(
        startSec: _t0, endSec: _t0, tsSec: const [], bandState: const []),
        isNull);
  });

  // Duplicate seconds (callers derive tsSec with tsMs ~/ 1000) must count once.
  ({List<int> ts, List<int> band, int end}) _dupTail(
      int tailSec, bool Function(int i) present) {
    final ts = <int>[], band = <int>[];
    for (var i = 0; i < 7 * 3600; i++) {
      ts.add(_t0 + i);
      band.add(2);
    }
    for (var i = 0; i < tailSec; i++) {
      if (!present(i)) continue;
      for (var r = 0; r < 2; r++) {
        ts.add(_t0 + 7 * 3600 + i);
        band.add(3);
      }
    }
    return (ts: ts, band: band, end: _t0 + 7 * 3600 + tailSec);
  }

  test('duplicate rows cannot fake tail coverage', () {
    final n = _dupTail(120 * 60, (i) => i.isEven); // 50 % distinct coverage
    expect(_trim(n), isNull);
  });

  test('duplicate rows in an otherwise complete tail still trim', () {
    final n = _dupTail(60 * 60, (_) => true);
    expect(_trim(n), _t0 + 7 * 3600);
  });

  test('stager and rule share one "sleep" code', () {
    expect(AdvancedSleepStager.bandStateAsleep, kBandStateSleep);
  });
}
