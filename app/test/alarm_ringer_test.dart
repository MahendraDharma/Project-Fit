// A wake alarm keeps buzzing until the wearer double-taps the band: every buzz
// that stops on its own starts again, a double tap ends it, and it never
// buzzes someone who already turned it off.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:projectfit/notify/notification_center.dart';
import 'package:projectfit/notify/notification_event.dart';
import 'package:projectfit/state/alarm_ringer.dart';
import 'package:projectfit/state/app_state.dart';
import 'package:projectfit/state/prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late int buzzes;
  late List<RingEnd> ends;
  late int sounds;
  AlarmRinger ringer({Future<void> Function()? rebuzz}) => AlarmRinger(
        rebuzz: rebuzz ?? () async => buzzes++,
        now: () => now,
        onEnd: ends.add,
        onBuzz: () => sounds++,
      );

  setUp(() {
    now = DateTime(2026, 11, 4, 6, 30);
    buzzes = 0;
    ends = [];
    sounds = 0;
  });

  int sec(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  test('a buzz that runs out starts again, until the double tap', () async {
    final r = ringer()..onFired(tsSec: sec(now));
    expect(r.ringing, isTrue);
    await r.onHapticsEnded('expired');
    await r.onHapticsEnded('expired');
    expect(buzzes, 2);
    // The phone's tone follows every re-buzz.
    expect(sounds, 2);
    expect(r.ringing, isTrue);
    await r.onHapticsEnded('user_double_tap');
    expect(r.ringing, isFalse);
    expect(ends, [RingEnd.doubleTap]);
    // After the tap, a late stop buzzes nobody.
    await r.onHapticsEnded('expired');
    expect(buzzes, 2);
  });

  test('a double-tap gesture event stops it too, and is spent on it', () {
    final r = ringer()..onFired();
    expect(r.onDoubleTap(), isTrue);
    expect(r.ringing, isFalse);
    // Not ringing: the tap belongs to the double-tap shortcut.
    expect(r.onDoubleTap(), isFalse);
  });

  test('an unknown stop cause counts as turned off', () async {
    final r = ringer()..onFired();
    await r.onHapticsEnded(null);
    expect(r.ringing, isFalse);
    expect(buzzes, 0);
    expect(ends, [RingEnd.unknownCause]);
  });

  test('it gives up after 20 minutes', () async {
    final r = ringer()..onFired();
    now = now.add(const Duration(minutes: 19));
    await r.onHapticsEnded('expired');
    expect(buzzes, 1);
    now = now.add(const Duration(minutes: 1));
    await r.onHapticsEnded('expired');
    expect(buzzes, 1);
    expect(ends, [RingEnd.timeout]);
  });

  test('a fire replayed from history does not ring', () {
    final r = ringer()
      ..onFired(tsSec: sec(now.subtract(const Duration(minutes: 10))));
    expect(r.ringing, isFalse);
  });

  test('turned off in settings, one buzz is all', () async {
    final r = ringer()
      ..enabled = false
      ..onFired();
    await r.onHapticsEnded('expired');
    expect(r.ringing, isFalse);
    expect(buzzes, 0);
  });

  test('a lost link ends the ring instead of retrying forever', () async {
    final r = ringer(rebuzz: () async => throw Exception('not connected'))..onFired();
    await r.onHapticsEnded('expired');
    expect(r.ringing, isFalse);
    expect(ends, [RingEnd.app]);
  });

  test('super strong restarts on its own beat and ignores its own cut-offs',
      () async {
    final r = ringer()
      ..strong = true
      ..onFired();
    // A buzz that ends on its own waits for the next beat instead.
    await r.onHapticsEnded('expired');
    expect(buzzes, 0);
    await r.tick();
    await r.tick();
    expect(buzzes, 2);
    expect(sounds, 2);
    // The buzz it just cut short reports in: not the wearer, keep going.
    await r.onHapticsEnded('code_7');
    expect(r.ringing, isTrue);
    // The double tap still ends it, and the beat stops with it.
    await r.onHapticsEnded('user_double_tap');
    expect(r.ringing, isFalse);
    await r.tick();
    expect(buzzes, 2);
    r.stop();
  });

  test('super strong still gives up after 20 minutes', () async {
    final r = ringer()
      ..strong = true
      ..onFired();
    now = now.add(const Duration(minutes: 20));
    await r.tick();
    expect(buzzes, 0);
    expect(ends, [RingEnd.timeout]);
  });

  group('in the app', () {
    final originalSink = NotificationCenter.instance.presentSink;
    tearDown(() => NotificationCenter.instance.presentSink = originalSink);

    test('the band firing starts the ring; the setting and the phone stop it',
        () async {
      SharedPreferences.setMockInitialValues({});
      await Prefs.ensureLoaded();
      NotificationCenter.instance.presentSink =
          (NotificationEvent e, {bool allowPermissionPrompt = true}) async => true;
      final app = AppState.forTesting();
      addTearDown(app.dispose);
      expect(app.alarmUntilDoubleTap, isTrue);
      // The phone stays quiet unless asked.
      expect(app.alarmPhoneSound, isFalse);
      await app.setAlarmPhoneSound(true);
      expect(app.alarmPhoneSound, isTrue);
      // Both levels start at normal, and each choice sticks.
      expect(app.alarmSoundLoud, isFalse);
      expect(app.alarmVibrationStrong, isFalse);
      await app.setAlarmSoundLoud(true);
      await app.setAlarmVibrationStrong(true);
      expect(app.alarmSoundLoud, isTrue);
      expect(app.alarmVibrationStrong, isTrue);
      // Trying the alarm needs the band.
      await expectLater(app.tryAlarmNow(), throwsException);
      expect(app.alarmRinging, isFalse);

      app.debugHandleAlarmEvent(57);
      expect(app.alarmRinging, isTrue);
      app.stopAlarmRinging();
      expect(app.alarmRinging, isFalse);

      await app.setAlarmUntilDoubleTap(false);
      expect(app.alarmUntilDoubleTap, isFalse);
      app.debugHandleAlarmEvent(57);
      expect(app.alarmRinging, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
  });
}
