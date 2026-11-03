// The mochi's message on Home: one fixed priority over facts, nothing when
// there is nothing worth saying, and a closed message stays closed today.
import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/platform/install_expiry.dart';
import 'package:projectfit/ui2/screens/home_nudge.dart';
import 'package:projectfit/ui2/ui2.dart';

void main() {
  test('a draining band outranks everything else', () {
    final n = pickNudge(
        hour: 21, batteryPct: 12, charging: false, alarmArmed: false, bedtimeMin: 1350);
    expect(n?.kind, NudgeKind.battery);
    expect(n?.mood, MochiMood.alert);
  });

  test('a charging band is not nagged about its level', () {
    expect(pickNudge(hour: 10, batteryPct: 5, charging: true), isNull);
  });

  test('in the evening a missing alarm comes before bedtime', () {
    expect(pickNudge(hour: 20, alarmArmed: false, bedtimeMin: 1350)?.kind,
        NudgeKind.alarm);
    expect(pickNudge(hour: 20, bedtimeMin: 1350)?.kind, NudgeKind.bedtime);
    // Not before 17:00: an unarmed alarm at noon is not news yet.
    expect(pickNudge(hour: 12, alarmArmed: false), isNull);
  });

  test('a day without a sync says so', () {
    expect(pickNudge(hour: 14, staleHours: 30)?.kind, NudgeKind.stale);
    expect(pickNudge(hour: 14, staleHours: 3), isNull);
  });

  test('the morning reads the recovery band', () {
    expect(pickNudge(hour: 8, readiness: 80)?.kind, NudgeKind.recoveryHigh);
    expect(pickNudge(hour: 8, readiness: 50)?.kind, NudgeKind.recoveryMid);
    expect(pickNudge(hour: 8, readiness: 20)?.mood, MochiMood.sleepy);
    // Not in the afternoon: by then the day is being lived, not planned.
    expect(pickNudge(hour: 15, readiness: 80), isNull);
  });

  test('a dismissed kind falls through to the next one', () {
    final n = pickNudge(
        hour: 21,
        alarmArmed: false,
        bedtimeMin: 1350,
        dismissed: const {NudgeKind.alarm});
    expect(n?.kind, NudgeKind.bedtime);
  });

  test('the words carry the figures', () {
    expect(
        nudgeText(null, (kind: NudgeKind.battery, mood: MochiMood.alert),
            batteryPct: 12.4),
        contains('12%'));
    expect(
        nudgeText(null, (kind: NudgeKind.recoveryHigh, mood: MochiMood.happy),
            readiness: 86),
        contains('86%'));
  });

  test('an install about to stop opening outranks everything', () {
    final n = pickNudge(hour: 21, batteryPct: 5, charging: false, installHoursLeft: 20);
    expect(n?.kind, NudgeKind.redeploy);
    expect(n?.mood, MochiMood.alert);
  });

  test('the warning starts 48 hours ahead and stops once it has lapsed', () {
    final now = DateTime(2026, 11, 3, 9);
    expect(InstallExpiry.hoursLeftToWarn(null, now), isNull);
    expect(InstallExpiry.hoursLeftToWarn(now.add(const Duration(days: 5)), now), isNull);
    expect(InstallExpiry.hoursLeftToWarn(now.add(const Duration(hours: 30)), now), 30);
    expect(InstallExpiry.hoursLeftToWarn(now.subtract(const Duration(hours: 1)), now),
        isNull);
  });

  test('the redeploy words name the day and the time', () {
    final ends = installEndsText(null, DateTime(2026, 11, 5, 14, 5));
    expect(ends, contains('Thursday'));
    expect(
        nudgeText(null, (kind: NudgeKind.redeploy, mood: MochiMood.alert),
            installEnds: ends),
        allOf(contains('Thursday'), contains('Mac')));
  });
}
