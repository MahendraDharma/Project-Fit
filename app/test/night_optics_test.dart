import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/ble/ble_state.dart';
import 'package:projectfit/ble/night_optics.dart';
import 'package:projectfit/state/night_optics_recorder.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A gen4 live R10 optics frame (0x2B/0x0b) laid out like the band's.
Uint8List opticsFrame(int bandSec, List<int> a, List<int> b, List<int> c, List<int> d) {
  final n = a.length;
  final f = Uint8List(1924);
  final v = ByteData.sublistView(f);
  f[0] = 0x2B;
  f[1] = 0x0B;
  v.setUint32(7, bandSec, Endian.little);
  f[14] = n;
  f[1289] = n;
  for (var i = 0; i < n; i++) {
    v.setUint32(38 + 4 * i, a[i], Endian.little);
    v.setUint32(38 + 4 * (n + i), b[i], Endian.little);
    v.setUint32(1313 + 4 * i, c[i], Endian.little);
    v.setUint32(1313 + 4 * (n + i), d[i], Endian.little);
  }
  return f;
}

/// 50 samples of a 1.3 Hz pulse from sample [start] at 51 Hz.
List<int> pulse(int start, double dc, double amp, {double noise = 0, math.Random? rng}) => [
      for (var i = start; i < start + 50; i++)
        (dc + amp * math.sin(2 * math.pi * 1.3 * i / 51) + noise * ((rng?.nextDouble() ?? 0.5) - 0.5)).round()
    ];

