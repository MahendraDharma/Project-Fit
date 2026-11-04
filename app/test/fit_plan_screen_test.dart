// The fit program on screen: make one, see today's day, tick it, and start it
// as a real session that opens with the day's exercises.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:projectfit/state/prefs.dart';
import 'package:projectfit/ui2/activity/setup.dart';
import 'package:projectfit/ui2/program/fit_plan.dart';
import 'package:projectfit/ui2/program/fit_plan_screen.dart';
import 'package:projectfit/ui2/ui2.dart';

Widget _host(Widget w) => MaterialApp(theme: buildTheme(Brightness.light), home: w);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.ensureLoaded();
    FitPlanStore.clear();
  });

  testWidgets('make a program, then today shows with its exercises', (t) async {
    t.view.physicalSize = const Size(1170, 6000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(const FitPlanEntry()));
    expect(find.text('Fit program'), findsOneWidget);
    await t.tap(find.text('Fit program'));
    await t.pumpAndSettle();

    // Setup: calisthenics with a pull-up bar, 30 days.
    expect(find.text('New program'), findsOneWidget);
    await t.tap(find.text('Pull-up bar'));
    await t.pump();
    await t.tap(find.text('Make my schedule'));
    await t.pumpAndSettle();

    final cfg = FitPlanStore.config!;
    expect(cfg.days, 30);
    expect(cfg.style, FitStyle.calisthenics);
    expect(cfg.equipment, {Equip.pullUpBar});
    expect(find.text('Day 1 of 30'), findsOneWidget);
    // Day 1 is a strength day: full body, with its sets.
    expect(find.textContaining('Full body A'), findsWidgets);
    expect(find.text('Start this workout'), findsOneWidget);

    await t.tap(find.text('Mark done'));
    await t.pumpAndSettle();
    expect(FitPlanStore.done, {0});
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('1 of ${buildFitPlan(cfg).where((d) => d.kind != DayKind.rest).length} workouts done'),
        findsOneWidget);
  });

  testWidgets("starting today's workout opens the session setup with the plan",
      (t) async {
    t.view.physicalSize = const Size(1170, 6000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final now = DateTime.now();
    FitPlanStore.save(FitPlanConfig(
        days: 14,
        goal: FitGoal.general,
        style: FitStyle.gym,
        level: FitLevel.beginner,
        daysPerWeek: 3,
        equipment: gymEquipment,
        start: DateTime(now.year, now.month, now.day)));
    await t.pumpWidget(_host(const FitPlanScreen()));
    await t.pumpAndSettle();
    await t.tap(find.text('Start this workout'));
    await t.pumpAndSettle();
    final setup = t.widget<ActivitySetup>(find.byType(ActivitySetup));
    expect(setup.a.typeKey, 'weight_training');
    expect(setup.plan, isNotEmpty);
    expect(setup.plan.first, 'back_squat');
  });

  testWidgets('every week of the program has a tab, and a rest day says rest',
      (t) async {
    t.view.physicalSize = const Size(1170, 6000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final now = DateTime.now();
    FitPlanStore.save(FitPlanConfig(
        days: 30,
        goal: FitGoal.fatLoss,
        style: FitStyle.calisthenics,
        level: FitLevel.intermediate,
        daysPerWeek: 3,
        equipment: const {},
        start: DateTime(now.year, now.month, now.day)));
    await t.pumpWidget(_host(const FitPlanScreen()));
    await t.pumpAndSettle();
    for (var w = 1; w <= 5; w++) {
      expect(find.text('Week $w'), findsOneWidget);
    }
    expect(find.text('Rest day'), findsWidgets);
    await t.ensureVisible(find.text('Week 4'));
    await t.pumpAndSettle();
    await t.tap(find.text('Week 4'));
    await t.pumpAndSettle();
    expect(find.textContaining('A lighter week'), findsOneWidget);
  });
}
