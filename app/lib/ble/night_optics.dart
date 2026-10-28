// Night SpO2 groundwork for WHOOP 4.0 (gen4): the red/IR ratio from the live
// optical stream, scored in 30 s windows, and a personal calibration of that
// ratio against the Garmin watch's own SpO2 (docs/WHOOP_PARITY.md, "Rekaman
// mentah live").
//
// The live 0x2B record, subtype 0x0b, carries four optical channels, 50
// samples each per frame (~51 Hz): A and B pulse with the green LED; C and D
// pulse together and are the red/IR candidates. D's DC arrives already
// offset-subtracted by the front end, so the ratio
//
//   R = (AC_C / DC_C) / (AC_D / DC_D)
//
// is stable on a still wrist (0.17-0.19 over 10 min) but is not on the
// textbook SpO2 curve. Nothing here claims a percentage until a fit against
// a reference the person already trusts says what R means for their band.
//
// Pure: no I/O, no clock. NightOpticsRecorder (state/) feeds and stores it.
import 'dart:math' as math;
import 'dart:typed_data';

/// One 0x2B/0x0b frame's optical samples.
class OpticsBlock {
  /// Band clock, ms (u32 seconds @7 + u16 subseconds @11).
  final int bandMs;
  final List<int> a, b, c, d;
  const OpticsBlock(this.bandMs, this.a, this.b, this.c, this.d);
}

const int _slot1Header = 14, _slot1Samples = 38;
const int _slot3Header = 1289, _slot3Samples = 1313;

/// The optical channels of a live gen4 R10 frame, or null for anything else
/// (the 0x0a motion subtype, gen5's 0x2B IMU, a short or reshaped frame).
OpticsBlock? parseOpticsFrame(Uint8List f) {
  if (f.length < _slot3Samples || f[0] != 0x2B || f[1] != 0x0B) return null;
  final n = f[_slot1Header];
  if (n == 0 || f[_slot3Header] != n) return null;
  if (_slot1Samples + 8 * n > _slot3Header ||
      _slot3Samples + 8 * n > f.length) {
    return null;
  }
  final v = ByteData.sublistView(f);
  List<int> run(int at, int count) =>
      [for (var i = 0; i < count; i++) v.getUint32(at + 4 * i, Endian.little)];
  final s1 = run(_slot1Samples, 2 * n), s3 = run(_slot3Samples, 2 * n);
  final ms = v.getUint32(7, Endian.little) * 1000 +
      v.getUint16(11, Endian.little) * 1000 ~/ 65536;
  return OpticsBlock(
      ms, s1.sublist(0, n), s1.sublist(n), s3.sublist(0, n), s3.sublist(n));
}

/// One scored 30 s window.
class OpticWindow {
  /// Wall clock at the window's end, ms.
  final int atMs;
  final double r, corrCD, corrCA, piC, piD;
  const OpticWindow({
    required this.atMs,
    required this.r,
    required this.corrCD,
    required this.corrCA,
    required this.piC,
    required this.piD,
  });

  /// C and D see the same pulse, and that pulse is the heart's (it follows
  /// the green channel). Motion and a loose band fail one or the other.
  bool get ok => corrCD >= kMinCorrCD && corrCA.abs() >= kMinCorrCA && r.isFinite && r > 0;

  Map<String, Object?> toJson() => {
        't': atMs,
        'r': _round(r, 5),
        'cd': _round(corrCD, 3),
        'ca': _round(corrCA, 3),
        'pc': _round(piC, 7),
        'pd': _round(piD, 7),
      };

