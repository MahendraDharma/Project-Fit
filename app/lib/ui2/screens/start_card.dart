// The way into a tab: a soft, dark card with one number and a play button
// (redesign B, November 2026). It replaced a full-bleed gradient card with a
// mascot, the look of the app this one was forked from.
//
// One widget, two uses: Workout's "start a session" and Wellness's "start a
// sitting", the same card with a different accent and noun.
//
// The height is a floor, not a fixed size, so the copy can grow at large text.
// Rendered at a real phone width in `start_session_card_test.dart`.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../ui2.dart';

class StartCard extends StatelessWidget {
  const StartCard({
    super.key,
    required this.label,
    required this.count,
    required this.noun,
    required this.accent,
    this.sub,
    this.onTap,
  });

  /// The overline, "Start a session".
  final String label;

  /// How many things are behind the tap, and what to call them: the count of
  /// what the picker offers, never a total this tab cannot start.
  final int count;
  final String noun;

  /// The tab's own colour, on the play button.
  final Color accent;

  /// The line under the count, e.g. "Pick one and go".
  final String? sub;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final subText = sub ?? (l?.startCardDefaultSub ?? 'Pick one and go');
    // Inverted on the light look; the raised card tone on the dark one, where
    // a white card would glare.
    final bg = p.dark ? p.card2 : p.ink;
    final ink = p.dark ? p.ink : p.bg;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 132),
        padding: const EdgeInsets.all(S.x5),
        decoration: BoxDecoration(color: bg, borderRadius: R.rXl, boxShadow: p.el(2)),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: F.cap.copyWith(color: ink.withValues(alpha: .7))),
                  const SizedBox(height: S.x2),
                  Text('$count $noun', style: F.t2.copyWith(color: ink)),
                  const SizedBox(height: S.x1),
                  Text(subText, style: F.cap.copyWith(color: ink.withValues(alpha: .75))),
                ]),
          ),
          const SizedBox(width: S.x3),
          Container(
            width: S.x12 + S.x1,
            height: S.x12 + S.x1,
            decoration: BoxDecoration(color: p.fill(accent), shape: BoxShape.circle),
            child: Icon(LucideIcons.play, size: 24, color: p.inkOnFill),
          ),
        ]),
      ),
    );
  }
}
