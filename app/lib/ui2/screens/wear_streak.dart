// The wear streak: days in a row with the band on.
//
// THE OWNER'S CALL. This codebase came with a rule of "consistency, never a
// streak" (see grammar.dart `Consistency` and month_grid.dart), because a
// count that resets to zero punishes one missed day more than it rewards
// thirty kept ones. The owner asked for a WHOOP-style streak anyway. It is
// kept gentle: the best run stays on screen after a break, nothing here
// notifies, and a day counts on stored wear minutes alone — no score, no
// threshold on how well you slept or trained.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/day_label.dart';
import '../../data/local_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/date_text.dart';
import '../ui2.dart';
import 'home_screen.dart' show go, pointsOf, repoOf;
import 'metric_detail.dart' show detailScaffold;

/// Minutes of wear that make a day count: four hours.
const double kStreakWearMin = 240;

/// Milestones, in days.
const List<int> kStreakMilestones = [3, 7, 10, 25, 50, 100, 250, 365];

/// What the streak is on [today], from stored wear minutes by day.
class WearStreak {
  /// Days in the current run. Today counts once it has enough wear; until
  /// then the run ending yesterday is still alive.
  final int current;
  final DateTime? startedOn;
  final int best;

  /// Monday to Sunday of this week: true worn, false not, null still ahead.
  final List<bool?> week;
  const WearStreak({this.current = 0, this.startedOn, this.best = 0, this.week = const []});

  static WearStreak from(Map<String, double> wearMin, DateTime today) {
    bool worn(DateTime d) => (wearMin[dayLabelOf(d)] ?? 0) >= kStreakWearMin;
    DateTime day(int back) => DateTime(today.year, today.month, today.day - back);

    var back = worn(day(0)) ? 0 : 1;
    var current = 0;
    while (worn(day(back + current))) {
      current++;
    }
    final startedOn = current == 0 ? null : day(back + current - 1);

    final days = wearMin.keys.map(DateTime.parse).toList()..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final d in days) {
      if ((wearMin[dayLabelOf(d)] ?? 0) < kStreakWearMin) {
        run = 0;
        prev = null;
        continue;
      }
      run = prev != null && DateTime(prev.year, prev.month, prev.day + 1) == d ? run + 1 : 1;
      prev = d;
      if (run > best) best = run;
    }
    if (current > best) best = current;

    final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    final week = [
      for (var i = 0; i < 7; i++)
        DateTime(monday.year, monday.month, monday.day + i).isAfter(today)
            ? null
            : worn(DateTime(monday.year, monday.month, monday.day + i)),
    ];
    return WearStreak(current: current, startedOn: startedOn, best: best, week: week);
  }

  /// The milestones either side of the current run.
  (int, int?) get milestones {
    var last = 0;
    for (final m in kStreakMilestones) {
      if (current < m) return (last, m);
      last = m;
    }
    return (last, null);
  }

  static Future<WearStreak> load(LocalRepository repo, {DateTime? now}) async {
    final pts = pointsOf(await repo.getChart('wear'));
    return from({
      for (final p in pts) dayLabelOf(DateTime.fromMillisecondsSinceEpoch(p.t * 1000)): p.v,
    }, now ?? DateTime.now());
  }
}

/// The flame and its number, for Home's top bar. Nothing until a first day.
class StreakChip extends StatefulWidget {
  final WearStreak? streak;
  const StreakChip({super.key, this.streak});

  @override
  State<StreakChip> createState() => _StreakChipState();
}

class _StreakChipState extends State<StreakChip> with RevisionReload {
  // Re-read when a sync lands new data while this screen is open.
  @override
  bool get revisionReloads => widget.streak == null;

  @override
  void reload() => _load();

  WearStreak? _s;

  @override
  void initState() {
    super.initState();
    _s = widget.streak;
    if (_s == null) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repo = repoOf(context);
    if (repo == null) return;
    try {
      final s = await WearStreak.load(repo);
      if (mounted) setState(() => _s = s);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext c) {
    final s = _s;
    if (s == null || s.current == 0) return const SizedBox.shrink();
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    return Pressable(
      onTap: () => go(c, StreakScreen(streak: s)),
      semanticLabel: l?.streakChip(s.current) ?? '${s.current}-day streak',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: S.x2, vertical: S.x1),
        decoration: BoxDecoration(color: p.card, borderRadius: R.rPill, border: Border.all(color: p.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.flame, size: 16, color: p.on(C.orange)),
          const SizedBox(width: S.x1),
          Text('${s.current}', style: F.n17.copyWith(color: p.ink)),
        ]),
      ),
    );
  }
}