  static OpticWindow? fromJson(Object? j) {
    if (j is! Map) return null;
    try {
      return OpticWindow(
        atMs: (j['t'] as num).toInt(),
        r: (j['r'] as num).toDouble(),
        corrCD: (j['cd'] as num).toDouble(),
        corrCA: (j['ca'] as num).toDouble(),
        piC: (j['pc'] as num).toDouble(),
        piD: (j['pd'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}

const double kMinCorrCD = 0.9, kMinCorrCA = 0.6;

double _round(double v, int places) {
  final p = math.pow(10, places);
  return (v * p).roundToDouble() / p;
}

/// Accumulates blocks into 30 s windows. A gap in the band's clock (a dropped
/// frame, a stream re-armed) starts a fresh window rather than splicing two
/// stretches of signal together.
class OpticWindowAnalyzer {
  static const double fs = 51.0;
  static const int windowSamples = 1530; // 30 s

  /// Filter settling skipped at the start of every window (2 s).
  static const int settle = 100;

  final List<int> _a = [], _c = [], _d = [];
  int? _lastBandMs;

  void reset() {
    _a.clear();
    _c.clear();
    _d.clear();
    _lastBandMs = null;
  }

  /// Feed one block; returns a window when one completes.
  OpticWindow? add(OpticsBlock b, int wallMs) {
    final last = _lastBandMs;
    if (last != null && (b.bandMs - last > 3000 || b.bandMs <= last)) reset();
    _lastBandMs = b.bandMs;
    _a.addAll(b.a);
    _c.addAll(b.c);
    _d.addAll(b.d);
    if (_c.length < windowSamples) return null;
    final w = scoreWindow(_a.sublist(0, windowSamples),
        _c.sublist(0, windowSamples), _d.sublist(0, windowSamples), wallMs);
    _a.removeRange(0, windowSamples);
    _c.removeRange(0, windowSamples);
    _d.removeRange(0, windowSamples);
    return w;
  }
}

/// Score one window of green (A) and red/IR (C, D) samples.
OpticWindow scoreWindow(List<int> a, List<int> c, List<int> d, int atMs) {
  final fa = _bandpass(a), fc = _bandpass(c), fd = _bandpass(d);
  final piC = _rms(fc) / _mean(c), piD = _rms(fd) / _mean(d);
  return OpticWindow(
    atMs: atMs,
    r: piD == 0 ? double.nan : piC / piD,
    corrCD: _corr(fc, fd),
    corrCA: _corr(fc, fa),
    piC: piC,
    piD: piD,
  );
}

/// 0.6-4 Hz: second-order Butterworth high-pass then low-pass, causal, with
/// the first [OpticWindowAnalyzer.settle] samples dropped.
List<double> _bandpass(List<int> x) {
  final x0 = x.first.toDouble();
  final hp = _Biquad.highPass(0.6, OpticWindowAnalyzer.fs);
  final lp = _Biquad.lowPass(4.0, OpticWindowAnalyzer.fs);
  final out = <double>[];
  for (var i = 0; i < x.length; i++) {
    final y = lp.step(hp.step(x[i] - x0));
    if (i >= OpticWindowAnalyzer.settle) out.add(y);
  }
  return out;
}

class _Biquad {
  final double b0, b1, b2, a1, a2;
  double _x1 = 0, _x2 = 0, _y1 = 0, _y2 = 0;
  _Biquad._(this.b0, this.b1, this.b2, this.a1, this.a2);

  factory _Biquad._make(double f0, double fs, bool high) {
    final w = 2 * math.pi * f0 / fs, cw = math.cos(w);
    final alpha = math.sin(w) / (2 * math.sqrt1_2);
    final a0 = 1 + alpha;
    final k = high ? (1 + cw) / 2 : (1 - cw) / 2;
    return _Biquad._(k / a0, (high ? -2 * k : 2 * k) / a0, k / a0,
        -2 * cw / a0, (1 - alpha) / a0);
  }
  factory _Biquad.highPass(double f0, double fs) => _Biquad._make(f0, fs, true);
  factory _Biquad.lowPass(double f0, double fs) => _Biquad._make(f0, fs, false);

  double step(double x) {
    final y = b0 * x + b1 * _x1 + b2 * _x2 - a1 * _y1 - a2 * _y2;
    _x2 = _x1;
    _x1 = x;
    _y2 = _y1;
    _y1 = y;
    return y;
  }
}

double _mean(List<num> x) => x.fold<double>(0, (s, v) => s + v) / x.length;

double _rms(List<double> x) {
  final m = _mean(x);
  return math.sqrt(x.fold<double>(0, (s, v) => s + (v - m) * (v - m)) / x.length);
}

double _corr(List<double> x, List<double> y) {
  final mx = _mean(x), my = _mean(y);
  var sxy = 0.0, sxx = 0.0, syy = 0.0;
  for (var i = 0; i < x.length; i++) {
    final dx = x[i] - mx, dy = y[i] - my;
    sxy += dx * dy;
    sxx += dx * dx;
    syy += dy * dy;
  }
  return sxx == 0 || syy == 0 ? 0 : sxy / math.sqrt(sxx * syy);
}

// ── Calibration against the Garmin watch ─────────────────────────────────────

/// A reference reading paired with the band's ratio around it.
typedef CalPair = ({int atMs, double r, double spo2});

/// Pair each reference SpO2 reading with the median R of the good windows
/// within ±[span] of it. Readings with fewer than 2 good windows near them
/// are left out.
List<CalPair> pairWithReference(
  List<OpticWindow> windows,
  List<({int atMs, double spo2})> refs, {
  Duration span = const Duration(minutes: 5),
}) {
  final good = windows.where((w) => w.ok).toList()
    ..sort((x, y) => x.atMs.compareTo(y.atMs));
  final out = <CalPair>[];
  for (final ref in refs) {
    final near = [
      for (final w in good)
        if ((w.atMs - ref.atMs).abs() <= span.inMilliseconds) w.r
    ];
    if (near.length < 2) continue;
    out.add((atMs: ref.atMs, r: _median(near), spo2: ref.spo2));
  }
  return out;
}

double _median(List<double> v) {
  final s = [...v]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}

/// SpO2 = [a] + [b]·R, fitted to the person's own pairs.
class SpO2Calibration {
  final double a, b, r2;
  final int pairs;
  const SpO2Calibration(this.a, this.b, this.r2, this.pairs);

  double spo2(double r) => (a + b * r).clamp(70.0, 100.0).toDouble();
}

/// Why a fit is not usable yet, or the fit.
sealed class CalibrationResult {
  const CalibrationResult();
}

class CalibrationReady extends CalibrationResult {
  final SpO2Calibration cal;
  const CalibrationReady(this.cal);
}

class CalibrationPending extends CalibrationResult {
  /// 'pairs' (too few), 'spread' (the readings barely vary), 'fit' (the
  /// ratio does not follow the reading, or slopes the wrong way).
  final String reason;
  final int pairs;
  const CalibrationPending(this.reason, this.pairs);
}

const int kMinCalPairs = 20;

/// Least squares, accepted only when it means something: enough pairs, a
/// reference that actually varies, a ratio that falls as SpO2 rises, and a
/// fit that explains a fair share of the variation.
CalibrationResult fitCalibration(List<CalPair> pairs) {
  final n = pairs.length;
  if (n < kMinCalPairs) return CalibrationPending('pairs', n);
  final xs = [for (final p in pairs) p.r], ys = [for (final p in pairs) p.spo2];
  final ys0 = [...ys]..sort();
  if (ys0.last - ys0.first < 3) return CalibrationPending('spread', n);
  final mx = _mean(xs), my = _mean(ys);
  var sxy = 0.0, sxx = 0.0, syy = 0.0;
  for (var i = 0; i < n; i++) {
    sxy += (xs[i] - mx) * (ys[i] - my);
    sxx += (xs[i] - mx) * (xs[i] - mx);
    syy += (ys[i] - my) * (ys[i] - my);
  }
  if (sxx == 0 || syy == 0) return CalibrationPending('spread', n);
  final b = sxy / sxx, a = my - b * mx;
  final r2 = sxy * sxy / (sxx * syy);
  if (b >= 0 || r2 < 0.3) return CalibrationPending('fit', n);
  return CalibrationReady(SpO2Calibration(a, b, r2, n));
}
