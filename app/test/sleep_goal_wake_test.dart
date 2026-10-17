// Sleep-goal wake: the pure decision, tonight's rest time, the stored flag,
// and the alarm-screen row.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:projectfit/data/db.dart';
import 'package:projectfit/state/alarm_schedule.dart';
import 'package:projectfit/state/smart_wake.dart';
import 'package:projectfit/ui2/profile/alarm.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sleepGoalReached', () {
    test('fires only once rest reaches the learned need', () {
      expect(sleepGoalReached(restSec: 7 * 3600, needSec: 7 * 3600), isTrue);
      expect(sleepGoalReached(restSec: 7 * 3600 - 1, needSec: 7 * 3600),
          isFalse);
    });
    test('unknown rest or an unlearned need never fires', () {
      expect(sleepGoalReached(restSec: null, needSec: 7 * 3600), isFalse);
      expect(sleepGoalReached(restSec: 9 * 3600, needSec: null), isFalse);
      expect(sleepGoalReached(restSec: 9 * 3600, needSec: 0), isFalse);
    });
  });

  group('schedule entry', () {
    test('the flag round-trips through a row and copyWith', () {
      final e = AlarmScheduleEntry.fromRow({
        'weekday': 2, 'hour': 7, 'minute': 0, 'enabled': 1,
        'smart_window_minutes': 30, 'sleep_goal': 1,
      });
      expect(e.sleepGoal, isTrue);
      expect(e.copyWith(sleepGoal: false).sleepGoal, isFalse);
      expect(e.copyWith(hour: 6).sleepGoal, isTrue);
    });
    test('a row from before the column existed reads as off', () {
      final e = AlarmScheduleEntry.fromRow(
          {'weekday': 0, 'hour': 7, 'minute': 0, 'enabled': 1});
      expect(e.sleepGoal, isFalse);
    });
    test('the armed window carries the flag of its weekday', () {
      final end = DateTime(2026, 10, 20, 7); // a Tuesday
      final schedule = fillDefaultAlarmSchedule([
        AlarmScheduleEntry(
            weekday: end.weekday - 1, hour: 7, minute: 0,
            smartWindowMinutes: 30, sleepGoal: true),
      ]);
      final w = armedSmartWakeWindow(
          epoch: end.millisecondsSinceEpoch ~/ 1000, schedule: schedule)!;
      expect(w.sleepGoal, isTrue);
      expect(w.minutes, 30);
    });
  });

  group('restSecondsSoFar', () {
    // Moving wrist: the z-angle swings every second. Still wrist: constant.
    List<({int recTs, SmartWakeSample s})> night(
        {required int movingSec, required int stillSec}) {
      final out = <({int recTs, SmartWakeSample s})>[];
      var t = 1_760_000_000;
      // A wrist that keeps turning: the arm angle sweeps steadily, far faster
      // than the 5 degree rest threshold, and survives the 5 s median.
      for (var i = 0; i < movingSec; i++, t++) {
        final a = i * 0.25;
        out.add((recTs: t, s: SmartWakeSample(70, math.sin(a), 0, math.cos(a))));
      }
      for (var i = 0; i < stillSec; i++, t++) {
        out.add((recTs: t, s: const SmartWakeSample(55, 0.1, 0.0, 0.99)));
      }
      return out;
    }

    test('no samples is unknown', () {
      expect(restSecondsSoFar(const []), isNull);
    });

    test('counts the still night, not the evening before it', () {
      final rest = restSecondsSoFar(night(movingSec: 3600, stillSec: 6 * 3600))!;
      // The last few minutes cannot be certified yet: runs behind, never ahead.
      expect(rest, lessThanOrEqualTo(6 * 3600));
      expect(rest, greaterThan(6 * 3600 - 15 * 60));
    });
  });

  group('database', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });
    tearDownAll(() async {
      await LocalDb.close();
      await databaseFactory.deleteDatabase(p.join(
          await databaseFactory.getDatabasesPath(), 'projectfit_sleep_goal_test.db'));
    });

    test('the sleep_goal flag is stored per weekday', () async {
      const name = 'projectfit_sleep_goal_test.db';
      await databaseFactory.deleteDatabase(
          p.join(await databaseFactory.getDatabasesPath(), name));
      await LocalDb.close();
      LocalDb.lastRebuild = null;
      LocalDb.dbName = name;
      await LocalDb.instance;
      await LocalDb.setAlarmScheduleDay(
          weekday: 1, hour: 6, minute: 45, enabled: true,
          smartWindowMinutes: 30, sleepGoal: true);
      await LocalDb.setAlarmScheduleDay(
          weekday: 2, hour: 6, minute: 45, enabled: true);
      final rows = await LocalDb.alarmScheduleRows();
      expect(rows.firstWhere((r) => r['weekday'] == 1)['sleep_goal'], 1);
      expect(rows.firstWhere((r) => r['weekday'] == 2)['sleep_goal'], 0);
    });
  });

  group('alarm screen', () {
    Widget view(List<AlarmScheduleEntry> entries,
            {Future<void> Function(int, bool)? onSetSleepGoal}) =>
        MaterialApp(
            home: AlarmScreenView(
                connected: true,
                schedule: fillDefaultAlarmSchedule(entries),
                onSetSleepGoal: onSetSleepGoal));

    testWidgets('the row appears only inside a smart window', (t) async {
      await t.pumpWidget(view(const [
        AlarmScheduleEntry(weekday: 0, hour: 7, minute: 0),
      ]));
      expect(find.text('Wake at sleep goal'), findsNothing);

      await t.pumpWidget(view(const [
        AlarmScheduleEntry(weekday: 0, hour: 7, minute: 0, smartWindowMinutes: 30),
      ]));
      await t.pumpAndSettle();
      expect(find.text('Wake at sleep goal'), findsOneWidget);
    });

    testWidgets('tapping it flips the flag for that weekday', (t) async {
      (int, bool)? got;
      await t.pumpWidget(view(const [
        AlarmScheduleEntry(weekday: 0, hour: 7, minute: 0, smartWindowMinutes: 30),
      ], onSetSleepGoal: (w, on) async => got = (w, on)));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Wake at sleep goal'));
      await t.tap(find.text('Wake at sleep goal'));
      expect(got, (0, true));
    });
  });
}
