// How recovered each muscle is, estimated from the sets logged on it, and the
// body it is drawn on.
//
// AN ESTIMATE, AND IT SAYS SO. No app publishes a validated per-muscle
// recovery formula (Fitbod describes its inputs and a full recovery within
// about six days, not its math). This one is small enough to state whole:
//
//   * A session's dose on a muscle is its sets there — a set counts 1 for a
//     primary muscle and 0.5 for a secondary one (the counting rule of
//     muscle_volume.dart) — and depletes the muscle by dose ÷ 10, capped at
//     all of it. Ten hard sets in one session is the top of the per-session
//     range the hypertrophy literature works in.
//   * That depletion halves every 24 hours, or every 36 hours when any of the
//     sets was rated RPE 9 or more: taking sets to failure delays recovery of
//     neuromuscular function by about 24-48 hours (Morán-Navarro et al. 2017,
//     Eur J Appl Physiol 117:2387). A moderate session is then mostly back by
//     48 hours and nearly whole by 72, the usual 48-72 hour guide.
//   * Sessions add up, and recovered = 100 % minus what is left.
//
// Status bands, as Bevel names them: 80 % and up recovered, 50-80 fatigued,
// under 50 depleted. A muscle with nothing logged in the window has no
// estimate at all, not 100 %.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui2.dart';

/// One session's work on one muscle.
typedef MuscleDose = ({String muscle, DateTime at, double sets, bool toFailure});

const double kDoseFullSets = 10;
const double kHalfLifeHours = 24, kHalfLifeFailureHours = 36;

/// Muscle → % recovered at [now], for every muscle with a dose.
Map<String, double> muscleRecovery(List<MuscleDose> doses, DateTime now) {
  final left = <String, double>{};
  for (final d in doses) {
    final hours = now.difference(d.at).inMinutes / 60;
    if (hours < 0) continue;
    final half = d.toFailure ? kHalfLifeFailureHours : kHalfLifeHours;
    final impact = math.min(1.0, d.sets / kDoseFullSets);
    left[d.muscle] = (left[d.muscle] ?? 0) + impact * math.pow(.5, hours / half);
  }
  return {for (final e in left.entries) e.key: 100 * (1 - math.min(1.0, e.value))};
}

enum MuscleState { recovered, fatigued, depleted }

MuscleState muscleState(double pct) =>
    pct >= 80 ? MuscleState.recovered : (pct >= 50 ? MuscleState.fatigued : MuscleState.depleted);

const kMuscleStateColor = {
  MuscleState.recovered: C.green,
  MuscleState.fatigued: C.yellow,
  MuscleState.depleted: C.red,
};

/// The exercise catalogue's muscle names → the body map's regions.
const Map<String, List<String>> kMuscleRegions = {
  'Abs': ['abs'],
  'Biceps': ['biceps'],
  'Brachialis': ['biceps'],
  'Calves': ['calves', 'left_soleus', 'right_soleus'],
  'Soleus': ['left_soleus', 'right_soleus'],
  'Chest': ['chest'],
  'Glutes': ['gluteal'],
  'Hamstrings': ['hamstring'],
  'Lats': ['upper_back'],
  'Obliquus externus abdominis': ['obliques'],
  'Serratus anterior': ['obliques'],
  'Quads': ['quadriceps'],
  'Shoulders': ['front_deltoids', 'back_deltoids'],
  'Trapezius': ['trapezius'],
  'Triceps': ['triceps'],
};

/// Front and back, each region filled by its muscle's state.
class BodyMap extends StatelessWidget {
  /// Catalogue muscle name → % recovered.
  final Map<String, double> recovered;
  const BodyMap(this.recovered, {super.key});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final fill = <String, Color>{};
    for (final e in recovered.entries) {
      final col = p.on(kMuscleStateColor[muscleState(e.value)]!);
      for (final r in kMuscleRegions[e.key] ?? const <String>[]) {
        fill[r] = col;
      }
    }
    return Semantics(
      label: 'Body map',
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 1.05,
        child: Row(children: [
          Expanded(child: CustomPaint(size: Size.infinite, painter: _Body(kBodyFront, fill, p))),
          const SizedBox(width: S.x3),
          Expanded(child: CustomPaint(size: Size.infinite, painter: _Body(kBodyBack, fill, p))),
        ]),
      ),
    );
  }
}

class _Body extends CustomPainter {
  final List<(String, List<List<double>>)> shapes;
  final Map<String, Color> fill;
  final P p;
  _Body(this.shapes, this.fill, this.p);

  @override
  void paint(Canvas c, Size s) {
    // The data's view box is 100 × 200; fit it, centred.
    final k = math.min(s.width / 100, s.height / 200);
    final dx = (s.width - 100 * k) / 2, dy = (s.height - 200 * k) / 2;
    final base = p.card2;
    for (final (key, polys) in shapes) {
      final col = fill[key] ?? base;
      for (final pts in polys) {
        if (pts.length < 6) continue;
        final path = Path()..moveTo(dx + pts[0] * k, dy + pts[1] * k);
        for (var i = 2; i + 1 < pts.length; i += 2) {
          path.lineTo(dx + pts[i] * k, dy + pts[i + 1] * k);
        }
        path.close();
        c.drawPath(path, Paint()..color = col);
        c.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = p.bg.withValues(alpha: .6));
      }
    }
  }

  @override
  bool shouldRepaint(_Body o) => true;
}

/// Five segments, lit up to the muscle's recovery, in its state's colour.
class RecoveryBar extends StatelessWidget {
  final double pct;
  const RecoveryBar(this.pct, {super.key});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final col = p.on(kMuscleStateColor[muscleState(pct)]!);
    final lit = (pct / 20).ceil().clamp(1, 5);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 5; i++) ...[
        if (i > 0) const SizedBox(width: 3),
        Container(
          width: 9,
          height: 22,
          decoration: BoxDecoration(
            color: i < lit ? (i == lit - 1 ? col : col.withValues(alpha: .45)) : p.track,
            borderRadius: R.rSm,
          ),
        ),
      ],
    ]);
  }
}
