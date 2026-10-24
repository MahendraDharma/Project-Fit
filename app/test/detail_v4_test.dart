import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/models/metric.dart';
import 'package:projectfit/ui2/screens/screens.dart';
import 'package:projectfit/ui2/ui2.dart';

Future<void> _pump(WidgetTester t, Widget w) async {
  await t.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.dark),
      home: Scaffold(body: ListView(children: [w]))));
  await t.pump();
}

void main() {
  testWidgets('sleep top: share of the need, the two durations, the coaching line', (t) async {
    await _pump(
        t,
        const DetailTop(DetailKind.sleep,
            data: DetailTopData(
                HomeData(dayId: '2026-10-17', sleepMin: Metric(value: 507)),
                HomeVitals(sleepMin: 507, efficiency: .91, needMin: 660, debtMin: 153))));
    expect(find.text('77'), findsOneWidget);
    expect(find.text('9h 17m'), findsOneWidget); // in bed = asleep / efficiency
    expect(find.text('8h 27m'), findsOneWidget);
    expect(find.textContaining('of the 11h 00m you needed'), findsOneWidget);
    expect(find.textContaining('Sleep debt'), findsOneWidget);
  });

  testWidgets('recovery top while calibrating: nights, never a score', (t) async {
    await _pump(
        t,
        const DetailTop(DetailKind.recovery,
            data: DetailTopData(HomeData(dayId: '2026-10-17'),
                HomeVitals(hrv: 90, rhr: 51, recoveryHave: 3, recoveryNeed: 7))));
    expect(find.text('3/7'), findsOneWidget);
    expect(find.textContaining('4 more nights'), findsOneWidget);
  });

  testWidgets('a day from another device is named, and never placed in the range', (t) async {
    final pts = <TrendPoint>[
      (day: '2026-10-15', value: 50, source: null),
      (day: '2026-10-16', value: 58, source: 'Connect'),
    ];
    await _pump(t, MetricTrendCard(TrendRow('resting_hr', pts, const UsualRange(48, 55))));
    expect(find.text('Data from Connect'), findsOneWidget);
    expect(find.text('From another device'), findsOneWidget);
    expect(find.text('Above normal'), findsNothing);
  });

  testWidgets('the band\'s own day is placed against the usual range', (t) async {
    final pts = <TrendPoint>[(day: '2026-10-16', value: 58, source: null)];
    await _pump(t, MetricTrendCard(TrendRow('resting_hr', pts, const UsualRange(48, 55))));
    expect(find.text('Above normal'), findsOneWidget);
    expect(find.textContaining('Data from'), findsNothing);
  });
}
