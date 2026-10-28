import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/ble/raw_capture.dart';

void main() {
  test('records frames only while running and writes header, frames, footer', () {
    var now = DateTime(2026, 10, 26, 23, 40);
    final c = RawCapture(minutes: 1, now: () => now);
    c.add(0x2B, 'aa', null); // before start: ignored
    c.start({'band': 'gen4', 'optics': {'led_drive': '1:0a'}});
    c.add(0x2B, 'aabb', 1792900000);
    now = now.add(const Duration(seconds: 30));
    c.add(0x33, 'cc', null);
    expect(c.secondsLeft, 30);
    now = now.add(const Duration(seconds: 31));
    expect(c.timeUp, isTrue);
    c.addLog('[raw] note');
    c.stop({'phase': 'listening'});
    c.add(0x28, 'dd', null); // after stop: ignored
    c.addLog('late'); // after stop: ignored
    final lines = const LineSplitter().convert(c.toJsonl());
    expect(lines, hasLength(4));
    final head = jsonDecode(lines.first) as Map;
    expect(head['kind'], 'projectfit-raw-capture');
    expect((head['optics'] as Map)['led_drive'], '1:0a');
    expect(jsonDecode(lines[1]), containsPair('rec', 1792900000));
    expect(jsonDecode(lines[2]), isNot(contains('rec')));
    final end = jsonDecode(lines.last) as Map;
    expect(end['frames'], 2);
    expect(end['counts'], {'0x2b': 1, '0x33': 1});
    expect(end['diag_end'], {'phase': 'listening'});
    expect((end['log'] as List).single, endsWith('[raw] note'));
    expect(c.fileName, 'projectfit-raw-20261026-2340.jsonl');
  });
}
