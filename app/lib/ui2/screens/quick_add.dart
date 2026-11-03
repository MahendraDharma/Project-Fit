// The green + in the middle of the tab bar: one sheet for everything you can
// log or start, wherever you are in the app.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../activity/picker.dart' show ActivityPicker;
import '../ui2.dart';
import 'home_screen.dart' show go;
import 'journal_compose.dart' show JournalCompose;
import 'log_food.dart' show LogFoodSheet;
import 'log_workout.dart' show LogWorkout;
import '../profile/alarm.dart' show AlarmScreen;
import 'workout_screen.dart' show activityHost;

/// Opens [QuickAddSheet] wired to the real screens.
Future<void> showQuickAdd(BuildContext c) {
  // Each action closes the sheet first, then opens its screen from the
  // context the + was pressed in (the sheet's own context is gone by then).
  void then(BuildContext s, void Function() open) {
    Navigator.of(s).pop();
    open();
  }

  return showModalBottomSheet<void>(
    context: c,
    sheetAnimationStyle: sheetMotion(c),
    backgroundColor: P.of(c).bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(R.xxl)),
    ),
    builder: (s) => QuickAddSheet(
      onStart: () => then(
          s,
          () => go(c,
              ActivityPicker(host: activityHost(c.read<AppState>())))),
      onWorkout: () => then(s, () => go(c, const LogWorkout())),
      onFood: () => then(s, () => LogFoodSheet.show(c)),
      onJournal: () => then(s, () => go(c, const JournalCompose())),
      onAlarm: () => then(s, () => go(c, const AlarmScreen())),
    ),
  );
}

/// Soft tiles: start an activity, log a workout, log food, write in the
/// journal, and a full-width one for the wake alarm.
class QuickAddSheet extends StatelessWidget {
  final VoidCallback onStart, onWorkout, onFood, onJournal, onAlarm;
  const QuickAddSheet({
    super.key,
    required this.onStart,
    required this.onWorkout,
    required this.onFood,
    required this.onJournal,
    required this.onAlarm,
  });

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    final p = P.of(c);
    Widget tile(IconData icon, Color accent, String label, VoidCallback onTap) =>
        Pressable(
          onTap: onTap,
          semanticLabel: label,
          child: Container(
            padding: const EdgeInsets.all(S.x4),
            decoration: BoxDecoration(color: p.card, borderRadius: R.rXl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: S.x10,
                  height: S.x10,
                  decoration: BoxDecoration(
                      color: p.wash(accent, strength: 1.6),
                      shape: BoxShape.circle),
                  child: Icon(icon, size: 20, color: p.on(accent)),
                ),
                const SizedBox(height: S.x3),
                Text(label, style: F.head.copyWith(color: p.ink)),
              ],
            ),
          ),
        );
    final tiles = [
      tile(LucideIcons.play, C.green,
          l?.quickStartActivity ?? 'Start an activity', onStart),
      tile(LucideIcons.dumbbell, C.orange,
          l?.quickLogWorkout ?? 'Log a workout', onWorkout),
      tile(LucideIcons.apple, C.pink, l?.quickLogFood ?? 'Log food', onFood),
      tile(LucideIcons.notebookPen, C.indigo,
          l?.quickJournal ?? 'Write in your journal', onJournal),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(S.x4, S.x3, S.x4, S.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: S.x10,
                height: S.x1,
                decoration: BoxDecoration(color: p.line, borderRadius: R.rPill),
              ),
            ),
            const SizedBox(height: S.x4),
            Text(l?.quickAddTitle ?? 'Log or start',
                style: F.t2.copyWith(color: p.ink)),
            const SizedBox(height: S.x4),
            for (var i = 0; i < tiles.length; i += 2) ...[
              if (i > 0) const SizedBox(height: S.x3),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: tiles[i]),
                    const SizedBox(width: S.x3),
                    Expanded(child: tiles[i + 1]),
                  ],
                ),
              ),
            ],
            const SizedBox(height: S.x3),
            Pressable(
              onTap: onAlarm,
              semanticLabel: l?.quickSetAlarm ?? 'Set an alarm',
              child: Container(
                padding: const EdgeInsets.all(S.x4),
                decoration: BoxDecoration(color: p.card, borderRadius: R.rXl),
                child: Row(children: [
                  Container(
                    width: S.x10,
                    height: S.x10,
                    decoration: BoxDecoration(
                        color: p.wash(C.blue, strength: 1.6),
                        shape: BoxShape.circle),
                    child: Icon(LucideIcons.alarmClock, size: 20, color: p.on(C.blue)),
                  ),
                  const SizedBox(width: S.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l?.quickSetAlarm ?? 'Set an alarm',
                            style: F.head.copyWith(color: p.ink)),
                        Text(
                          l?.quickSetAlarmSub ??
                              'Wakes you on the band. Double-tap it to turn it off.',
                          style: F.cap.copyWith(color: p.ink2),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