String hexOf(Uint8List b) => [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();

void main() {
  test('parses the four optical channels of a 0x2B/0x0b frame', () {
    final f = opticsFrame(1793197476, List.filled(50, 1), List.filled(50, 2),
        List.filled(50, 3), List.filled(50, 4));
    final b = parseOpticsFrame(f)!;
    expect(b.bandMs, 1793197476000);
    expect([b.a.first, b.b.first, b.c.last, b.d.last], [1, 2, 3, 4]);
    expect(b.a.length, 50);
    // The motion subtype and short frames are not optics.
    expect(parseOpticsFrame(Uint8List.fromList([0x2B, 0x0A, ...f.sublist(2)])), isNull);
    expect(parseOpticsFrame(f.sublist(0, 1000)), isNull);
  });

  OpticWindow? run(OpticWindowAnalyzer an, {double dNoise = 0}) {
    final rng = math.Random(1);
    OpticWindow? w;
    for (var k = 0; k < 31 && w == null; k++) {
      final s = k * 50;
      w = an.add(
          parseOpticsFrame(opticsFrame(1000 + k, pulse(s, 220000, 2000), pulse(s, 200000, 1800),
              pulse(s, 160000, 300), pulse(s, 15000, 150, noise: dNoise, rng: rng)))!,
          k * 1000);
    }
    return w;
  }

  test('a still, clean pulse scores R = (AC/DC)_C / (AC/DC)_D', () {
    final w = run(OpticWindowAnalyzer())!;
    expect(w.r, closeTo((300 / 160000) / (150 / 15000), 0.01));
    expect(w.corrCD, greaterThan(0.99));
    expect(w.ok, isTrue);
  });

  test('D drowned in noise fails the quality gate', () {
    final w = run(OpticWindowAnalyzer(), dNoise: 4000)!;
    expect(w.ok, isFalse);
  });

  test('a gap in the band clock starts the window again', () {
    final an = OpticWindowAnalyzer();
    for (var k = 0; k < 20; k++) {
      expect(an.add(parseOpticsFrame(opticsFrame(1000 + k, pulse(0, 1, 0), pulse(0, 1, 0), pulse(0, 9, 1), pulse(0, 9, 1)))!, 0), isNull);
    }
    // 10 s later: the 20 frames before are dropped, so a window needs 31
    // fresh frames (1530 samples) instead of 11.
    OpticsBlock frame(int k) => parseOpticsFrame(opticsFrame(1030 + k, pulse(50 * k, 1, 0),
        pulse(50 * k, 1, 0), pulse(50 * k, 9000, 10), pulse(50 * k, 9000, 10)))!;
    for (var k = 0; k < 30; k++) {
      expect(an.add(frame(k), 0), isNull, reason: 'frame $k');
    }
    expect(an.add(frame(30), 0), isNotNull);
  });

  OpticWindow win(int t, double r, {bool ok = true}) =>
      OpticWindow(atMs: t, r: r, corrCD: ok ? 0.95 : 0.2, corrCA: 0.8, piC: 0, piD: 0);

  test('pairs each Garmin reading with the median good R around it', () {
    final pairs = pairWithReference([
      win(0, 0.17),
      win(60000, 0.19),
      win(120000, 0.50, ok: false),
      win(3600000, 0.2),
    ], [
      (atMs: 60000, spo2: 96),
      (atMs: 3600000, spo2: 95), // one window only: left out
    ]);
    expect(pairs, hasLength(1));
    expect(pairs.single.r, closeTo(0.18, 1e-9));
    expect(pairs.single.spo2, 96);
  });

  test('calibration needs enough varied, falling, fitting pairs', () {
    final rng = math.Random(3);
    final good = [
      for (var i = 0; i < 30; i++)
        (() {
          final r = 0.15 + 0.06 * i / 30;
          return (atMs: i, r: r, spo2: 110 - 80 * r + (rng.nextDouble() - 0.5));
        })()
    ];
    final fit = fitCalibration(good);
    expect(fit, isA<CalibrationReady>());
    final k = (fit as CalibrationReady).cal;
    expect(k.b, closeTo(-80, 8));
    expect(k.spo2(0.18), closeTo(95.6, 0.5));

    expect((fitCalibration(good.sublist(0, 5)) as CalibrationPending).reason, 'pairs');
    expect(
        (fitCalibration([for (final p in good) (atMs: p.atMs, r: p.r, spo2: 96.0)]) as CalibrationPending).reason,
        'spread');
    expect(
        (fitCalibration([for (final p in good) (atMs: p.atMs, r: p.r, spo2: 80 + 80 * p.r)]) as CalibrationPending)
            .reason,
        'fit');
  });

  test('the night owner asks for the high-rate stream', () {
    expect(
        desiredLiveStreams(const LiveStreamOwners(nightOptics: true),
                gen5: false, standardHrFallback: false)
            .imu,
        isTrue);
    expect(
        desiredLiveStreams(const LiveStreamOwners(), gen5: false, standardHrFallback: false).imu,
        isFalse);
  });

  test('the night window and its label', () {
    expect(inNightWindow(DateTime(2026, 10, 28, 21)), isTrue);
    expect(inNightWindow(DateTime(2026, 10, 29, 8, 59)), isTrue);
    expect(inNightWindow(DateTime(2026, 10, 29, 9)), isFalse);
    expect(inNightWindow(DateTime(2026, 10, 29, 20, 59)), isFalse);
    expect(nightLabel(DateTime(2026, 10, 29, 2)), '2026-10-28');
    expect(nightLabel(DateTime(2026, 10, 28, 22)), '2026-10-28');
  });

  group('recorder', () {
    late Directory dir;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      dir = Directory.systemTemp.createTempSync('night_optics_test');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('holds the stream only at night, on gen4, connected, with battery', () async {
      var now = DateTime(2026, 10, 28, 20);
      var gen4 = true, connected = true;
      double? battery = 80;
      var nudges = 0;
      final rec = NightOpticsRecorder(
        gen4: () => gen4,
        connected: () => connected,
        batteryPct: () => battery,
        nudge: () => nudges++,
        now: () => now,
        dir: () async => dir,
      );
      await rec.start();
      expect(rec.active, isFalse);
      now = DateTime(2026, 10, 28, 22);
      rec.evaluate();
      expect(rec.active, isTrue);
      expect(nudges, 1);
      battery = 10;
      rec.evaluate();
      expect(rec.active, isFalse);
      battery = 80;
      gen4 = false;
      rec.evaluate();
      expect(rec.active, isFalse);
      gen4 = true;
      connected = false;
      rec.evaluate();
      expect(rec.active, isFalse);
      connected = true;
      await rec.setEnabled(false);
      expect(rec.active, isFalse);
      await rec.setEnabled(true);
      expect(rec.active, isTrue);
    });

    test('scores live frames and keeps them per night', () async {
      final rec = NightOpticsRecorder(
        gen4: () => true,
        connected: () => true,
        batteryPct: () => null,
        nudge: () {},
        now: () => DateTime(2026, 10, 29, 2),
        dir: () async => dir,
      );
      await rec.start();
      for (var k = 0; k < 31; k++) {
        final s = k * 50;
        rec.onFrame(
            0x2B,
            hexOf(opticsFrame(1000 + k, pulse(s, 220000, 2000), pulse(s, 200000, 1800),
                pulse(s, 160000, 300), pulse(s, 15000, 150))));
      }
      rec.onFrame(0x28, '2802');
      expect(rec.windows, 1);
      expect(rec.good, 1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final nights = await rec.loadNights();
      expect(nights.keys, ['2026-10-28']);
      expect(nights['2026-10-28']!.single.r, closeTo(0.1875, 0.01));
    });
  });
}
