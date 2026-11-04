// The fit program on screen: the card on the Activity tab, the setup, and the
// day-by-day schedule. The plan itself is fit_plan.dart; this file stores the
// person's choices and ticks, and draws.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/date_text.dart';
import '../../state/prefs.dart';
import '../activity/catalogue.dart';
import '../activity/live.dart' show ActivityHost;
import '../activity/setup.dart';
import '../profile/profile.dart' show SetRow;
import '../ui2.dart';
import 'fit_plan.dart';

// ══════════════════ storage ══════════════════

/// The choices and the ticked days, in Prefs. The plan is rebuilt from the
/// choices, so a change to the rules reaches a program already running.
class FitPlanStore {
  static const _kConfig = 'fit_plan_config';
  static const _kDone = 'fit_plan_done';

  /// Bumped on every change, so screens holding a card rebuild.
  static final revision = ValueNotifier<int>(0);

  static FitPlanConfig? get config =>
      FitPlanConfig.decode(Prefs.getString(_kConfig, ''));

  static Set<int> get done {
    try {
      final raw = jsonDecode(Prefs.getString(_kDone, '[]'));
      return {for (final v in raw as List) if (v is num) v.toInt()};
    } catch (_) {
      return {};
    }
  }

  static void save(FitPlanConfig c) {
    Prefs.setString(_kConfig, c.encode());
    Prefs.setString(_kDone, '[]');
    revision.value++;
  }

  static void setDone(int day, bool on) {
    final d = done;
    on ? d.add(day) : d.remove(day);
    Prefs.setString(_kDone, jsonEncode(d.toList()..sort()));
    revision.value++;
  }

  static void clear() {
    Prefs.setString(_kConfig, '');
    Prefs.setString(_kDone, '[]');
    revision.value++;
  }
}

// ══════════════════ words ══════════════════

String sessionName(AppLocalizations? l, Session s) => switch (s) {
      Session.fullA => l?.fitPlanSessionFullA ?? 'Full body A',
      Session.fullB => l?.fitPlanSessionFullB ?? 'Full body B',
      Session.upper => l?.fitPlanSessionUpper ?? 'Upper body',
      Session.lower => l?.fitPlanSessionLower ?? 'Lower body',
    };

String _activity(BuildContext c, String key) =>
    activityByName(key)?.displayName(c) ?? key;

/// "Today: Full body A, 5 exercises" — what the day is, in one line.
String dayLine(BuildContext c, PlanDay d) {
  final l = AppLocalizations.of(c);
  return switch (d.kind) {
    DayKind.strength => l?.fitPlanDayStrength(sessionName(l, d.session!), '${d.items.length}') ??
        '${sessionName(l, d.session!)}, ${d.items.length} exercises',
    DayKind.cardio => l?.fitPlanDayCardio(_activity(c, d.cardio!.activityKey), '${d.cardio!.minutes}') ??
        '${_activity(c, d.cardio!.activityKey)}, ${d.cardio!.minutes} min',
    DayKind.rest => l?.fitPlanDayRest ?? 'Rest day',
  };
}

String _equipName(AppLocalizations? l, Equip e) => switch (e) {
      Equip.pullUpBar => l?.fitPlanEquipPullUpBar ?? 'Pull-up bar',
      Equip.dipBars => l?.fitPlanEquipDipBars ?? 'Dip bars',
      Equip.bench => l?.fitPlanEquipBench ?? 'Bench or sturdy chair',
      Equip.dumbbells => l?.fitPlanEquipDumbbells ?? 'Dumbbells',
      Equip.kettlebell => l?.fitPlanEquipKettlebell ?? 'Kettlebell',
      Equip.barbell => l?.fitPlanEquipBarbell ?? 'Barbell and plates',
      Equip.cableMachine => l?.fitPlanEquipCable ?? 'Cable machine',
      Equip.machines => l?.fitPlanEquipMachines ?? 'Weight machines',
      Equip.abWheel => l?.fitPlanEquipAbWheel ?? 'Ab wheel',
      Equip.jumpRope => l?.fitPlanEquipJumpRope ?? 'Jump rope',
      Equip.treadmill => l?.fitPlanEquipTreadmill ?? 'Treadmill',
      Equip.indoorBike => l?.fitPlanEquipIndoorBike ?? 'Exercise bike',
      Equip.rower => l?.fitPlanEquipRower ?? 'Rowing machine',
    };

