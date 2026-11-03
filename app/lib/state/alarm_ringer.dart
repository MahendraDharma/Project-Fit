// AlarmRinger — keeps a wake alarm going until the wearer double-taps the band.
//
// The band's own wake buzz runs for a fixed time (30 s, `AlarmPayloads.
// defaultHaptics`) and then stops by itself, so a heavy sleeper could sleep
// through it. The band says WHY a buzz stopped (HAPTICS_TERMINATED, event
// 100): it ran its course (`expired`), the firmware aborted it (`error`), or
// the wearer double-tapped (`user_double_tap`). While ringing, every stop that
// was not a double tap starts the buzz again — until the double tap, the user
// stops it in the app, or [maxRing] passes.
//
// Two rules keep it from ever buzzing someone who already turned it off:
//   • An unknown cause counts as a dismissal. A band that does not report the
//     cause (WHOOP 5's event body is not decoded) gets the old behaviour, one
//     buzz, rather than a buzz that cannot be stopped.
//   • It only starts for a fire that is happening NOW, not one replayed from
//     the band's history after a reconnect.
//
// It needs the phone connected when the alarm goes off: the re-buzz is a
// command the phone sends. Without a connection the band's own buzz still runs.

import 'package:flutter/foundation.dart' show visibleForTesting;

/// Why ringing stopped, for the log and the screen.
enum RingEnd { doubleTap, app, timeout, unknownCause }

class AlarmRinger {
  AlarmRinger({
    required this.rebuzz,
    this.log,
    this.onEnd,
    DateTime Function()? now,
    this.maxRing = const Duration(minutes: 20),
  }) : _now = now ?? DateTime.now;

  /// Starts the band's wake buzz again.
  final Future<void> Function() rebuzz;
  final void Function(String line)? log;

  /// Called once when a ring ends, for whatever reason.
  final void Function(RingEnd why)? onEnd;

  /// The longest a ring keeps going without a double tap — the band is not on
  /// a wrist, or the wearer is away. Battery matters more than one more buzz.
  final Duration maxRing;

  final DateTime Function() _now;

  /// Whether to keep buzzing at all (the user's setting; on by default).
  bool enabled = true;

  DateTime? _startedAt;
  int _rebuzzes = 0;

  bool get ringing => _startedAt != null;
  int get rebuzzes => _rebuzzes;

  /// How old a fire may be and still count as happening now.
  static const int liveFireSlackSec = 120;

  /// The band fired a wake buzz (the armed alarm, or a smart-wake early one).
  /// [tsSec] is the event's wall time, when known.
  void onFired({int? tsSec}) {
    if (!enabled || ringing) return;
    final nowSec = _now().millisecondsSinceEpoch ~/ 1000;
    if (tsSec != null && tsSec > 0 && nowSec - tsSec > liveFireSlackSec) {
      log?.call('[alarm] not ringing for a fire ${nowSec - tsSec}s old');
      return;
    }
    _startedAt = _now();
    _rebuzzes = 0;
    log?.call('[alarm] ringing until a double tap');
  }

  /// The band's buzz stopped; [cause] is its HAPTICS_TERMINATED reason.
  Future<void> onHapticsEnded(String? cause) async {
    if (!ringing) return;
    switch (cause) {
      case 'user_double_tap':
        _end(RingEnd.doubleTap);
        return;
      case 'expired':
      case 'error':
        break;
      default:
        _end(RingEnd.unknownCause);
        return;
    }
    if (_now().difference(_startedAt!) >= maxRing) {
      _end(RingEnd.timeout);
      return;
    }
    _rebuzzes++;
    log?.call('[alarm] buzz ended ($cause) without a double tap — buzzing again '
        '(#$_rebuzzes)');
    try {
      await rebuzz();
    } catch (e) {
      // A dropped link: nothing more the phone can do. The band keeps its
      // own armed alarm state either way.
      log?.call('[alarm] re-buzz failed: $e');
      _end(RingEnd.app);
    }
  }

  /// A double tap arrived as a gesture event. True when it was spent on the
  /// alarm, so the caller does not also run the double-tap shortcut.
  bool onDoubleTap() {
    if (!ringing) return false;
    _end(RingEnd.doubleTap);
    return true;
  }

  /// Stopped from the phone.
  void stop() {
    if (ringing) _end(RingEnd.app);
  }

  void _end(RingEnd why) {
    _startedAt = null;
    log?.call('[alarm] ringing stopped: ${why.name}');
    onEnd?.call(why);
  }

  @visibleForTesting
  DateTime? get startedAt => _startedAt;
}
