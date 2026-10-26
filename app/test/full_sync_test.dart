import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/sync/full_sync.dart';

class _Host implements FullSyncHost {
  bool paired = true, garmin = true, health = true;
  int healthRows = 3;
  int dataChangedCalls = 0;
  final List<String> calls = [];
  final band = Completer<void>();
  final watch = Completer<bool>();
  DateTime? last;
  double? watchProgress;

  @override
  bool get bandPaired => paired;
  @override
  Future<void> syncBand() {
    calls.add('band');
    return band.future;
  }

  @override
  bool get bandActive => false;
  @override
  DateTime? get lastRecordAt => last;
  @override
  bool get deriving => false;
  @override
  (int, int)? get deriveDays => null;
  @override
  Future<bool> garminPaired() async => garmin;
  @override
  Future<bool> syncGarmin() {
    calls.add('garmin');
    return watch.future;
  }

  @override
  double? get garminProgress => watchProgress;
  @override
  Future<bool> healthAsked() async => health;
  @override
  Future<int> importHealth() async {
    calls.add('health');
    return healthRows;
  }

  @override
  void dataChanged() => dataChangedCalls++;
}

FullSync _sync(_Host h, DateTime Function() now) => FullSync(
      h,
      tick: const Duration(milliseconds: 1),
      bandCap: const Duration(seconds: 30),
      deriveStartWait: Duration.zero,
      deriveCap: Duration.zero,
      doneHold: const Duration(milliseconds: 20),
      now: now,
    );

Future<void> _spin([int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

void main() {
  test('runs band, watch and Health in order; progress only rises; ends done then idle', () async {
    final h = _Host();
    final t0 = DateTime(2026, 10, 26, 8);
    final now = t0;
    h.last = t0.subtract(const Duration(hours: 10));
    final s = _sync(h, () => now);
    final seen = <double>[];
    s.addListener(() => seen.add(s.value.pct));

    final run = s.run();
    await _spin();
    expect(s.value.running, isTrue);
    expect(s.value.step, SyncStep.band);
    // Half the gap to now has landed.
    h.last = t0.subtract(const Duration(hours: 5));
    await _spin();
    expect(s.value.percent, inInclusiveRange(20, 30)); // band is 0.5 of the bar
    h.band.complete();
    await _spin();
    expect(s.value.step, SyncStep.garmin);
    h.watchProgress = .5;
    await _spin();
    h.watch.complete(true);
    await run;

    expect(h.calls, ['band', 'garmin', 'health']);
    expect(s.value.phase, SyncPhase.done);
    expect(s.value.percent, 100);
    expect(h.dataChangedCalls, 1);
    for (var i = 1; i < seen.length; i++) {
      expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
    }
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(s.value.phase, SyncPhase.idle);
    s.dispose();
  });

  test('a second tap joins the run already going', () async {
    final h = _Host()..garmin = false..health = false;
    final s = _sync(h, DateTime.now);
    final a = s.run();
    final b = s.run();
    h.band.complete();
    await Future.wait([a, b]);
    expect(h.calls, ['band']);
    s.dispose();
  });

  test('without a band, the watch step fills the bar alone', () async {
    final h = _Host()..paired = false..health = false;
    final s = _sync(h, DateTime.now);
    final run = s.run();
    await _spin();
    expect(s.value.step, SyncStep.garmin);
    h.watchProgress = .5;
    await _spin();
    expect(s.value.percent, 50);
    h.watch.complete(true);
    await run;
    expect(s.value.percent, 100);
    s.dispose();
  });

  test('a step that throws does not stop the run', () async {
    final h = _Host()..health = false;
    final s = _sync(h, DateTime.now);
    final run = s.run();
    await _spin();
    h.band.completeError(StateError('radio off'));
    await _spin();
    h.watch.complete(false);
    await run;
    expect(h.calls, ['band', 'garmin']);
    expect(s.value.phase, SyncPhase.done);
    s.dispose();
  });

  test('nothing to sync still ends with complete, and screens re-read', () async {
    final h = _Host()..paired = false..garmin = false..health = false;
    final s = _sync(h, DateTime.now);
    await s.run();
    expect(s.value.phase, SyncPhase.done);
    expect(h.dataChangedCalls, 1);
    s.dispose();
  });
}
