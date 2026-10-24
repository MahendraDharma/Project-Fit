import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:projectfit/health/health_readings_import.dart';
import 'package:projectfit/ui2/screens/external_vitals.dart';

const _own = 'com.projectfit.app';

HealthDataPoint _p(
  HealthDataType type,
  num value, {
  String uuid = 'u1',
  DateTime? from,
  DateTime? to,
  String source = 'Connect',
  String sourceId = 'com.garmin.connect.mobile',
}) =>
    HealthDataPoint(
      uuid: uuid,
      value: NumericHealthValue(numericValue: value),
      type: type,
      unit: HealthDataUnit.PERCENT,
      dateFrom: from ?? DateTime(2026, 10, 20, 9),
      dateTo: to ?? from ?? DateTime(2026, 10, 20, 9),
      sourceId: sourceId,
      sourcePlatform: HealthPlatformType.appleHealth,
      sourceDeviceId: 'dev',
      sourceName: source,
    );

void main() {
  group('point readings', () {
    test('SpO₂ arrives as a fraction and is stored as a percentage', () {
      final rows = readingRowsFrom([_p(HealthDataType.BLOOD_OXYGEN, .962)], _own);
      expect(rows.single['kind'], kKindSpo2);
      expect(rows.single['value'], closeTo(96.2, 1e-9));
      expect(rows.single['source'], 'Connect');
    });

    test('our own exports are not read back as another device', () {
      final rows = readingRowsFrom([
        _p(HealthDataType.RESTING_HEART_RATE, 51, sourceId: _own, source: 'ProjectFit'),
        _p(HealthDataType.RESTING_HEART_RATE, 53, uuid: 'u2'),
      ], _own);
      expect(rows.single['value'], 53);
    });

    test('an implausible reading is dropped, not clamped', () {
      expect(readingRowsFrom([_p(HealthDataType.RESPIRATORY_RATE, 80)], _own), isEmpty);
    });

    test('a nameless source still says it is someone else', () {
      expect(readingRowsFrom([_p(HealthDataType.HEART_RATE_VARIABILITY_SDNN, 60, source: ' ')], _own)
          .single['source'], 'Unknown app');
    });
  });

  test('steps: one row per day and source, sources never added together', () {
    final rows = stepRowsFrom([
      _p(HealthDataType.STEPS, 4000, uuid: 'a'),
      _p(HealthDataType.STEPS, 2000, uuid: 'b', from: DateTime(2026, 10, 20, 15)),
      _p(HealthDataType.STEPS, 5500, uuid: 'c', source: 'iPhone', sourceId: 'com.apple.health'),
    ], _own);
    final by = {for (final r in rows) r['source']: r['value']};
    expect(by, {'Connect': 6000.0, 'iPhone': 5500.0});
  });

  group('sleep', () {
    test('staged minutes win over an unstaged total of the same night', () {
      final n = DateTime(2026, 10, 19, 23);
      final rows = sleepRowsFrom([
        _p(HealthDataType.SLEEP_ASLEEP, 0, uuid: 'x', from: n, to: n.add(const Duration(hours: 7))),
        _p(HealthDataType.SLEEP_LIGHT, 0, uuid: 'l', from: n, to: n.add(const Duration(hours: 4))),
        _p(HealthDataType.SLEEP_DEEP, 0, uuid: 'd',
            from: n.add(const Duration(hours: 4)), to: n.add(const Duration(hours: 5))),
        _p(HealthDataType.SLEEP_REM, 0, uuid: 'r',
            from: n.add(const Duration(hours: 5)), to: n.add(const Duration(hours: 6, minutes: 30))),
      ], _own);
      final by = {for (final r in rows) r['kind']: r['value']};
      expect(by[kKindSleepMin], 390);
      expect(by[kKindSleepDeep], 60);
      expect(by[kKindSleepRem], 90);
      expect(rows.every((r) => (r['uuid'] as String).contains('2026-10-20')), isTrue);
    });

    test('a nap is not a night', () {
      final t = DateTime(2026, 10, 20, 14);
      expect(sleepRowsFrom([
        _p(HealthDataType.SLEEP_LIGHT, 0, from: t, to: t.add(const Duration(minutes: 40))),
      ], _own), isEmpty);
    });
  });

  test('VO₂ max rows keep the source and skip our own', () {
    final rows = vo2RowsFrom([
      {'uuid': 'v1', 'ts': 1792000000000, 'value': 41.0, 'source': 'Connect', 'sourceId': 'g'},
      {'uuid': 'v2', 'ts': 1792000000000, 'value': 40.0, 'source': 'ProjectFit', 'sourceId': _own},
      {'uuid': 'v3', 'ts': 1792000000000, 'value': 3.0, 'source': 'Connect', 'sourceId': 'g'},
    ], _own);
    expect(rows.single['uuid'], 'v1');
    expect(rows.single['source'], 'Connect');
  });

  group('per-day series', () {
    int ts(int d, int h) => DateTime(2026, 10, d, h).millisecondsSinceEpoch ~/ 1000;

    test('several readings in a day average within the busiest source only', () {
      final days = externalDaysFrom([
        {'ts': ts(20, 8), 'value': 95.0, 'source': 'Connect'},
        {'ts': ts(20, 12), 'value': 97.0, 'source': 'Connect'},
        {'ts': ts(20, 9), 'value': 90.0, 'source': 'Other'},
      ]);
      expect(days['2026-10-20'], (value: 96.0, source: 'Connect'));
    });

    test('the band keeps its days; another device fills only the gaps', () {
      final pts = mergeWithExternal(
        {'2026-10-19': 52, '2026-10-21': 50},
        {
          '2026-10-19': (value: 60, source: 'Connect'),
          '2026-10-20': (value: 55, source: 'Connect'),
        },
      );
      expect(pts.map((p) => (p.day, p.value, p.source)), [
        ('2026-10-19', 52.0, null),
        ('2026-10-20', 55.0, 'Connect'),
        ('2026-10-21', 50.0, null),
      ]);
    });
  });
}
