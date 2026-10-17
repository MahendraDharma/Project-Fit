// Irregular-rhythm SCREEN — synthetic known-answer tests.
import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:openstrap_analytics/src/onehz/types.dart';
import 'package:openstrap_analytics/src/onehz/clinical/irregular_rhythm.dart';

void main() {
  group('irregularBeatScreen', () {
    test('organised sinus rhythm does NOT flag', () {
      // Regular ~60 bpm (1000 ms) with tiny RSA-like wobble → low SD1/SD2, low pNN.
      final rr = <double>[
        for (var i = 0; i < 1200; i++) 1000 + 15 * math.sin(i / 8)
      ];
      final m = irregularBeatScreen(rr);
      expect(m.present, isTrue);
      expect(m.tier, Tier.estimate);
      expect(m.value!.flag, isFalse);
      expect(m.value!.sd1sd2, lessThan(0.70));
    });

    test('irregularly-irregular rhythm flags', () {
      // Large beat-to-beat jumps (alternating ±200 ms) → round Poincaré + high pNN70.
      final rnd = math.Random(7);
      final rr = <double>[
        for (var i = 0; i < 1200; i++)
          800.0 + (rnd.nextBool() ? 250 : -50) + rnd.nextInt(120)
      ];
      final m = irregularBeatScreen(rr);
      expect(m.present, isTrue);
      expect(m.value!.flag, isTrue);
      expect(m.value!.pnnPct, greaterThanOrEqualTo(30));
    });

    test('too few beats → absent', () {
      final m = irregularBeatScreen([for (var i = 0; i < 100; i++) 1000]);
      expect(m.present, isFalse);
    });

    test('high artifact fraction suppresses the screen', () {
      final rr = [for (var i = 0; i < 1200; i++) 1000.0];
      final m = irregularBeatScreen(rr, artifactFraction: 0.5);
      expect(m.present, isFalse);
      expect(m.note, contains('artifact'));
    });

    // Regression for the real-world false positive: a day built mostly of
    // organised stretches with two short, fast (many-beats-per-minute, e.g.
    // an exercise episode) scattered stretches blends into a whole-span
    // ratio that clears both thresholds, even though only 2 of 12 real
    // 5-minute windows were ever irregular — see the fix note in
    // irregular_rhythm.dart. Beat count and elapsed time are deliberately
    // decoupled here (each block gets a fixed 5-minute time slot regardless
    // of how many beats it holds) — exactly what a fast episode does for
    // real: more beats land in the same wall-clock window.
    test('scatter confined to 2 of 12 windows does NOT flag once '
        'sustained-window times are supplied, though the blend does', () {
      final rnd = math.Random(7);
      List<double> organised(int n) =>
          [for (var i = 0; i < n; i++) 900 + 15 * math.sin(i / 8)];
      List<double> scattered(int n) => [
            for (var i = 0; i < n; i++)
              800.0 + (rnd.nextDouble() < 0.5 ? 250 : -50) + rnd.nextInt(120)
          ];
      final orgBlocks = [for (var i = 0; i < 10; i++) organised(300)];
      final scatBlocks = [for (var i = 0; i < 2; i++) scattered(1800)];
      final blocks = [
        ...orgBlocks.sublist(0, 5),
        scatBlocks[0],
        ...orgBlocks.sublist(5),
        scatBlocks[1],
      ];
      final rr = [for (final b in blocks) ...b];

      const windowMs = 5 * 60000.0;
      final times = <double>[];
      var windowStart = 0.0;
      for (final b in blocks) {
        // Never step further than the beat itself, or every organised pair
        // reads as a time hole and its window has no contiguous diffs.
        final step = math.min(b.reduce(math.min), windowMs * 0.999 / b.length);
        for (var i = 0; i < b.length; i++) {
          times.add(windowStart + i * step);
        }
        windowStart += windowMs;
      }

      // Without times: falls back to the old whole-span verdict (still flags
      // — this is exactly the bug being fixed).
      final withoutTimes = irregularBeatScreen(rr);
      expect(withoutTimes.value!.flag, isTrue);
      expect(withoutTimes.value!.pnnPct, greaterThanOrEqualTo(30));

      // With times: only 2 of 12 real 5-minute windows are irregular — not
      // sustained — so the day must not flag.
      final withTimes = irregularBeatScreen(rr, nnTimesMs: times);
      expect(withTimes.value!.flag, isFalse);
    });

    test('out-of-range artifact beats sprinkled through organised windows '
        'do not fake a per-window flag', () {
      // Every 6th beat is a hard-implausible outlier (>2000 ms) — the same
      // [keep] mask the aggregate uses must also apply to the windowed pass,
      // or these get counted as real successive-diff jumps inside a window.
      final organised = <double>[
        for (var i = 0; i < 3600; i++)
          i % 6 == 5 ? 5000.0 : 900 + 15 * math.sin(i / 8)
      ];
      final times = <double>[];
      var t = 0.0;
      for (final v in organised) {
        t += v;
        times.add(t);
      }
      final m = irregularBeatScreen(organised, nnTimesMs: times);
      expect(m.value!.flag, isFalse);
    });

    test('beats either side of a time hole are not differenced', () {
      // correctRr hands over a compacted series whose clock skips dropped runs
      // and dropouts. Steady 1000 / 600 ms stretches split by 60 s holes: the
      // only big jumps are across the holes, so SD1 and pNN70 must stay tiny.
      final rr = <double>[];
      final times = <double>[];
      var t = 0.0;
      for (var s = 0; s < 40; s++) {
        final base = s.isEven ? 1000.0 : 600.0;
        t += 60000;
        for (var i = 0; i < 60; i++) {
          final v = base + 5 * math.sin(i / 3);
          t += v;
          rr.add(v);
          times.add(t);
        }
      }
      final m = irregularBeatScreen(rr, nnTimesMs: times);
      expect(m.present, isTrue);
      expect(m.value!.pnnPct, 0);
      expect(m.value!.sd1, lessThan(10));
      expect(m.value!.flag, isFalse);
    });

    // A 5-min slot of 42 in-range beats where only two pairs are contiguous
    // (+75 / -75); every other beat sits behind a 3 s hole. 42 beats used to
    // pass the 40-beat window gate with SD1/pNN70 built from those 2 diffs.
    void fragmented(List<double> rr, List<double> times, double start) {
      var t = start;
      for (var i = 0; i < 42; i++) {
        final v = i == 1
            ? 975.0
            : (i == 0 || i == 2 ? 900.0 : 840.0 + (i * 37) % 196);
        t += i <= 2 ? v : v + 3000;
        rr.add(v);
        times.add(t);
      }
    }

    test('beats split by holes are not a window: gate counts contiguous '
        'pairs, not beats', () {
      final rr = <double>[];
      final times = <double>[];
      for (var w = 0; w < 15; w++) {
        fragmented(rr, times, w * 300000.0);
      }
      final m = irregularBeatScreen(rr, nnTimesMs: times);
      expect(m.present, isFalse);
    });

    test('fragmented windows do not vote toward a sustained flag', () {
      final rnd = math.Random(3);
      final rr = <double>[];
      final times = <double>[];
      var slot = 0;
      void contiguous(double Function() next) {
        var t = slot++ * 300000.0;
        while (t < (slot * 300000.0) - 2000) {
          final v = next();
          t += v;
          rr.add(v);
          times.add(t);
        }
      }
      for (var w = 0; w < 3; w++) {
        contiguous(() => 500.0 + rnd.nextInt(600));
      }
      for (var w = 0; w < 4; w++) {
        contiguous(() => 800.0 + rnd.nextInt(10));
      }
      for (var w = 0; w < 6; w++) {
        fragmented(rr, times, slot++ * 300000.0);
      }
      // 3 of 7 real windows irregular: not sustained. The 6 fragmented
      // slots used to count as 6 more flagged windows (9 of 13).
      final m = irregularBeatScreen(rr, nnTimesMs: times);
      expect(m.present, isTrue);
      expect(m.value!.flag, isFalse);
    });

    test('mismatched nnTimesMs length falls back to the whole-span verdict '
        'instead of crashing', () {
      final rnd = math.Random(7);
      final rr = <double>[
        for (var i = 0; i < 1200; i++)
          800.0 + (rnd.nextBool() ? 250 : -50) + rnd.nextInt(120)
      ];
      final m = irregularBeatScreen(rr, nnTimesMs: [1.0, 2.0, 3.0]);
      expect(m.value!.flag, isTrue);
    });

    test('scatter sustained across (nearly) the whole day still flags with '
        'sustained-window times', () {
      final rnd = math.Random(7);
      final rr = <double>[
        for (var i = 0; i < 1200; i++)
          800.0 + (rnd.nextBool() ? 250 : -50) + rnd.nextInt(120)
      ];
      final times = <double>[];
      var t = 0.0;
      for (final v in rr) {
        t += v;
        times.add(t);
      }
      final m = irregularBeatScreen(rr, nnTimesMs: times);
      expect(m.value!.flag, isTrue);
    });
  });
}