IconData _kindIcon(DayKind k) => switch (k) {
      DayKind.strength => LucideIcons.dumbbell,
      DayKind.cardio => LucideIcons.heartPulse,
      DayKind.rest => LucideIcons.moon,
    };

Color _kindTint(DayKind k) => switch (k) {
      DayKind.strength => C.purple,
      DayKind.cardio => C.red,
      DayKind.rest => C.blue,
    };

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ══════════════════ the card ══════════════════

/// The program's door on the Activity tab: an offer to make one, or where the
/// running one stands today.
class FitPlanCard extends StatelessWidget {
  final FitPlanConfig? config;
  final Set<int> done;
  final DateTime today;
  final VoidCallback onTap;
  const FitPlanCard({
    super.key,
    required this.config,
    required this.today,
    required this.onTap,
    this.done = const {},
  });

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final cfg = config;
    final plan = cfg == null ? null : buildFitPlan(cfg);
    final day = plan == null ? null : planDayOn(plan, today);
    final title = l?.fitPlanTitle ?? 'Fit program';
    final String sub;
    if (cfg == null) {
      sub = l?.fitPlanCardNone ??
          'A day-by-day plan for 30, 60 or 90 days, built around your equipment.';
    } else if (day == null) {
      sub = today.isBefore(cfg.start)
          ? (l?.fitPlanStarts(localizedDate(cfg.start, l.localeName)) ??
              'Starts ${localizedDate(cfg.start, 'en')}')
          : (l?.fitPlanFinished ?? 'Program complete. Well done!');
    } else {
      sub = '${l?.fitPlanDayOf('${day.index + 1}', '${cfg.days}') ?? 'Day ${day.index + 1} of ${cfg.days}'}'
          ' · ${dayLine(c, day)}';
    }
    final frac = cfg == null
        ? 0.0
        : (done.length /
                (plan!.where((d) => d.kind != DayKind.rest).length).clamp(1, 9999))
            .clamp(0.0, 1.0);
    return Pressable(
      onTap: onTap,
      semanticLabel: title,
      child: Container(
        padding: const EdgeInsets.all(S.x4),
        decoration: BoxDecoration(color: p.card, borderRadius: R.rXl),
        child: Row(children: [
          Container(
            width: S.x10,
            height: S.x10,
            decoration:
                BoxDecoration(color: p.wash(C.green, strength: 1.6), shape: BoxShape.circle),
            child: Icon(day == null ? LucideIcons.calendarCheck : _kindIcon(day.kind),
                size: 20, color: p.on(C.green)),
          ),
          const SizedBox(width: S.x3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: F.head.copyWith(color: p.ink)),
              const SizedBox(height: S.x1),
              Text(sub, style: F.cap.copyWith(color: p.ink2), maxLines: 3),
              if (cfg != null) ...[
                const SizedBox(height: S.x2),
                ClipRRect(
                  borderRadius: R.rPill,
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: S.x1 + 2,
                    backgroundColor: p.card2,
                    color: p.on(C.green),
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(width: S.x2),
          Icon(LucideIcons.chevronRight, size: 18, color: p.ink3),
        ]),
      ),
    );
  }
}

/// [FitPlanCard] wired to the store, rebuilding when the program changes.
class FitPlanEntry extends StatelessWidget {
  final ActivityHost host;
  final double? weightKg;
  final DateTime? now;
  const FitPlanEntry({super.key, this.host = ActivityHost.none, this.weightKg, this.now});

