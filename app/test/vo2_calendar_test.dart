import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/ui2/screens/screens.dart';
import 'package:projectfit/ui2/ui2.dart';

Future<void> _pump(WidgetTester t, Widget w, {double scale = 1}) async {
  t.view.physicalSize = const Size(390, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.dark),
      home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale), size: const Size(390, 2400)),
          child: w)));
  await t.pump();
}

void main() {
  group('VO₂ max ratings (Cooper Institute, as Garmin prints them)', () {
    test('men 20–29: 41.0 is Poor, 41.7 is Fair, 55.4 is Superior', () {
      final cuts = vo2Cuts('m', 27)!;
      expect(vo2Tier(41.0, cuts), 0);
      expect(vo2Tier(41.7, cuts), 1);
      expect(vo2Tier(55.4, cuts), 4);
    });
    test('the table ends clamp: 18 reads 20–29, 85 reads 70–79', () {
      expect(vo2Cuts('female', 18), kVo2Norms['f']![0]);
      expect(vo2Cuts('M', 85), kVo2Norms['m']![5]);
    });
    test('no rating without both age and sex', () {
      expect(vo2Cuts(null, 30), isNull);
      expect(vo2Cuts('m', null), isNull);
    });
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('VO₂ max screen at ${scale}x: value, rating, cohort, source', (t) async {
      await _pump(
          t,
          Vo2MaxScreen(
              data: Vo2Data(sex: 'm', age: 27, points: [
            (at: DateTime(2026, 10, 22), value: 41.0, source: 'Connect'),
            (at: DateTime(2026, 10, 24), value: 42.0, source: 'Connect'),
          ])),
          scale: scale);
      expect(find.text('42.0'), findsOneWidget);
      expect(find.text('Fair'), findsOneWidget);
      expect(find.text('Standardised for men aged 20–29'), findsOneWidget);
      expect(find.text('Data from Connect'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('no VO₂ max: says where it comes from, draws no rating', (t) async {
    await _pump(t, const Vo2MaxScreen(data: Vo2Data()));
    expect(find.text('No VO₂ max yet'), findsOneWidget);
    expect(find.text('Fair'), findsNothing);
  });

  testWidgets('calendar: 31 days of October, empty days stay empty', (t) async {
    await _pump(
        t,
        MonthCalendarScreen(month: DateTime(2026, 10), data: const {
          CalendarMetric.recovery: {'2026-10-23': (frac: .9, color: C.green)},
        }));
    expect(find.text('31'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
