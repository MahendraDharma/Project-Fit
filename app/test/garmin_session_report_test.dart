import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/ble/garmin_link.dart';

void main() {
  test('a session report survives the round trip, and junk reads as none', () {
    const r = GarminSyncReport(
        atMs: 1792900000000, ok: false, listed: -1, read: 0, lines: ['sync failed: timeout']);
    final back = GarminSyncReport.fromJson(jsonEncode(r.toJson()))!;
    expect(back.ok, isFalse);
    expect(back.listed, -1);
    expect(back.lines, ['sync failed: timeout']);
    expect(GarminSyncReport.fromJson('{"at": "x"}'), isNull);
    expect(GarminSyncReport.fromJson(null), isNull);
  });
}