  @override
  Widget build(BuildContext c) => ValueListenableBuilder<int>(
        valueListenable: FitPlanStore.revision,
        builder: (c, _, _) => FitPlanCard(
          config: FitPlanStore.config,
          done: FitPlanStore.done,
          today: now ?? DateTime.now(),
          onTap: () => Navigator.of(c).push(MaterialPageRoute<void>(
            builder: (_) => FitPlanStore.config == null
                ? FitPlanSetup(host: host, weightKg: weightKg)
                : FitPlanScreen(host: host, weightKg: weightKg),
          )),
        ),
      );
}

// ══════════════════ choice chips ══════════════════

class _Chips<T> extends StatelessWidget {
  final List<T> values;
  final bool Function(T) selected;
  final String Function(T) label;
  final ValueChanged<T> onTap;
  const _Chips(this.values, {required this.selected, required this.label, required this.onTap});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return Wrap(spacing: S.x2, runSpacing: S.x2, children: [
      for (final v in values)
        Pressable(
          onTap: () => onTap(v),
          semanticLabel: label(v),
          child: Container(
            constraints: const BoxConstraints(minHeight: S.tap),
            padding: const EdgeInsets.symmetric(horizontal: S.x4, vertical: S.x3),
            decoration: BoxDecoration(
              color: selected(v) ? p.ink : p.card,
              borderRadius: R.rPill,
            ),
            child: Text(label(v),
                style: F.body.copyWith(
                    color: selected(v) ? p.bg : p.ink,
                    fontWeight: selected(v) ? FontWeight.w700 : FontWeight.w500)),
          ),
        ),
    ]);
  }
}

// ══════════════════ setup ══════════════════

class FitPlanSetup extends StatefulWidget {
  /// The program being changed, or null for a new one.
  final FitPlanConfig? initial;

  /// Passed on to the schedule, so a workout started from it is a real session.
  final ActivityHost host;
  final double? weightKg;
  const FitPlanSetup(
      {super.key, this.initial, this.host = ActivityHost.none, this.weightKg});

  @override
  State<FitPlanSetup> createState() => _FitPlanSetupState();
}

class _FitPlanSetupState extends State<FitPlanSetup> {
  late int days = widget.initial?.days ?? 30;
  late FitGoal goal = widget.initial?.goal ?? FitGoal.general;
  late FitStyle style = widget.initial?.style ?? FitStyle.calisthenics;
  late FitLevel level = widget.initial?.level ?? FitLevel.beginner;
  late int perWeek = widget.initial?.daysPerWeek ?? 4;
  late Set<Equip> equipment = {...?widget.initial?.equipment};