class StreakScreen extends StatelessWidget {
  final WearStreak streak;
  const StreakScreen({super.key, required this.streak});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final s = streak;
    final loc = l?.localeName ?? 'en';
    final (last, next) = s.milestones;
    final monday = DateTime(2026, 10, 19);
    final dayNames = [
      for (var i = 0; i < 7; i++) localizedDate(DateTime(monday.year, monday.month, monday.day + i), loc, pattern: 'EEE'),
    ];
    Widget flame(bool? on, double size) => Icon(
          LucideIcons.flame,
          size: size,
          color: on == true ? p.on(C.orange) : (on == false ? p.ink3 : p.line),
        );

    return detailScaffold(c, l?.streakTitle ?? 'Day streak', [
      const SizedBox(height: S.x6),
      Center(
        child: ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [C.yellow, C.orange, C.red],
          ).createShader(r),
          child: Icon(LucideIcons.flame, size: 120, color: p.ink),
        ),
      ),
      Center(child: Text('${s.current}', style: F.n48.copyWith(color: p.ink))),
      Center(child: Text(l?.streakTitle ?? 'Day streak', style: F.t2.copyWith(color: p.ink))),
      const SizedBox(height: S.x1),
      Center(
        child: Text(l?.streakHow ?? 'Wear your band at least 4 hours a day',
            style: F.body.copyWith(color: p.ink3), textAlign: TextAlign.center),
      ),
      const SizedBox(height: S.x5),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: _Fact(
                s.startedOn == null ? '–' : localizedDate(s.startedOn!, loc, pattern: 'd MMM yyyy'),
                l?.streakStarted ?? 'Streak started'),
          ),
          VerticalDivider(color: p.line, width: S.x5),
          Expanded(child: _Fact('${s.best}', l?.streakBest ?? 'Longest streak')),
        ]),
      ),
      const SizedBox(height: S.x5),
      Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l?.streakThisWeek ?? 'This week', style: F.label.copyWith(color: p.ink)),
          const SizedBox(height: S.x3),
          Row(children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Column(children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(dayNames[i].toUpperCase(), style: F.labelSm.copyWith(color: p.ink3)),
                  ),
                  const SizedBox(height: S.x2),
                  flame(i < s.week.length ? s.week[i] : null, 26),
                ]),
              ),
          ]),
        ]),
      ),
      const SizedBox(height: S.x3),
      Surface(
        child: Row(children: [
          _Badge(last, lit: true),
          const SizedBox(width: S.x3),
          Expanded(
            child: Column(children: [
              Text(
                next == null
                    ? (l?.streakAllMilestones ?? 'Every milestone reached')
                    : (l?.streakToNext(next - s.current) ?? '${next - s.current} more days to the next milestone'),
                style: F.body.copyWith(color: p.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: S.x2),
              ClipRRect(
                borderRadius: R.rPill,
                child: LinearProgressIndicator(
                  value: next == null ? 1 : (s.current - last) / (next - last),
                  minHeight: 6,
                  color: C.orange,
                  backgroundColor: p.track,
                ),
              ),
            ]),
          ),
          const SizedBox(width: S.x3),
          _Badge(next ?? last, lit: next == null),
        ]),
      ),
    ]);
  }
}

class _Fact extends StatelessWidget {
  final String value, label;
  const _Fact(this.value, this.label);

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return Column(children: [
      FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: F.head.copyWith(color: p.ink))),
      Text(label, style: F.body.copyWith(color: p.ink3), textAlign: TextAlign.center),
    ]);
  }
}

class _Badge extends StatelessWidget {
  final int days;
  final bool lit;
  const _Badge(this.days, {required this.lit});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.card2,
        border: Border.all(color: lit ? p.on(C.orange) : p.line, width: 2),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(LucideIcons.flame, size: 20, color: lit ? p.on(C.orange) : p.ink3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(days == 0 ? '–' : '$days', style: F.n24.copyWith(color: p.ink)),
        ),
      ]),
    );
  }
}
