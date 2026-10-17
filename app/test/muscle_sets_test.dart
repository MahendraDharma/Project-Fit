// Sets per muscle — catalogue mapping and the workout-tab card.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/l10n/app_localizations.dart';
import 'package:projectfit/ui2/activity/muscle_sets.dart';
import 'package:projectfit/ui2/activity/summary.dart';
import 'package:projectfit/ui2/ui2.dart';
import 'package:projectfit_analytics/onehz.dart' show muscleVolume;

Widget _harness(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  final at = DateTime(2026, 10, 1);

  test('catalogue muscles are resolved; an unknown exercise keeps its sets', () {
    final inputs = strengthSetInputs(StrengthLog([
      LoggedSet('bench_press', 8, loadKg: 60, rpe: 8, at: at),
      LoggedSet('not_in_catalogue', 10, at: at),
    ]));
    expect(inputs[0].primaryMuscles, ['chest', 'triceps', 'shoulders']);
    expect(inputs[0].loadKg, 60);
    expect(inputs[0].rpe, 8);
    expect(inputs[1].primaryMuscles, isEmpty);
    expect(muscleVolume(inputs).value!.unmappedSets, 1);
  });

  testWidgets('the card lists muscles, largest first, with hard sets when rated',
      (tester) async {
    final v = muscleVolume(strengthSetInputs(StrengthLog([
      for (var i = 0; i < 3; i++)
        LoggedSet('bench_press', 8, loadKg: 60, rpe: i == 0 ? 8 : 6, at: at),
    ]))).value!;
    await tester.pumpWidget(_harness(MuscleSetsCard(v)));
    expect(find.text('Sets per muscle, last 7 days'), findsOneWidget);
    expect(find.text('chest'), findsOneWidget);
    expect(find.text('3 · 1'), findsNWidgets(3)); // 3 sets, 1 hard, per muscle
    expect(find.textContaining('RPE 7 or more'), findsOneWidget);
  });

  testWidgets('without any RPE the card shows sets only and says why',
      (tester) async {
    final v = muscleVolume(strengthSetInputs(StrengthLog([
      LoggedSet('bench_press', 8, loadKg: 60, at: at),
    ]))).value!;
    await tester.pumpWidget(_harness(MuscleSetsCard(v)));
    expect(find.text('1'), findsNWidgets(3));
    expect(find.textContaining('Rate sets with RPE'), findsOneWidget);
  });
}
