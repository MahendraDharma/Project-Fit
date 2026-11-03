// The one thing the mochi says on Home, picked from figures the app already
// has. No AI: a fixed priority over facts, so the same morning always says the
// same thing, and a day with nothing worth saying says nothing.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../state/clock_format.dart';
import '../../state/prefs.dart';
export '../../platform/install_expiry.dart' show installEndsText;
import '../ui2.dart';

enum NudgeKind { redeploy, battery, alarm, stale, bedtime, recoveryHigh, recoveryMid, recoveryLow }

typedef Nudge = ({NudgeKind kind, MochiMood mood});

/// Highest priority first. [hour] is the local hour; [batteryPct] and
/// [charging] are the band's; [staleHours] is how old the newest band record
/// is; [bedtimeMin] tonight's recommended bedtime (minute of day); [readiness]
/// today's recovery 0–100; [installHoursLeft] how long until this iPhone
/// install stops opening, when that is close ([InstallExpiry]). Null inputs
/// simply cannot fire their nudge.
Nudge? pickNudge({
  required int hour,
  double? batteryPct,
  bool? charging,
  bool alarmArmed = true,
  double? staleHours,
  double? bedtimeMin,
  double? readiness,
  double? installHoursLeft,
  Set<NudgeKind> dismissed = const {},
}) {
  Nudge? pick(NudgeKind k, MochiMood m) => dismissed.contains(k) ? null : (kind: k, mood: m);
  final evening = hour >= 17;
  return [
    // First: once it lapses the app does not open at all, alarm included.
    if (installHoursLeft != null) pick(NudgeKind.redeploy, MochiMood.alert),
    if (batteryPct != null && charging == false && batteryPct < 20)
      pick(NudgeKind.battery, MochiMood.alert),
    if (evening && !alarmArmed) pick(NudgeKind.alarm, MochiMood.alert),
    if (staleHours != null && staleHours >= 24) pick(NudgeKind.stale, MochiMood.think),
    if (evening && bedtimeMin != null) pick(NudgeKind.bedtime, MochiMood.sleepy),
    if (hour >= 5 && hour < 12 && readiness != null)
      readiness >= 67
          ? pick(NudgeKind.recoveryHigh, MochiMood.happy)
          : readiness >= 34
              ? pick(NudgeKind.recoveryMid, MochiMood.idle)
              : pick(NudgeKind.recoveryLow, MochiMood.sleepy),
  ].whereType<Nudge>().firstOrNull;
}

/// Kinds the user closed today, so a dismissed nudge stays gone until tomorrow.
Set<NudgeKind> dismissedNudges(String day) {
  final raw = Prefs.getString(_key, '');
  if (!raw.startsWith('$day:')) return const {};
  return {
    for (final n in raw.substring(day.length + 1).split(','))
      for (final k in NudgeKind.values)
        if (k.name == n) k,
  };
}

void dismissNudge(String day, NudgeKind k) {
  final now = {...dismissedNudges(day), k};
  Prefs.setString(_key, '$day:${now.map((e) => e.name).join(',')}');
}

const _key = 'home_nudge_dismissed';

/// The words for [n]. Figures the message quotes come in as arguments.
String nudgeText(AppLocalizations? l, Nudge n,
    {double? batteryPct, double? bedtimeMin, double? readiness, String installEnds = ''}) {
  final pct = '${(batteryPct ?? 0).round()}';
  final bed = bedtimeMin == null ? '' : formatClockMinute(bedtimeMin.round());
  final r = '${(readiness ?? 0).round()}';
  return switch (n.kind) {
    NudgeKind.redeploy => l?.nudgeRedeploy(installEnds) ??
        'This install stops opening $installEnds. Connect the iPhone to your Mac and '
            'run the app again from there to renew it.',
    NudgeKind.battery =>
      l?.nudgeBattery(pct) ?? 'Your band is at $pct%. Charge it before bed.',
    NudgeKind.alarm => l?.nudgeAlarm ?? 'Your alarm for tomorrow morning is not on.',
    NudgeKind.stale =>
      l?.nudgeStale ?? 'Your band has not synced for a day. Open it near your phone to catch up.',
    NudgeKind.bedtime =>
      l?.nudgeBedtime(bed) ?? 'To get the sleep you need, be in bed by $bed tonight.',
    NudgeKind.recoveryHigh =>
      l?.nudgeRecoveryHigh(r) ?? 'Recovery $r%. Your body is ready for a harder day.',
    NudgeKind.recoveryMid =>
      l?.nudgeRecoveryMid(r) ?? 'Recovery $r%. A steady, moderate day suits you.',
    NudgeKind.recoveryLow =>
      l?.nudgeRecoveryLow(r) ?? 'Recovery $r%. Take it easy today; rest counts too.',
  };
}

/// The mochi's message, spoken from the mochi in Home's header (its sharp
/// corner points up at it), with a close button and an optional action.
class NudgeBubble extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;
  final VoidCallback onClose;
  const NudgeBubble({
    super.key,
    required this.text,
    this.action,
    this.onAction,
    required this.onClose,
  });

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final bg = p.dark ? p.card2 : p.ink;
    final ink = p.dark ? p.ink : p.bg;
    return Semantics(
      container: true,
      child: Container(
          padding: const EdgeInsets.fromLTRB(S.x4, S.x3, S.x1, S.x3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(R.lg),
              topRight: Radius.circular(R.sm),
              bottomRight: Radius.circular(R.lg),
              bottomLeft: Radius.circular(R.lg),
            ),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(text, style: F.body.copyWith(color: ink)),
                if (action != null && onAction != null) ...[
                  const SizedBox(height: S.x2),
                  Pressable(
                    onTap: onAction,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: S.x4, vertical: S.x2),
                      decoration: BoxDecoration(color: p.fill(C.green), borderRadius: R.rPill),
                      child: Text(action!,
                          style: F.cap.copyWith(
                              color: p.inkOnFill, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ]),
            ),
            Pressable(
              onTap: onClose,
              semanticLabel: l?.nudgeClose ?? 'Close',
              child: Icon(LucideIcons.x, size: 16, color: ink.withValues(alpha: .6)),
            ),
          ]),
        ),
    );
  }
}

