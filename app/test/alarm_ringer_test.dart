// A wake alarm keeps buzzing until the wearer double-taps the band: every buzz
// that stops on its own starts again, a double tap ends it, and it never
// buzzes someone who already turned it off.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:projectfit/notify/notification_center.dart';
import 'package:projectfit/notify/notification_event.dart';
import 'package:projectfit/platform/phone_alarm.dart';
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

  test('a stop the band did not explain is not the wearer: it keeps ringing',
      () async {
    final r = ringer()..onFired();
    await r.onHapticsEnded(null);
    await r.onHapticsEnded('code_7');
    expect(r.ringing, isTrue);
    expect(buzzes, 2);
    expect(ends, isEmpty);
    r.stop();
  });

  test('it never gives up on its own: an hour on it still rings', () async {
    final r = ringer()..onFired();
    for (var i = 0; i < 120; i++) {
      now = now.add(const Duration(seconds: 30));
      await r.onHapticsEnded('expired');
    }
    expect(r.ringing, isTrue);
    expect(buzzes, 120);
    r.stop();
    expect(ends, [RingEnd.app]);
  });

  test('a cap is only there when asked for', () async {
    final r = AlarmRinger(
        rebuzz: () async => buzzes++,
        now: () => now,
        onEnd: ends.add,
        maxRing: const Duration(minutes: 20))
      ..onFired();
    now = now.add(const Duration(minutes: 20));
    await r.onHapticsEnded('expired');
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

  test('a lost link is not a stop: it tries again shortly', () async {
    var fail = true;
    final r = AlarmRinger(
        rebuzz: () async {
          if (fail) throw Exception('not connected');
          buzzes++;
        },
        now: () => now,
        onEnd: ends.add,
        retryEvery: const Duration(milliseconds: 20))
      ..onFired();
    await r.onHapticsEnded('expired');
    expect(r.ringing, isTrue);
    expect(buzzes, 0);
    fail = false;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(buzzes, 1);
    expect(r.ringing, isTrue);
    r.stop();
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

  test('super strong keeps its beat past twenty minutes', () async {
    final r = ringer()
      ..strong = true
      ..onFired();
    now = now.add(const Duration(minutes: 25));
    await r.tick();
    expect(buzzes, 1);
    expect(r.ringing, isTrue);
    r.stop();
  });

  group('in the app', () {
    final originalSink = NotificationCenter.instance.presentSink;
    tearDown(() => NotificationCenter.instance.presentSink = originalSink);

    Future<(AppState, _FakePhoneAlarm)> boot() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs.ensureLoaded();
      NotificationCenter.instance.presentSink =
          (NotificationEvent e, {bool allowPermissionPrompt = true}) async => true;
      final app = AppState.forTesting();
      final phone = _FakePhoneAlarm();
      app.phoneAlarm = phone;
      return (app, phone);
    }

    test('the settings start at their defaults and stick', () async {
      final (app, _) = await boot();
      addTearDown(app.dispose);
      expect(app.alarmUntilDoubleTap, isTrue);
      expect(app.alarmPhoneSound, isFalse, reason: 'the phone stays quiet unless asked');
      expect(app.alarmSoundLoud, isFalse);
      expect(app.alarmVibrationStrong, isFalse);
      await app.setAlarmSoundLoud(true);
      await app.setAlarmVibrationStrong(true);
      expect(app.alarmSoundLoud, isTrue);
      expect(app.alarmVibrationStrong, isTrue);
    });

    test('the band firing rings the band and the phone; Stop silences both',
        () async {
      final (app, phone) = await boot();
      addTearDown(app.dispose);
      await app.setAlarmPhoneSound(true);
      expect(phone.asked, isTrue, reason: 'turning it on asks for the permission');

      app.debugHandleAlarmEvent(57);
      expect(app.alarmRinging, isTrue);
      expect(phone.live.keys, contains(PhoneAlarmSlot.now));
      app.stopAlarmRinging();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(app.alarmRinging, isFalse);
      expect(phone.live.keys, isNot(contains(PhoneAlarmSlot.now)));
    });

    test('the phone alarm follows the wake time, and stops with the setting',
        () async {
      final (app, phone) = await boot();
      addTearDown(app.dispose);
      final wake = DateTime.now().add(const Duration(hours: 8));
      app.device.alarmEpoch = wake.millisecondsSinceEpoch ~/ 1000;
      await app.setAlarmPhoneSound(true);
      expect(phone.live[PhoneAlarmSlot.scheduled]!.millisecondsSinceEpoch ~/ 1000,
          wake.millisecondsSinceEpoch ~/ 1000);
      expect(app.alarmRinging, isFalse, reason: 'scheduled is not ringing');
      await app.setAlarmPhoneSound(false);
      expect(phone.live, isEmpty);
    });

    test('try it now without the band rings the phone alone, or says why',
        () async {
      final (app, phone) = await boot();
      addTearDown(app.dispose);
      await expectLater(app.tryAlarmNow(), throwsException,
          reason: 'no band and no phone sound: nothing could ring');
      expect(app.alarmRinging, isFalse);
      await app.setAlarmPhoneSound(true);
      expect(await app.tryAlarmNow(), isFalse);
      expect(app.alarmRinging, isTrue);
      expect(phone.live.keys, contains(PhoneAlarmSlot.now));
      app.stopAlarmRinging();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(app.alarmRinging, isFalse);
    });

    test('a ring stopped on the phone app stops the band too', () async {
      final (app, phone) = await boot();
      addTearDown(app.dispose);
      await app.setAlarmPhoneSound(true);
      app.debugHandleAlarmEvent(57);
      expect(app.debugRinger.ringing, isTrue);
      phone.stopOnPhone(); // AlarmKit's Stop
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(app.debugRinger.ringing, isFalse);
      expect(app.alarmRinging, isFalse);
    });

    test('with "until double-tap" off, the band buzzes once', () async {
      final (app, _) = await boot();
      addTearDown(app.dispose);
      await app.setAlarmUntilDoubleTap(false);
      app.debugHandleAlarmEvent(57);
      expect(app.debugRinger.ringing, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
  });
}

/// The phone's alarm, recorded instead of registered with the OS.
class _FakePhoneAlarm implements PhoneAlarmApi {
  final live = <PhoneAlarmSlot, DateTime>{};
  bool asked = false;
  void Function()? _stopped;

  void stopOnPhone() => _stopped?.call();

  @override
  set onStoppedOnPhone(void Function()? f) => _stopped = f;

  @override
  Future<bool> requestPermission() async => asked = true;

  @override
  Future<void> schedule(PhoneAlarmSlot slot,
      {required DateTime at,
      required bool loud,
      required String title,
      required String body,
      required String stopLabel}) async {
    live[slot] = at;
  }

  @override
  Future<void> cancel(PhoneAlarmSlot slot) async => live.remove(slot);
}