  void _build() {
    final now = DateTime.now();
    FitPlanStore.save(FitPlanConfig(
      days: days,
      goal: goal,
      style: style,
      level: level,
      daysPerWeek: perWeek,
      equipment: equipment,
      start: DateTime(now.year, now.month, now.day),
    ));
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => FitPlanScreen(host: widget.host, weightKg: widget.weightKg)));
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    Widget group(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(top: S.x5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: F.label.copyWith(color: p.ink)),
            const SizedBox(height: S.x2),
            child,
          ]),
        );
    final equipChoices = style == FitStyle.gym
        ? Equip.values
        : const [
            Equip.pullUpBar,
            Equip.dipBars,
            Equip.bench,
            Equip.dumbbells,
            Equip.kettlebell,
            Equip.abWheel,
            Equip.jumpRope,
            Equip.treadmill,
            Equip.indoorBike,
          ];
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.x4),
            child: NavBar(l?.fitPlanSetupTitle ?? 'New program',
                sub: l?.fitPlanTitle ?? 'Fit program'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.x4, 0, S.x4, S.x10),
              children: [
                group(
                    l?.fitPlanLength ?? 'How long',
                    _Chips<int>(const [14, 30, 60, 90],
                        selected: (v) => v == days,
                        label: (v) => l?.fitPlanDaysN('$v') ?? '$v days',
                        onTap: (v) => setState(() => days = v))),
                group(
                    l?.fitPlanGoal ?? 'Goal',
                    _Chips<FitGoal>(FitGoal.values,
                        selected: (v) => v == goal,
                        label: (v) => switch (v) {
                              FitGoal.general => l?.fitPlanGoalGeneral ?? 'Fitter overall',
                              FitGoal.strength => l?.fitPlanGoalStrength ?? 'Stronger',
                              FitGoal.fatLoss => l?.fitPlanGoalFatLoss ?? 'Lose fat',
                            },
                        onTap: (v) => setState(() => goal = v))),
                group(
                    l?.fitPlanStyle ?? 'How you train',
                    _Chips<FitStyle>(FitStyle.values,
                        selected: (v) => v == style,
                        label: (v) => v == FitStyle.gym
                            ? (l?.fitPlanStyleGym ?? 'Gym')
                            : (l?.fitPlanStyleCali ?? 'Calisthenics'),
                        onTap: (v) => setState(() {
                              style = v;
                              equipment = {...defaultEquipment(v)};
                            }))),
                group(
                    l?.fitPlanLevel ?? 'Level',
                    _Chips<FitLevel>(FitLevel.values,
                        selected: (v) => v == level,
                        label: (v) => v == FitLevel.beginner
                            ? (l?.fitPlanLevelBeginner ?? 'Beginner')
                            : (l?.fitPlanLevelIntermediate ?? 'Intermediate'),
                        onTap: (v) => setState(() => level = v))),
                group(
                    l?.fitPlanPerWeek ?? 'Training days a week',
                    _Chips<int>(const [3, 4, 5, 6],
                        selected: (v) => v == perWeek,
                        label: (v) => '$v',
                        onTap: (v) => setState(() => perWeek = v))),
                group(
                    l?.fitPlanEquipment ?? 'Equipment you have',
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _Chips<Equip>(equipChoices,
                          selected: equipment.contains,
                          label: (v) => _equipName(l, v),
                          onTap: (v) => setState(() =>
                              equipment.contains(v) ? equipment.remove(v) : equipment.add(v))),
                      if (equipment.isEmpty) ...[
                        const SizedBox(height: S.x2),
                        Text(l?.fitPlanEquipNone ?? 'Nothing ticked: bodyweight only.',
                            style: F.cap.copyWith(color: p.ink3)),
                      ],
                    ])),
                const SizedBox(height: S.x6),
                BigButton(l?.fitPlanBuild ?? 'Make my schedule',
                    icon: LucideIcons.calendarCheck, onTap: _build),
                const SizedBox(height: S.x3),
                Text(
                  l?.fitPlanSources ??
                      'Built on the WHO 2020 and ACSM guidelines: 150 minutes or more of '
                          'cardio a week, and strength work on two or more days.',
                  style: F.cap.copyWith(color: p.ink3),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════ the schedule ══════════════════

class FitPlanScreen extends StatefulWidget {
  final ActivityHost host;
  final double? weightKg;
  final DateTime? now;
  const FitPlanScreen({super.key, this.host = ActivityHost.none, this.weightKg, this.now});

  @override
  State<FitPlanScreen> createState() => _FitPlanScreenState();
}

class _FitPlanScreenState extends State<FitPlanScreen> {
  int? _week;

  DateTime get _today => widget.now ?? DateTime.now();

  Future<void> _menu(FitPlanConfig cfg) async {
    final l = AppLocalizations.of(context);
    final p = P.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.card,
      showDragHandle: true,
      builder: (s) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(S.x4, 0, S.x4, S.x4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SetRow(LucideIcons.pencil, C.blue, l?.fitPlanEdit ?? 'Change program',
                onTap: () {
              Navigator.of(s).pop();
              Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
                  builder: (_) => FitPlanSetup(
                      initial: cfg, host: widget.host, weightKg: widget.weightKg)));
            }),
            SetRow(LucideIcons.trash2, C.red, l?.fitPlanDelete ?? 'End program',
                danger: true, onTap: () async {
              Navigator.of(s).pop();
              final ok = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  backgroundColor: p.card,
                  title: Text(l?.fitPlanDelete ?? 'End program',
                      style: F.head.copyWith(color: p.ink)),
                  content: Text(
                      l?.fitPlanDeleteBody ?? 'The schedule and your ticks are cleared.',
                      style: F.body.copyWith(color: p.ink2)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(d).pop(false),
                        child: Text(l?.actionCancel ?? 'Cancel')),
                    TextButton(
                        onPressed: () => Navigator.of(d).pop(true),
                        child: Text(l?.fitPlanDeleteYes ?? 'End it',
                            style: F.body.copyWith(color: p.on(C.red)))),
                  ],
                ),
              );
              if (ok == true && mounted) {
                FitPlanStore.clear();
                Navigator.of(context).pop();
              }
            }),
          ]),
        ),
      ),
    );
  }

  void _start(FitPlanConfig cfg, PlanDay d) {
    final a = d.kind == DayKind.strength
        ? activityByName(cfg.style == FitStyle.gym ? 'weight_training' : 'calisthenics')
        : activityByName(d.cardio!.activityKey);
    if (a == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ActivitySetup(a,
          weightKg: widget.weightKg,
          host: widget.host,
          plan: [for (final i in d.items) i.exerciseKey]),
    ));
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    return ValueListenableBuilder<int>(
      valueListenable: FitPlanStore.revision,
      builder: (c, _, _) {
        final cfg = FitPlanStore.config;
        if (cfg == null) {
          return FitPlanSetup(host: widget.host, weightKg: widget.weightKg);
        }
        final plan = buildFitPlan(cfg);
        final done = FitPlanStore.done;
        final today = planDayOn(plan, _today);
        final weeks = plan.last.week;
        final week = (_week ?? today?.week ?? 1).clamp(1, weeks);
        final training = plan.where((d) => d.kind != DayKind.rest).length;
        return Scaffold(
          backgroundColor: p.bg,
          body: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: S.x4),
                child: NavBar(
                  l?.fitPlanTitle ?? 'Fit program',
                  sub: l?.fitPlanDoneOf('${done.length}', '$training') ??
                      '${done.length} of $training workouts done',
                  trailing: Pressable(
                    semanticLabel: l?.fitPlanEdit ?? 'Change program',
                    onTap: () => _menu(cfg),
                    child: Icon(LucideIcons.ellipsis, size: 22, color: p.ink),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(S.x4, 0, S.x4, S.x10),
                  children: [
                    if (today != null) ...[
                      Text(
                          l?.fitPlanDayOf('${today.index + 1}', '${cfg.days}') ??
                              'Day ${today.index + 1} of ${cfg.days}',
                          style: F.label.copyWith(color: p.ink3)),
                      const SizedBox(height: S.x2),
                      _DayCard(
                        day: today,
                        done: done.contains(today.index),
                        onStart: today.kind == DayKind.rest ? null : () => _start(cfg, today),
                        onDone: (v) => FitPlanStore.setDone(today.index, v),
                      ),
                    ] else
                      StatusCard(
                        _today.isBefore(cfg.start)
                            ? (l?.fitPlanStarts(localizedDate(cfg.start, l.localeName)) ??
                                'Starts soon')
                            : (l?.fitPlanFinished ?? 'Program complete. Well done!'),
                        l?.fitPlanDoneOf('${done.length}', '$training') ??
                            '${done.length} of $training workouts done',
                        icon: LucideIcons.partyPopper,
                      ),
                    const SizedBox(height: S.x5),
                    SubTabs(
                      [for (var w = 1; w <= weeks; w++) l?.fitPlanWeekN('$w') ?? 'Week $w'],
                      week - 1,
                      (i) => setState(() => _week = i + 1),
                    ),
                    const SizedBox(height: S.x3),
                    if (plan.firstWhere((d) => d.week == week).deload)
                      Padding(
                        padding: const EdgeInsets.only(bottom: S.x3),
                        child: Text(
                            l?.fitPlanDeload ??
                                'A lighter week: fewer sets, so the body catches up and the next block goes further.',
                            style: F.cap.copyWith(color: p.ink2)),
                      ),
                    for (final d in plan.where((d) => d.week == week)) ...[
                      _DayRow(
                        day: d,
                        done: done.contains(d.index),
                        today: _sameDay(d.date, _today),
                        onTap: () => showModalBottomSheet<void>(
                          context: c,
                          isScrollControlled: true,
                          backgroundColor: p.bg,
                          showDragHandle: true,
                          builder: (s) => SafeArea(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(S.x4, 0, S.x4, S.x4),
                              child: _DayCard(
                                day: d,
                                done: done.contains(d.index),
                                onStart: d.kind == DayKind.rest
                                    ? null
                                    : () {
                                        Navigator.of(s).pop();
                                        _start(cfg, d);
                                      },
                                onDone: (v) {
                                  FitPlanStore.setDone(d.index, v);
                                  Navigator.of(s).pop();
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: S.x2),
                    ],
                  ],
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// One day in the week list.
class _DayRow extends StatelessWidget {
  final PlanDay day;
  final bool done, today;
  final VoidCallback onTap;
  const _DayRow({required this.day, required this.done, required this.today, required this.onTap});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final date = localizedDate(day.date, l?.localeName ?? 'en', pattern: 'EEE d MMM');
    return Pressable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: S.tap + S.x2),
        padding: const EdgeInsets.symmetric(horizontal: S.x4, vertical: S.x3),
        decoration: BoxDecoration(
          color: today ? p.wash(C.green) : p.card,
          borderRadius: R.rLg,
        ),
        child: Row(children: [
          Container(
            width: S.x8,
            height: S.x8,
            decoration: BoxDecoration(color: p.wash(_kindTint(day.kind)), shape: BoxShape.circle),
            child: Icon(_kindIcon(day.kind), size: 16, color: p.on(_kindTint(day.kind))),
          ),
          const SizedBox(width: S.x3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dayLine(c, day), style: F.body.copyWith(color: p.ink)),
              Text(date, style: F.cap.copyWith(color: p.ink3)),
            ]),
          ),
          if (done) Icon(LucideIcons.circleCheck, size: 20, color: p.on(C.green)),
        ]),
      ),
    );
  }
}

/// A day in full: the exercises with their sets, or the cardio, or rest.
class _DayCard extends StatelessWidget {
  final PlanDay day;
  final bool done;
  final VoidCallback? onStart;
  final ValueChanged<bool> onDone;
  const _DayCard({required this.day, required this.done, required this.onStart, required this.onDone});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final lang = l?.localeName ?? 'en';
    String cardioLine(PlanCardio x) {
      final a = _activity(c, x.activityKey);
      return x.intervals
          ? (l?.fitPlanCardioIntervals(a, '${x.minutes}') ??
              '$a intervals, ${x.minutes} min: 1 min hard, 1 min easy')
          : (l?.fitPlanCardioSteady(a, '${x.minutes}') ??
              '$a, ${x.minutes} min at an easy, steady pace: you can still talk');
    }

    return Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_kindIcon(day.kind), size: 18, color: p.on(_kindTint(day.kind))),
          const SizedBox(width: S.x2),
          Expanded(child: Text(dayLine(c, day), style: F.head.copyWith(color: p.ink))),
        ]),
        const SizedBox(height: S.x3),
        if (day.kind == DayKind.strength) ...[
          Text(l?.fitPlanWarmup ?? 'Warm up for 5 minutes first: easy cardio and a light set.',
              style: F.cap.copyWith(color: p.ink3)),
          const SizedBox(height: S.x2),
          for (final i in day.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: S.x2),
              child: Row(children: [
                Expanded(
                  child: Text(exerciseByKey(i.exerciseKey)?.labelFor(lang) ?? i.exerciseKey,
                      style: F.body.copyWith(color: p.ink)),
                ),
                const SizedBox(width: S.x2),
                Text(
                  i.seconds != null
                      ? (l?.fitPlanSetsSeconds('${i.sets}', '${i.seconds}') ??
                          '${i.sets} × ${i.seconds} s')
                      : (l?.fitPlanSetsReps('${i.sets}', '${i.reps}') ?? '${i.sets} × ${i.reps}'),
                  style: F.body.copyWith(color: p.ink, fontWeight: FontWeight.w700),
                ),
              ]),
            ),
          Text(
              l?.fitPlanRestBetween('${day.items.isEmpty ? 0 : day.items.first.restSec}') ??
                  'Rest ${day.items.isEmpty ? 0 : day.items.first.restSec} s between sets',
              style: F.cap.copyWith(color: p.ink3)),
          if (day.finisher case final f?) ...[
            const SizedBox(height: S.x3),
            Text(l?.fitPlanFinisher(cardioLine(f)) ?? 'Then: ${cardioLine(f)}',
                style: F.body.copyWith(color: p.ink2)),
          ],
        ],
        if (day.cardio case final x?) Text(cardioLine(x), style: F.body.copyWith(color: p.ink2)),
        if (day.kind == DayKind.rest)
          Text(l?.fitPlanRestBody ?? 'Rest. A walk or some stretching is plenty.',
              style: F.body.copyWith(color: p.ink2)),
        if (day.deload) ...[
          const SizedBox(height: S.x2),
          Pill(l?.fitPlanDeloadPill ?? 'Lighter week', C.blue, icon: LucideIcons.feather),
        ],
        const SizedBox(height: S.x4),
        if (onStart != null) ...[
          BigButton(l?.fitPlanStart ?? 'Start this workout',
              icon: LucideIcons.play, onTap: onStart),
          const SizedBox(height: S.x2),
          BigButton(
              done ? (l?.fitPlanDone ?? 'Done') : (l?.fitPlanMarkDone ?? 'Mark done'),
              icon: done ? LucideIcons.circleCheck : LucideIcons.circle,
              color: C.green,
              soft: true,
              onTap: () => onDone(!done)),
        ],
      ]),
    );
  }
}
