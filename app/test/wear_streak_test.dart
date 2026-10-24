import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/ui2/screens/screens.dart';
import 'package:projectfit/ui2/ui2.dart';

Map<String, double> _worn(List<int> octDays, {double min = 600}) => {
      for (final d in octDays) '2026-10-${d.toString().padLeft(2, '0')}': min,
    };

void main() {
  final sat = DateTime(2026, 10, 24, 20);

  test('a run ending today counts today', () {
    final s = WearStreak.from(_worn([20, 21, 22, 23, 24]), sat);
    expect(s.current, 5);
    expect(s.startedOn, DateTime(2026, 10, 20));
  });

  test('today not worn yet: the run ending yesterday is still alive', () {
    final s = WearStreak.from(_worn([22, 23]), sat);
    expect(s.current, 2);
  });

  test('a missed day breaks the run; the best run stays', () {
    final s = WearStreak.from({..._worn([10, 11, 12, 13]), ..._worn([22, 23, 24])}, sat);
    expect(s.current, 3);
    expect(s.best, 4);
  });

  test('under four hours of wear is not a worn day', () {
    final s = WearStreak.from({..._worn([23]), ..._worn([24], min: 200)}, sat);
    expect(s.current, 1);
    expect(s.week, [false, false, false, false, true, false, null]);
  });

  test('milestones either side', () {
    expect(WearStreak.from(_worn([for (var d = 13; d <= 24; d++) d]), sat).milestones, (10, 25));
  });

  testWidgets('the screen shows the run, the best and the next milestone', (t) async {
    t.view.physicalSize = const Size(390, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: StreakScreen(streak: WearStreak.from(_worn([for (var d = 13; d <= 24; d++) d]), sat))));
    await t.pump();
    expect(find.text('12'), findsWidgets);
    expect(find.text('13 more days to the next milestone'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
