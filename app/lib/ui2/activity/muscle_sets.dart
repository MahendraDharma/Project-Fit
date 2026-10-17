// Sets per muscle group — the strength side of the workout tab, beside the
// tonnage chart and never inside strain. The counting rule lives in analytics
// (`muscle_volume.dart`); this file only resolves muscles and draws the card.

import 'package:flutter/material.dart';
import 'package:projectfit_analytics/onehz.dart'
    show MuscleVolume, StrengthSetInput;

import '../../l10n/app_localizations.dart';
import '../theme.dart';
import '../grammar.dart';
import 'catalogue.dart';
import 'summary.dart';

/// A log's sets with each exercise's muscles resolved from the catalogue. An
/// exercise the catalogue does not know keeps its sets, with no muscles: they
/// are counted and reported as unmapped rather than dropped.
List<StrengthSetInput> strengthSetInputs(StrengthLog log) => [
  for (final s in log.sets)
    StrengthSetInput(
      exerciseKey: s.exerciseKey,
      reps: s.reps,
      loadKg: s.loadKg,
      rpe: s.rpe,
      primaryMuscles: exerciseByKey(s.exerciseKey)?.primaryMuscles ?? const [],
      secondaryMuscles:
          exerciseByKey(s.exerciseKey)?.secondaryMuscles ?? const [],
    ),
];

/// TS-08b — sets per muscle group over the last seven days.
///
/// Counted, not scored: a set is 1 for each primary muscle of its exercise
/// and 0.5 for each secondary one, the unit the dose-response literature
/// uses. Hard sets (RPE ≥ 7) are shown only where sets were rated, because
/// an unrated set is not an easy one. Like tonnage, kept out of strain.
class MuscleSetsCard extends StatelessWidget {
  final MuscleVolume volume;
  const MuscleSetsCard(this.volume, {super.key});

  @override
  Widget build(BuildContext c) {
    final v = volume;
    final loc = AppLocalizations.of(c);
    final p = P.of(c);
    final rows = v.setsByMuscle.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = rows.first.value;
    String fmt(double x) =>
        x == x.roundToDouble() ? x.toInt().toString() : x.toStringAsFixed(1);
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc?.workoutMuscleSetsTitle ?? 'Sets per muscle, last 7 days',
            style: F.head.copyWith(color: p.ink),
          ),
          const SizedBox(height: S.x3),
          for (final e in rows) ...[
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    e.key,
                    style: F.cap.copyWith(color: p.ink2),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: R.rPill,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: top > 0 ? e.value / top : 0,
                        child: Container(height: 8, color: p.on(C.orange)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: S.x2),
                SizedBox(
                  width: 64,
                  child: Text(
                    v.hardSetsByMuscle == null
                        ? fmt(e.value)
                        : '${fmt(e.value)} · ${fmt(v.hardSetsByMuscle![e.key] ?? 0)}',
                    textAlign: TextAlign.right,
                    style: F.cap.copyWith(color: p.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: S.x2),
          ],
          const SizedBox(height: S.x1),
          Text(
            (loc?.workoutMuscleSetsFootnote ??
                    'A set counts 1 for the muscles an exercise mainly works and '
                        '0.5 for the ones it assists. ') +
                (v.hardSetsByMuscle == null
                    ? (loc?.workoutMuscleSetsNoRpe ??
                          'Rate sets with RPE to see how many were hard.')
                    : (loc?.workoutMuscleSetsHard ??
                          'The second number is hard sets: RPE 7 or more, '
                              'counted only where you rated the set.')),
            style: F.cap.copyWith(color: p.ink3),
          ),
        ],
      ),
    );
  }
}
