import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/data/observation.dart';
import 'package:projectfit/garmin/connectiq_link.dart';

void main() {
  test('a stress message becomes vendor rows under the direct link\'s key', () {
    final rows = ciqObservations({
      'k': 'stress',
      'd': [1792900000, 21, 1792900180, 75, 1792900360, 140],
    });
    expect(rows, hasLength(2)); // 140 is not a stress level
    expect(rows.first.vendorKey, 'stress_level');
    expect(rows.first.sourceKind, ObservationSource.vendor);
    expect(rows.first.attribution, 'Garmin');
    expect(rows.first.at, DateTime.fromMillisecondsSinceEpoch(1792900000 * 1000));
    expect(rows.last.value, 75);
  });

  test('body battery and steps land where their screens read them', () {
    final bb = ciqObservations({'k': 'body_battery', 'd': [1792900000, 43]});
    expect(bb.single.vendorKey, 'body_battery');
    expect(bb.single.unit, '%');
    final steps = ciqObservations({'k': 'steps_day', 'd': [1792800000, 8123]});
    expect(steps.single.key, 'steps');
    expect(steps.single.vendorKey, isNull);
  });

  test('junk and the end message store nothing', () {
    expect(ciqObservations(null), isEmpty);
    expect(ciqObservations({'k': 'end', 'n': 3}), isEmpty);
    expect(ciqObservations({'k': 'stress', 'd': 'x'}), isEmpty);
    expect(ciqObservations({'k': 'stress', 'd': [1, 'a', 2]}), isEmpty);
    expect(ciqObservations({'k': 'spo2', 'd': [1792900000, 50]}), isEmpty);
  });

  test('a report survives the round trip', () {
    const r = CiqSyncReport(atMs: 1, outcome: 'success', stored: 9, ended: true);
    final back = CiqSyncReport.fromJson('{"at":1,"outcome":"success","stored":9,"ended":true}')!;
    expect(back.ok, r.ok);
    expect(back.stored, 9);
    expect(CiqSyncReport.fromJson('nope'), isNull);
  });
}
