// The phone's own alarm, registered with the OS for the wake time, so it rings
// on a locked phone with the screen off, whether or not the app is running.
//
//   iOS 26+   AlarmKit: a system alarm, full screen on the lock screen, through
//             silent mode and Focus, ringing until stopped
//             (`PhoneAlarmBridge` in AppDelegate.swift).
//   older iOS, or AlarmKit refused: a run of notifications 30 s apart, each
//             carrying the tone (iOS keeps 64 pending; 30 of them, 15 min).
//   Android   one full-screen-intent notification on the alarm-clock exact
//             schedule, insistent (the tone repeats until it is cancelled).
//
// Two slots: [PhoneAlarmSlot.scheduled] is the next wake time; [now] is a ring
// started by the band (smart wake, "try it now"). Stopping a ring clears the
// slot that is ringing and never tomorrow's.
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../notify/notification_service.dart';

enum PhoneAlarmSlot { scheduled, now }

/// What [AppState] needs from the phone's alarm; tests swap it.
abstract class PhoneAlarmApi {
  /// Called when the person stops the alarm on the phone (AlarmKit's Stop).
  set onStoppedOnPhone(void Function()? f);
  Future<bool> requestPermission();
  Future<void> schedule(PhoneAlarmSlot slot,
      {required DateTime at,
      required bool loud,
      required String title,
      required String body,
      required String stopLabel});
  Future<void> cancel(PhoneAlarmSlot slot);
}

class PhoneAlarm implements PhoneAlarmApi {
  PhoneAlarm() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'stopped') _onStopped?.call();
    });
  }

  static const _channel = MethodChannel('projectfit/phone_alarm');
  void Function()? _onStopped;

  @override
  set onStoppedOnPhone(void Function()? f) => _onStopped = f;

  /// iOS keeps the alarm in AlarmKit when it may; null until asked.
  bool? _alarmKit;

  @override
  Future<bool> requestPermission() async {
    try {
      if (Platform.isIOS) {
        _alarmKit = await _channel.invokeMethod<bool>('requestAuth') ?? false;
        return _alarmKit! || await NotificationService.instance.ensurePermission();
      }
      if (Platform.isAndroid) {
        return NotificationService.instance.requestAlarmPermissions();
      }
    } catch (_) {
      _alarmKit = false;
    }
    return false;
  }

  @override
  Future<void> schedule(PhoneAlarmSlot slot,
      {required DateTime at,
      required bool loud,
      required String title,
      required String body,
      required String stopLabel}) async {
    await cancel(slot);
    final ns = NotificationService.instance;
    if (Platform.isAndroid) {
      await ns.scheduleAlarmAndroid(_androidId(slot),
          at: at, loud: loud, title: title, body: body, now: slot == PhoneAlarmSlot.now);
      return;
    }
    if (!Platform.isIOS) return;
    var kit = false;
    try {
      kit = await _channel.invokeMethod<bool>('schedule', {
            'slot': slot.name,
            'at': at.millisecondsSinceEpoch,
            'loud': loud,
            'title': title,
            'stop': stopLabel,
          }) ??
          false;
    } catch (_) {}
    if (!kit) {
      await ns.scheduleAlarmSeries(_seriesBase(slot),
          from: at, loud: loud, title: title, body: body);
    }
  }

  @override
  Future<void> cancel(PhoneAlarmSlot slot) async {
    final ns = NotificationService.instance;
    if (Platform.isAndroid) {
      await ns.cancel(_androidId(slot));
      return;
    }
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('cancel', {'slot': slot.name});
    } catch (_) {}
    await ns.cancelAlarmSeries(_seriesBase(slot));
  }

  static int _androidId(PhoneAlarmSlot s) => s == PhoneAlarmSlot.scheduled
      ? NotificationService.idPhoneAlarm
      : NotificationService.idPhoneAlarmNow;

  static int _seriesBase(PhoneAlarmSlot s) => s == PhoneAlarmSlot.scheduled
      ? NotificationService.idAlarmSeries
      : NotificationService.idAlarmSeriesNow;
}
