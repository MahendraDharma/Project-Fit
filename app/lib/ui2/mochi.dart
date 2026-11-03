// ProjectFit's mascot: the green dot of the "P." mark as a soft mochi with a
// face (owner's pick, November 2026). It paints from one construction per mood
// and plays ONE short cycle when it appears, changes mood or is tapped, then
// rests: it never loops, and under reduced motion it does not move at all.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

enum MochiMood { idle, think, talk, happy, sleepy, alert }

class Mochi extends StatefulWidget {
  final MochiMood mood;
  final double size;
  const Mochi({super.key, this.mood = MochiMood.idle, this.size = 44});

  @override
  State<Mochi> createState() => MochiState();
}

class MochiState extends State<Mochi> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Motion.slow);

  /// Plays the mood's one cycle again (a tap, a new message).
  void play() {
    final d = motion(context, Motion.mochi);
    if (d == Duration.zero) return;
    _c.duration = d;
    _c.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status == AnimationStatus.dismissed) play();
  }

  @override
  void didUpdateWidget(Mochi oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) play();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => ExcludeSemantics(
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => CustomPaint(
                painter: MochiPainter(widget.mood, _c.isAnimating ? _c.value : 0)),
          ),
        ),
      );
}

/// The mochi on a 120 × 120 grid, scaled to the canvas. [t] runs 0→1 over one
/// cycle; 0 is the resting pose.
class MochiPainter extends CustomPainter {
  final MochiMood mood;
  final double t;
  MochiPainter(this.mood, this.t);

  static Path _body(String shape) {
    final p = Path();
    switch (shape) {
      case 'melt':
        p
          ..moveTo(60, 34)
          ..cubicTo(92, 34, 114, 56, 115, 80)
          ..cubicTo(116, 100, 94, 104, 60, 104)
          ..cubicTo(26, 104, 4, 100, 5, 80)
          ..cubicTo(6, 56, 28, 34, 60, 34);
      case 'tall':
        p
          ..moveTo(60, 12)
          ..cubicTo(86, 12, 104, 38, 105, 66)
          ..cubicTo(106, 94, 90, 104, 60, 104)
          ..cubicTo(30, 104, 14, 94, 15, 66)
          ..cubicTo(16, 38, 34, 12, 60, 12);
      default:
        p
          ..moveTo(60, 20)
          ..cubicTo(90, 20, 110, 44, 111, 70)
          ..cubicTo(112, 94, 92, 104, 60, 104)
          ..cubicTo(28, 104, 8, 94, 9, 70)
          ..cubicTo(10, 44, 30, 20, 60, 20);
    }
    return p..close();
  }

