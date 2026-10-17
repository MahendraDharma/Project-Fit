// HRV STATUS — this week's overnight HRV against the 60 nights before it.
//
// The Garmin idea, from the method it rests on: analytics `hrvStatus` (7-night
// mean of ln RMSSD against a 60-night baseline ± Plews' smallest worthwhile
// change). Works on any band that measures beat-to-beat intervals overnight,
// which is what puts it on a WHOOP 4.0.
//
// No verdict colour: above or below baseline is a direction, and hard
// training, illness, alcohol and a deload can all produce either one.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:projectfit_analytics/onehz.dart' as ana
    show HrvStatus, Metric;

import '../../l10n/app_localizations.dart';
import '../../models/metric.dart' show needMessageFromNote;
import '../ui2.dart';

class HrvStatusCard extends StatelessWidget {
  const HrvStatusCard(this.status, {super.key});

  /// From analytics `hrvStatus`; absent while the nights are too few.
  final ana.Metric<ana.HrvStatus> status;

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    final p = P.of(c);
    final v = status.value;
    if (v == null) {
      return StatusCard(
        l?.hrvStatusLearningTitle ?? 'HRV status is still learning',
        needMessageFromNote(status.note) ??
            (l?.hrvStatusLearningBody ??
                'It needs four nights this week and two weeks of nights '
                    'before them.'),
        icon: LucideIcons.hourglass,
      );
    }
    final label = switch (v.status) {
      'above' => l?.hrvStatusAbove ?? 'Above your range',
      'below' => l?.hrvStatusBelow ?? 'Below your range',
      _ => l?.hrvStatusBalanced ?? 'Inside your range',
    };
    String ms(double x) => x.round().toString();
    return Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Wrap, not Row: at large text sizes the label moves under the title
        // instead of pushing it off the card.
        Wrap(
          spacing: S.x2,
          runSpacing: S.x2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l?.hrvStatusTitle ?? 'HRV status',
                style: F.head.copyWith(color: p.ink)),
            Pill(label, v.status == 'balanced' ? C.blue : C.purple, wrap: true),
          ],
        ),
        const SizedBox(height: S.x2),
        Text(
          l?.hrvStatusWeek(ms(v.weekMeanMs), ms(v.rangeLowMs),
                  ms(v.rangeHighMs)) ??
              '7-night average ${ms(v.weekMeanMs)} ms · your usual range '
                  '${ms(v.rangeLowMs)}–${ms(v.rangeHighMs)} ms',
          style: F.body.copyWith(color: p.ink2),
        ),
        const SizedBox(height: S.x2),
        Text(
          l?.hrvStatusFootnote ??
              'This week’s overnight HRV against the 60 nights before it. '
                  'Training, illness, alcohol and travel can all move it, '
                  'and this cannot tell them apart.',
          style: F.cap.copyWith(color: p.ink3),
        ),
      ]),
    );
  }
}
