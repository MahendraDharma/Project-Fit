import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/ui2/screens/screens.dart';
import 'package:projectfit/ui2/ui2.dart';

int _t(int day, int h, [int m = 0]) => DateTime(2026, 10, day, h, m).millisecondsSinceEpoch ~/ 1000;

final _today = <BbPoint>[
  (t: _t(24, 0), v: 25),
  (t: _t(24, 7), v: 82),
  (t: _t(24, 12), v: 70),
  (t: _t(24, 14), v: 74),
  (t: _t(24, 22), v: 52),
];

void main() {
  test('charged and drained are the rises and falls of Garmin\'s own samples', () {
    final d = BodyBatteryData(day: '2026-10-24', today: _today);
    expect(d.chargedDrained, (57 + 4, 12 + 22));
    expect(d.peak!.v, 82);
    expect(d.latest, 52);
  });

  test('usual at this time needs three earlier days near the same clock time', () {
    final two = BodyBatteryData(day: '2026-10-24', today: _today, before: {
      '2026-10-22': [(t: _t(22, 22, 10), v: 30)],
      '2026-10-23': [(t: _t(23, 21, 50), v: 34)],
    });
    expect(two.usualNow, isNull);
    final three = BodyBatteryData(day: '2026-10-24', today: _today, before: {
      ...two.before,
      '2026-10-21': [(t: _t(21, 22), v: 32), (t: _t(21, 9), v: 90)],
      '2026-10-20': [(t: _t(20, 9), v: 99)], // nothing within 20 min of 22:00
    });
    expect(three.usualNow, closeTo(32, 1e-9));
  });

  testWidgets('the screen names Garmin and does not claim the number', (t) async {
    t.view.physicalSize = const Size(390, 2000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: BodyBatteryScreen(data: BodyBatteryData(day: '2026-10-24', today: _today))));
    await t.pump();
    expect(find.text('52'), findsOneWidget);
    expect(find.text('+61'), findsOneWidget);
    expect(find.text('−34'), findsOneWidget);
    expect(find.text('Data from Garmin'), findsOneWidget);
    expect(find.textContaining('ProjectFit does not compute one'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('no samples: says where it comes from', (t) async {
    await t.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: const BodyBatteryScreen(data: BodyBatteryData(day: '2026-10-24'))));
    await t.pump();
    expect(find.text('No Body Battery for this day'), findsOneWidget);
  });
}
