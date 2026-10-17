// Monthly report — the 60-day split and the screen's three row states.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/l10n/app_localizations.dart';
import 'package:projectfit/ui2/screens/monthly_report.dart';
import 'package:projectfit/ui2/ui2.dart';

Widget _harness(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTheme(Brightness.light),
      home: child,
    );

List<double?> _sixty(double prev, double cur, {double wobble = 2}) => [
      for (var i = 0; i < 30; i++) prev + (i.isEven ? wobble : -wobble),
      for (var i = 0; i < 30; i++) cur + (i.isEven ? wobble : -wobble),
    ];

void main() {
  test('the older 30 days are the reference, the newer 30 the current month', () {
    final r = monthlyRow('hrv', _sixty(50, 56));
    expect(r.change!.previousMean, closeTo(50, 1e-9));
    expect(r.change!.currentMean, closeTo(56, 1e-9));
    expect(r.change!.direction, 'up');
  });

  test('a thin month has no comparison, only its day counts', () {
    final w = <double?>[..._sixty(50, 50).sublist(0, 30),
      ...List<double?>.filled(25, null), 50, 50, 50, 50, 50];
    final r = monthlyRow('hrv', w);
    expect(r.change, isNull);
    expect(r.currentDays, 5);
    expect(r.previousDays, 30);
  });

  testWidgets('rows show the month, the change direction, or the shortfall',
      (t) async {
    await t.pumpWidget(_harness(MonthlyReportScreen(rows: [
      monthlyRow('hrv', _sixty(50, 56)),
      monthlyRow('resting_hr', _sixty(55, 55.1)),
      monthlyRow('sleep',
          <double?>[...List<double?>.filled(55, null), 400, 410, 420, 430, 440]),
    ])));
    await t.pumpAndSettle();
    expect(find.text('Your month'), findsOneWidget);
    expect(find.text('56.0 ms'), findsOneWidget);
    Finder arrow(String d) =>
        find.byWidgetPredicate((w) => w is Icon && w.semanticLabel == d);
    expect(arrow('up'), findsOneWidget);
    expect(arrow('steady'), findsOneWidget);
    expect(find.text('Not enough days yet'), findsOneWidget);
    expect(find.text('0 of 10 measured days in the thinner month'), findsOneWidget);
  });
}
