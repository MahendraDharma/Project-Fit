import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/ui2/screens/screens.dart';
import 'package:projectfit/ui2/ui2.dart';

int _t(int h, [int m = 0]) => DateTime(2026, 10, 24, h, m).millisecondsSinceEpoch ~/ 1000;

void main() {
  test('Garmin\'s bands: 25 rest, 26 low, 51 medium, 76 high', () {
    expect([25, 26, 50, 51, 75, 76].map(stressBand), [0, 1, 1, 2, 2, 3]);
  });

  test('a sample holds until the next, five minutes at most', () {
    final d = GarminStressData(day: '2026-10-24', today: [
      (t: _t(9), v: 10),
      (t: _t(9, 3), v: 80),
      (t: _t(11), v: 30), // an hour later: only five minutes of high
    ]);
    expect(d.bandSeconds, [180, 180, 0, 300]);
  });

  testWidgets('the screen names Garmin and compares with earlier days', (t) async {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: GarminStressScreen(
            data: GarminStressData(day: '2026-10-24', today: [
          (t: _t(9), v: 18),
          (t: _t(9, 3), v: 18),
        ], dailyMeans: const {
          '2026-10-24': 18,
          '2026-10-21': 30,
          '2026-10-22': 30,
          '2026-10-23': 30,
        }))));
    await t.pump();
    expect(find.text('18'), findsWidgets); // the gauge and the daily-average card
    expect(find.textContaining('12 points lower than usual'), findsOneWidget);
    expect(find.text('Data from Garmin'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
