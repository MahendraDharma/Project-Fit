// The Health tab's Garmin-style loader: stored day reads → still-window
// stress, Body Battery slots (asleep / still / active / not worn) and the
// fitness-age inputs.
import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/data/day_label.dart';
import 'package:projectfit/data/local_repository.dart';
import 'package:projectfit/ui2/screens/garmin_style.dart';

int _at(int d, int h, [int m = 0]) =>
    DateTime(2026, 10, d, h, m).millisecondsSinceEpoch ~/ 1000;

class _Repo extends LocalRepository {
  @override
  Future<Map<String, dynamic>> getDaySleepV2(String date) async =>
      date == '2026-10-01'
      ? {
          'onset_ts': DateTime(2026, 9, 30, 23).millisecondsSinceEpoch ~/ 1000,
          'wake_ts': _at(1, 7),
        }
      : const {};

  @override
  Future<Map<String, dynamic>> getDayHeart(String date) async {
    if (date != '2026-10-01') return const {};
    return {
      'daytime_hrv': {
        'timeline': [
          for (var i = 0; i < 12; i++)
            {'t': _at(1, 10) + i * 300, 'rmssd': 30.0, 'n': 60},
        ],
      },
      'hr': [
        for (var i = 0; i < 60; i++) {'t': _at(1, 12) + i * 60, 'v': 150},
        for (var i = 0; i < 60; i++) {'t': _at(1, 14) + i * 60, 'v': 70},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> getWorkouts({String range = 'month'}) async =>
      const {'workouts': []};
}

void main() {
  test('stress and battery from stored reads; stale nights abstain', () async {
    final noon = [
      for (var d = 17; d <= 30; d++)
        (t: DateTime(2026, 9, d, 12).millisecondsSinceEpoch ~/ 1000, v: 60.0),
      (t: DateTime(2026, 10, 1, 12).millisecondsSinceEpoch ~/ 1000, v: 60.0),
    ];
    final g = await GarminStyleData.load(
      _Repo(),
      profile: const {'age': 30, 'sex': 'm', 'waist_cm': 85},
      days: const ['2026-10-01'],
      hrv: noon,
      rhr: [for (final p in noon) (t: p.t, v: 55.0)],
      sleepStress: [for (final p in noon) (t: p.t, v: 25.0)],
    );

    // Still windows at half the night level read 50.
    final s = g.stress.value!;
    expect(s.average, closeTo(50, 1e-9));
    expect(s.scoredMinutes, 60);

    // The night charged, the 150 bpm hour (72 % of reserve at 30) drained more
    // than the 70 bpm hour after it.
    final b = g.battery.value!;
    double at(int h) => b.timeline.lastWhere((p) => p.tSec <= _at(1, h)).level;
    expect(at(7), greaterThan(at(1)));
    // Still at stress 50: a small drain (0.2 a slot).
    expect(at(10) - at(11), closeTo(12 * 0.2, 1e-9));
    // Hard hour vs an easy one.
    expect(at(12) - at(13), greaterThan(10));
    expect(at(14) - at(15), closeTo(12 * 0.15, 1e-9));
    // Not worn after 15:00 (no HR, no windows): the line stops there.
    expect(b.timeline.last.tSec, lessThanOrEqualTo(_at(1, 15)));

    // Resting HR nights are weeks old relative to today: fitness abstains
    // rather than reading a month-old heart.
    expect(g.fitness.present, isFalse);
  });

  test('intensity minutes this week and load focus from session zones',
      () async {
    final today = todayLabel();
    final mid = localDayStartSec(today)!;
    final repo = _TodayRepo(mid);
    final noon = (t: mid + 12 * 3600, v: 55.0);
    final g = await GarminStyleData.load(
      repo,
      profile: const {'age': 30, 'sex': 'm'},
      days: const [],
      hrv: const [],
      rhr: [noon],
      sleepStress: const [],
    );
    // 15 minutes at 150 bpm: 72 % of reserve (55 → 187) — vigorous, doubled.
    final w = g.intensity.value!;
    expect((w.moderate, w.vigorous, w.total), (0, 15, 30));
    final f = g.focus.value!;
    expect((f.lowAerobic, f.highAerobic, f.anaerobic), (60.0, 20.0, 10.0));
  });
}

class _TodayRepo extends LocalRepository {
  final int mid;
  _TodayRepo(this.mid);

  @override
  Future<Map<String, dynamic>> getDayHeart(String date) async =>
      date == todayLabel()
          ? {
              'hr': [
                for (var i = 0; i < 15; i++) {'t': mid + 600 + i * 60, 'v': 150}
              ],
            }
          : const {};

  @override
  Future<Map<String, dynamic>> getWorkouts({String range = 'month'}) async => {
        'workouts': [
          {
            'status': 'done',
            'start_ts': mid,
            'duration_min': 40,
            'zone_min': [10, 10, 10, 5, 2],
          },
        ],
      };
}
