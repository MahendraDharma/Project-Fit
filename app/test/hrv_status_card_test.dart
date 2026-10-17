// HRV status card — the three states on the Health tab.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/l10n/app_localizations.dart';
import 'package:projectfit/ui2/screens/hrv_status_card.dart';
import 'package:projectfit/ui2/ui2.dart';
import 'package:projectfit_analytics/onehz.dart' show hrvStatus;

Widget _harness(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

List<double?> _nights(double base, double week, {int weekNights = 7}) => [
      for (var i = 0; i < 60; i++) base * (i.isEven ? 1.1 : 0.9),
      for (var i = 0; i < 7; i++) i < 7 - weekNights ? null : week,
    ];

void main() {
  testWidgets('a week at baseline reads inside the range, with numbers',
      (t) async {
    await t.pumpWidget(_harness(HrvStatusCard(hrvStatus(_nights(50, 50)))));
    expect(find.text('HRV status'), findsOneWidget);
    expect(find.text('Inside your range'), findsOneWidget);
    expect(find.textContaining('7-night average 50 ms'), findsOneWidget);
  });

  testWidgets('a low week reads below the range', (t) async {
    await t.pumpWidget(_harness(HrvStatusCard(hrvStatus(_nights(50, 38)))));
    expect(find.text('Below your range'), findsOneWidget);
  });

  testWidgets('too few nights says how many more, not a status', (t) async {
    await t.pumpWidget(
        _harness(HrvStatusCard(hrvStatus(_nights(50, 50, weekNights: 2)))));
    expect(find.text('HRV status is still learning'), findsOneWidget);
    expect(find.text('Need 2 more nights'), findsOneWidget);
    expect(find.text('Inside your range'), findsNothing);
  });
}
