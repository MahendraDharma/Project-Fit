// "Sync" as the person means it: everything this phone can pull, in one tap,
// with one honest progress figure and one "done".
//
// The band's own sync used to be the whole of it. A paired Garmin watch was
// reached only by a background wake or a button three screens deep in
// Devices, the readings other apps put in Health only on an hourly foreground
// pass, and nothing told the screens to re-read when either landed — so a
// sync could finish and the Garmin cards stay empty until a relaunch.
//
// THE STEPS, in order, each only when it applies:
//   band    — the band's backlog. Progress is how far the newest banked
//             record has come from where it stood at the tap toward now: the
//             band offloads oldest first, so that is the share of the gap
//             already on the phone.
//   derive  — the pass the drain starts. Days done of days queued.
//   garmin  — the paired watch's health files. Files read of files listed.
//   health  — the readings in Apple Health / Health Connect, once the person
//             has said yes to them on a tap. One step, no inner figure.
// Each step's share of the bar is fixed ([_weights]) and the shares of the
// steps that do not apply are spread over the rest, so the bar never stalls
// at a step that is not there.
//
// NOTHING HERE DECIDES WHAT A STEP DOES. The band step is the existing
// `syncNow`, the watch step `GarminLink.sync`, the Health step the existing
// importer — this file only runs them in order and reads their progress.
import 'dart:async';

import 'package:flutter/foundation.dart';

enum SyncStep { band, derive, garmin, health }

enum SyncPhase { idle, running, done }

@immutable
class SyncRun {
  final SyncPhase phase;

  /// 0..1 of the whole run.
  final double pct;

  /// The step running now; null when not running.
  final SyncStep? step;

  /// When the last run ended.
  final DateTime? endedAt;

  const SyncRun(this.phase, {this.pct = 0, this.step, this.endedAt});

  static const idle = SyncRun(SyncPhase.idle);

  bool get running => phase == SyncPhase.running;

  /// Whole percent, never 100 before the run is over.
  int get percent => phase == SyncPhase.done ? 100 : (pct * 100).floor().clamp(0, 99);
}

/// What [FullSync] drives. AppState implements it; a test fakes it.
abstract class FullSyncHost {
  bool get bandPaired;
  Future<void> syncBand();

  /// Band records are landing right now.
  bool get bandActive;
  DateTime? get lastRecordAt;

  bool get deriving;
  (int, int)? get deriveDays;

  Future<bool> garminPaired();
  Future<bool> syncGarmin();
  double? get garminProgress;

  /// Whether the person has said yes to Health readings.
  Future<bool> healthAsked();
  Future<int> importHealth();

  /// The durable data changed: every screen re-reads.
  void dataChanged();
}

const Map<SyncStep, double> _weights = {
  SyncStep.band: 0.5,
  SyncStep.derive: 0.2,
  SyncStep.garmin: 0.2,
  SyncStep.health: 0.1,
};

class FullSync extends ValueNotifier<SyncRun> {
  FullSync(
    this._host, {
    this.tick = const Duration(milliseconds: 250),
    this.bandCap = const Duration(seconds: 120),
    this.deriveStartWait = const Duration(seconds: 4),
    this.deriveCap = const Duration(seconds: 120),
    this.doneHold = const Duration(seconds: 4),
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        super(SyncRun.idle);

  final FullSyncHost _host;
  final Duration tick;

  /// The longest the bar waits on the band. A long backlog keeps draining
  /// after it; the bar moves on rather than sitting at one figure for an hour.
  final Duration bandCap;
  final Duration deriveStartWait;
  final Duration deriveCap;

  /// How long "Sync complete" stays before the pill goes back to idle.
  final Duration doneHold;
  final DateTime Function() _now;

  Future<void>? _running;
  Timer? _clear;
  bool _disposed = false;

  /// Start a run, or join the one already going.
  Future<void> run() => _running ??= _run().whenComplete(() => _running = null);

  Future<void> _run() async {
    _clear?.cancel();
    final steps = <SyncStep>[
      if (_host.bandPaired) ...[SyncStep.band, SyncStep.derive],
      if (await _safe(_host.garminPaired, false)) SyncStep.garmin,
      if (await _safe(_host.healthAsked, false)) SyncStep.health,
    ];
    final total = steps.fold<double>(0, (a, s) => a + _weights[s]!);
    var before = 0.0;
    double share(SyncStep s) => total == 0 ? 0 : _weights[s]! / total;

    void show(SyncStep s, double inner) {
      if (_disposed) return;
      final p = (before + share(s) * inner.clamp(0.0, 1.0)).clamp(0.0, 1.0);
      // Never backwards: a step's inner figure can dip (a new file listed).
      value = SyncRun(SyncPhase.running, pct: p < value.pct ? value.pct : p, step: s);
    }

    if (!_disposed) value = SyncRun(SyncPhase.running, step: steps.firstOrNull);
    var changed = false;
    for (final s in steps) {
      show(s, 0);
      switch (s) {
        case SyncStep.band:
          await _band((f) => show(s, f));
        case SyncStep.derive:
          await _derive((f) => show(s, f));
        case SyncStep.garmin:
          await _poll(
            _safe(_host.syncGarmin, false),
            () => show(s, _host.garminProgress ?? 0),
          );
        case SyncStep.health:
          if (await _safe(_host.importHealth, 0) > 0) changed = true;
      }
      show(s, 1);
      before += share(s);
      if (s != SyncStep.band) changed = true;
    }
    if (changed || steps.isEmpty) _host.dataChanged();
    if (_disposed) return;
    value = SyncRun(SyncPhase.done, pct: 1, endedAt: _now());
    _clear = Timer(doneHold, () {
      if (!_disposed && value.phase == SyncPhase.done) {
        value = SyncRun(SyncPhase.idle, endedAt: value.endedAt);
      }
    });
  }

  Future<void> _band(void Function(double) show) async {
    final start = _host.lastRecordAt ?? _now().subtract(const Duration(days: 1));
    final began = _now();
    double frac() {
      final last = _host.lastRecordAt;
      if (last == null) return 0;
      final gap = _now().difference(start).inSeconds;
      if (gap <= 0) return 1;
      return last.difference(start).inSeconds / gap;
    }

    await _poll(_safe(_host.syncBand, null), () => show(frac()),
        until: began.add(bandCap));
    // `syncNow` can return while the burst it asked for is still landing.
    while (_host.bandActive && _now().isBefore(began.add(bandCap))) {
      show(frac());
      await Future<void>.delayed(tick);
    }
  }

  Future<void> _derive(void Function(double) show) async {
    final began = _now();
    // The drain asks for the pass; it may not have started yet.
    while (!_host.deriving && _now().difference(began) < deriveStartWait) {
      await Future<void>.delayed(tick);
    }
    while (_host.deriving && _now().difference(began) < deriveCap) {
      final d = _host.deriveDays;
      if (d != null && d.$2 > 0) show(d.$1 / d.$2);
      await Future<void>.delayed(tick);
    }
  }

  /// Await [f], calling [onTick] every [tick] until it completes or [until].
  Future<void> _poll(Future<Object?> f, void Function() onTick, {DateTime? until}) async {
    var done = false;
    unawaited(f.whenComplete(() => done = true));
    while (!done && (until == null || _now().isBefore(until))) {
      onTick();
      await Future<void>.delayed(tick);
    }
  }

  static Future<T> _safe<T>(Future<T> Function() f, T fallback) async {
    try {
      return await f();
    } catch (e) {
      debugPrint('[full_sync] step failed: $e');
      return fallback;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _clear?.cancel();
    super.dispose();
  }
}