  @override
  void paint(Canvas cv, Size s) {
    final k = s.shortestSide / 120;
    cv.save();
    cv.scale(k);
    final shape = switch (mood) {
      MochiMood.sleepy => 'melt',
      MochiMood.alert => 'tall',
      _ => 'round',
    };
    final pal = switch (mood) {
      MochiMood.sleepy => MochiInk.blue,
      MochiMood.alert => MochiInk.orange,
      _ => MochiInk.green,
    };
    final top = switch (shape) { 'melt' => 34.0, 'tall' => 12.0, _ => 20.0 };
    final ey = switch (shape) { 'melt' => 66.0, 'tall' => 52.0, _ => 58.0 };
    final my = ey + 17;
    final wave = math.sin(t * math.pi * 2);

    // Ground shadow, under the body's own movement.
    cv.drawOval(Rect.fromCenter(center: const Offset(60, 106), width: 96, height: 12),
        Paint()
          ..color = MochiInk.shadow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    if (mood == MochiMood.alert && t > 0) {
      final r = 1 + .35 * t;
      cv.save();
      cv.translate(60, 58);
      cv.scale(r);
      cv.translate(-60, -58);
      cv.drawPath(
          _body(shape),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = pal[1].withValues(alpha: .6 * (1 - t)));
      cv.restore();
    }

    // The body's squash and stretch, from its base.
    cv.save();
    cv.translate(60, 104);
    switch (mood) {
      case MochiMood.happy:
        final hop = math.max(0.0, math.sin(t * math.pi * 2));
        cv.translate(0, -14 * hop);
        cv.scale(1 + .1 * (1 - hop) * (t > 0 ? 1 : 0) - .05 * hop,
            1 - .1 * (1 - hop) * (t > 0 ? 1 : 0) + .05 * hop);
      case MochiMood.sleepy:
        cv.scale(1 + .04 * wave.abs(), 1 - .07 * wave.abs());
      default:
        cv.scale(1 + .03 * wave.abs(), 1 - .03 * wave.abs());
    }
    cv.translate(-60, -104);

    final body = _body(shape);
    cv.drawPath(
        body,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.2, -.44),
            radius: .8,
            colors: pal,
            stops: const [0, .45, 1],
          ).createShader(body.getBounds()));
    cv.save();
    cv.clipPath(body);
    cv.drawOval(Rect.fromCenter(center: Offset(46, top + 16), width: 60, height: 28),
        Paint()
          ..color = MochiInk.sheen
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    cv.drawOval(Rect.fromCenter(center: const Offset(60, 112), width: 112, height: 28),
        Paint()
          ..color = MochiInk.shade
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    cv.restore();
    cv.save();
    cv.translate(38, top + 12);
    cv.rotate(-25 * math.pi / 180);
    cv.drawOval(Rect.fromCenter(center: Offset.zero, width: 10, height: 6),
        Paint()..color = MochiInk.glint);
    cv.restore();

    final ink = pal == MochiInk.blue
        ? MochiInk.inkBlue
        : (pal == MochiInk.orange ? MochiInk.inkOrange : MochiInk.inkGreen);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = ink;
    final fill = Paint()..color = ink;
    final white = Paint()..color = MochiInk.glint;
    final cheek = Paint()..color = MochiInk.cheek;
    void cheeks() {
      cv.drawOval(Rect.fromCenter(center: Offset(30, ey + 10), width: 14, height: 9), cheek);
      cv.drawOval(Rect.fromCenter(center: Offset(90, ey + 10), width: 14, height: 9), cheek);
    }

    // A blink near the middle of the cycle.
    final blink = (t > .44 && t < .52) ? .12 : 1.0;
    void capsules([double dx = 0, double dy = 0]) {
      for (final cx in const [46.0, 74.0]) {
        cv.save();
        cv.translate(cx + dx, ey + dy);
        cv.scale(1, blink);
        cv.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset.zero, width: 11, height: 20),
                const Radius.circular(5.5)),
            fill);
        if (blink == 1) cv.drawCircle(const Offset(-1.5, -5), 2.2, white);
        cv.restore();
      }
    }

    switch (mood) {
      case MochiMood.idle:
        capsules();
        cheeks();
        cv.drawPath(
            Path()
              ..moveTo(52, my)
              ..quadraticBezierTo(60, my + 6, 68, my),
            stroke..strokeWidth = 3.2);
      case MochiMood.think:
        final look = t > 0 ? math.sin(t * math.pi) : 1.0;
        capsules(2 * look, -3 * look);
        cheeks();
        for (var i = 0; i < 3; i++) {
          final ph = ((t * 2 - i * .15) % 1 + 1) % 1;
          final lift = t > 0 ? math.max(0.0, math.sin(ph * math.pi)) * 3 : 0.0;
          cv.drawCircle(Offset(52.0 + 8 * i, my + 1 - lift), 3, fill);
        }
      case MochiMood.talk:
        capsules();
        cheeks();
        final open = t > 0 ? .5 + math.sin(t * math.pi * 8).abs() : 1.0;
        cv.drawOval(
            Rect.fromCenter(center: Offset(60, my + 1), width: 13, height: 8 * open),
            fill);
      case MochiMood.happy:
        for (final cx in const [46.0, 74.0]) {
          cv.drawPath(
              Path()
                ..moveTo(cx - 7, ey + 2)
                ..quadraticBezierTo(cx, ey - 8, cx + 7, ey + 2),
              stroke..strokeWidth = 4);
        }
        cheeks();
        final mouth = Path()
          ..moveTo(48, my - 5)
          ..quadraticBezierTo(60, my + 14, 72, my - 5)
          ..close();
        cv.drawPath(mouth, fill);
        cv.save();
        cv.clipPath(mouth);
        cv.drawOval(Rect.fromCenter(center: Offset(60, my + 7), width: 16, height: 10),
            Paint()..color = MochiInk.tongue);
        cv.restore();
      case MochiMood.sleepy:
        for (final cx in const [46.0, 74.0]) {
          cv.drawPath(
              Path()
                ..moveTo(cx - 7, ey)
                ..quadraticBezierTo(cx, ey + 6, cx + 7, ey),
              stroke..strokeWidth = 3.4);
        }
        cheeks();
        cv.drawOval(Rect.fromCenter(center: Offset(60, my - 2), width: 8, height: 5.2), fill);
      case MochiMood.alert:
        for (final cx in const [46.0, 74.0]) {
          cv.drawCircle(Offset(cx, ey), 10, white);
          cv.drawCircle(Offset(cx, ey + 1), 5.4, fill);
          cv.drawCircle(Offset(cx + 1.8, ey - 1.5), 1.5, white);
        }
        cv.drawOval(Rect.fromCenter(center: Offset(60, my + 2), width: 9.2, height: 10.8), fill);
    }
    cv.restore(); // squash
    cv.restore(); // scale
  }

  @override
  bool shouldRepaint(MochiPainter o) => o.t != t || o.mood != mood;
}
