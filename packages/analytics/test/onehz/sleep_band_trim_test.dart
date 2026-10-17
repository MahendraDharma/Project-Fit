// test/onehz/sleep_band_trim_test.dart
import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:openstrap_analytics/onehz.dart';

const int _t0 = 1700000000;
final int _midnight = _t0 - (_t0 % 86400);
final int _wake = _midnight + 7 * 3600 + 10 * 60; // band's last SLEEP + 1

/// 22:00 → 11:00 UTC. Asleep (still, HR 55) 23:00 → 07:10; a short walk
/// 07:10-07:15; lie-in (still, HR 57 — near RHR, like the real nights)
/// 07:15 → 08:30; then real activity.
({List<AccelSample> accel, List<double> hr, List<int> band}) _lieInNight() {
  final accel = <AccelSample>[], hr = <double>[], band = <int>[];
  final rnd = math.Random(7);
  for (var t = _midnight - 2 * 3600; t < _midnight + 11 * 3600; t++) {
    final asleep = t >= _midnight - 3600 && t < _wake;
    final walk = t >= _wake && t < _wake + 5 * 60;
    final lieIn = t >= _wake + 5 * 60 && t < _midnight + 8 * 3600 + 30 * 60;
    final moving = !asleep && !lieIn;
    accel.add(AccelSample(t * 1000.0,
        moving ? 0.4 * math.cos(t / 2) : 0.01 * rnd.nextDouble(), 0.0,
        moving ? 1.0 + 0.3 * math.sin(t / 3) : 1.0));
    hr.add(asleep ? 55 : (lieIn ? 57 : (walk ? 80 : 85)));
    band.add(asleep ? 2 : (lieIn || walk ? 3 : 0));
  }
  return (accel: accel, hr: hr, band: band);
}

void main() {
  test('fixture reproduces the bug: without band the night runs past 07:20', () {
    final n = _lieInNight();
    final base = segmentSleep(n.accel, n.hr, tzOffsetSec: 0);
    expect(base.present, isTrue);
    expect(base.window!.offsetMs! ~/ 1000, greaterThan(_wake + 10 * 60));
    expect(base.bandOffsetTrimSec, isNull);
  });

  test('band last SLEEP 07:10, awake after: night ends at 07:10', () {
    final n = _lieInNight();
    final base = segmentSleep(n.accel, n.hr, tzOffsetSec: 0);
    final s = segmentSleep(n.accel, n.hr, tzOffsetSec: 0, bandSleepState: n.band);
    expect(s.present, isTrue);
    expect(s.window!.offsetMs, _wake * 1000.0);
    expect(s.bandOffsetTrimSec, (base.window!.offsetMs! ~/ 1000) - _wake);
    expect(s.window!.offsetMs! ~/ 1000 + s.bandOffsetTrimSec!,
        base.window!.offsetMs! ~/ 1000); // untrimmed end recoverable
    expect(s.inBedSec, lessThan(base.inBedSec!));
    expect(s.tstSec, lessThan(base.tstSec!));
    expect(s.toJson()['band_offset_trim_sec'], s.bandOffsetTrimSec);
  });

  test('all-absent band (-1) is byte-identical to no input', () {
    final n = _lieInNight();
    expect(
        segmentSleep(n.accel, n.hr,
                tzOffsetSec: 0,
                bandSleepState: List<int>.filled(n.band.length, -1))
            .toJson(),
        segmentSleep(n.accel, n.hr, tzOffsetSec: 0).toJson());
  });

  test('forced window ignores the band entirely', () {
    final n = _lieInNight();
    final w = (onsetSec: _midnight - 3600, offsetSec: _midnight + 8 * 3600 + 30 * 60);
    expect(
        segmentSleep(n.accel, n.hr, tzOffsetSec: 0, forcedWindow: w, bandSleepState: n.band)
            .toJson(),
        segmentSleep(n.accel, n.hr, tzOffsetSec: 0, forcedWindow: w).toJson());
  });

  test('band shorter than accel: ignored (positional contract broken)', () {
    final n = _lieInNight();
    expect(
        segmentSleep(n.accel, n.hr, tzOffsetSec: 0, bandSleepState: n.band.sublist(0, 100))
            .toJson(),
        segmentSleep(n.accel, n.hr, tzOffsetSec: 0).toJson());
  });
}
