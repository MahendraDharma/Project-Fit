// The coach's quick answers: worked out on the phone from stored figures, no
// model. Same data, same words — and too little data says so instead of
// guessing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:projectfit/coach/coach_config.dart';
import 'package:projectfit/data/local_repository.dart';
import 'package:projectfit/state/app_state.dart';
import 'package:projectfit/state/prefs.dart';
import 'package:projectfit/ui2/screens/coach.dart';
import 'package:projectfit/ui2/screens/coach_quick.dart';
import 'package:projectfit/ui2/ui2.dart';

final _today = DateTime(2026, 11, 3); // a Tuesday

List<double?> _flat(int n, double v) => List<double?>.filled(n, v);

/// A dense series whose last [recent] days sit at [now] and the rest at [before].
List<double?> _step(int n, int recent, double before, double now) =>
    [for (var i = 0; i < n; i++) i >= n - recent ? now : before];

void main() {
  group('recovery', () {
    test('a high morning against a lower usual', () {
      final days = [..._flat(29, 55), 82.0];
      final r = quickRecovery(null, days, today: _today);
      expect(r.text, contains('82%'));
      expect(r.text, contains('27 points above your usual 55'));
      expect(r.text, contains('harder workout'));
      expect(r.mood, MochiMood.happy);
      expect(r.chart?.series.single.values.length, 14);
      expect(r.chart?.xLabels.last, '3');
    });

    test('a low one says to go easy, and a missing one says why', () {
      final low = quickRecovery(null, [..._flat(29, 60), 20.0], today: _today);
      expect(low.text, contains('below your usual'));
      expect(low.mood, MochiMood.sleepy);
      final none = quickRecovery(null, [..._flat(29, 60), null], today: _today);
      expect(none.chart, isNull);
      expect(none.mood, MochiMood.think);
    });

    test('without four earlier days there is no "usual" to compare to', () {
      final r = quickRecovery(null, [null, null, 50, 50, 50.0], today: _today);
      expect(r.text, isNot(contains('usual')));
    });
  });

  group('sleep', () {
    test('a short week against the need, the week before and its extremes', () {
      final days = <double?>[
        ..._flat(7, 480), // the week before: 8 h
        420, 400, 360, 410, null, 390, 300, // this week, one night missing
      ];
      final r = quickSleep(null, days, today: _today, needMin: 480);
      expect(r.text, contains('over your last 6 nights'));
      expect(r.text, contains('less than the 8h 00m your body needs'));
      expect(r.text, contains('less than the week before'));
      expect(r.text, contains('Longest night: 7h 00m (Wednesday)'));
      expect(r.text, contains('Shortest: 5h 00m (Tuesday)'));
      expect(r.mood, MochiMood.sleepy);
      expect(r.chart?.xLabels, ['Wed', 'Thu', 'Fri', 'Sat', 'Sun', 'Mon', 'Tue']);
      expect(r.chart?.series.single.values.last, 5.0);
    });

    test('two nights are not a week', () {
      final r = quickSleep(null, [null, null, null, null, null, 420, 400.0],
          today: _today);
      expect(r.text, contains('not enough data'));
      expect(r.chart, isNull);
    });
  });

  test('bedtime quotes the time and the need, or asks for more nights', () {
    final r = quickBedtime(null, bedtimeMin: 22 * 60 + 30, needMin: 470);
    expect(r.text, contains('7h 50m'));
    expect(r.text, anyOf(contains('22:30'), contains('10:30')));
    expect(quickBedtime(null).mood, MochiMood.think);
  });

  group('trends', () {
    test('HRV falling is a warning; rising is good; flat is steady', () {
      final down = quickHrv(null, _step(30, 7, 60, 48), today: _today);
      expect(down.text, contains('averages 48 ms, against 60 ms'));
      expect(down.text, contains('going down'));
      expect(down.mood, MochiMood.alert);
      expect(quickHrv(null, _step(30, 7, 60, 70), today: _today).mood, MochiMood.happy);
      expect(quickHrv(null, _step(30, 7, 60, 61), today: _today).text,
          contains('steady'));
    });

    test('resting heart rate reads the other way round', () {
      final up = quickRestingHr(null, _step(30, 7, 52, 58), today: _today);
      expect(up.text, contains('higher than usual'));
      expect(up.mood, MochiMood.alert);
      final down = quickRestingHr(null, _step(30, 7, 58, 52), today: _today);
      expect(down.mood, MochiMood.happy);
      expect(quickRestingHr(null, _step(30, 7, 55, 56), today: _today).text,
          contains('steady'));
    });

    test('too few nights give no trend', () {
      expect(quickHrv(null, [..._flat(27, 60).map((_) => null), 50, 50, 50],
              today: _today)
          .text, contains('not enough data'));
    });
  });

  test('steps: the average, the goal days and the best day', () {
    final r = quickSteps(null, [6000, 9000, 12000, 4000, 8000, 10000, 7000.0],
        today: _today, goal: 8000);
    expect(r.text, contains('8,000 steps a day'));
    expect(r.text, contains('on 4 of 7 days'));
    expect(r.text, contains('Your best day was Friday, with 12,000 steps'));
    expect(r.mood, MochiMood.happy);
  });

  testWidgets('with no model set up, the coach still answers', (t) async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.ensureLoaded();
    final app = AppState.forTesting();
    addTearDown(app.dispose);
    app.repo = _Repo();
    final cfg = CoachConfig();
    addTearDown(cfg.dispose);
    await t.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: app),
          ChangeNotifierProvider<CoachConfig>.value(value: cfg),
        ],
        child: const CoachScreen(),
      ),
    ));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Quick answers'), findsWidgets);
    expect(find.text('Set up AI chat'), findsOneWidget);
    // No composer: there is no model to type to.
    expect(find.byType(TextField), findsNothing);

    await t.tap(find.text('How recovered am I today?'));
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('Recovery today is 75%', findRichText: true),
        findsOneWidget);
    // The questions stay to hand under the answer.
    expect(find.text('How was my sleep this week?'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });
}

class _Repo extends LocalRepository {
  @override
  Future<Map<String, dynamic>> getChart(String metric,
      {int? from, int? to, Set<String> signals = const {}}) async {
    final now = DateTime.now();
    final noon = DateTime(now.year, now.month, now.day, 12);
    return {
      'points': [
        for (var i = 0; i < 10; i++)
          {
            't': noon.subtract(Duration(days: i)).millisecondsSinceEpoch ~/ 1000,
            'v': i == 0 ? 75 : 60,
          },
      ],
    };
  }
}
