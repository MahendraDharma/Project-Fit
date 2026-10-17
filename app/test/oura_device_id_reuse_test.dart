// One ring keeps one device_id across re-pairings.
//
// The id is the storage key for `decoded_onehz`, `raw_archive` and every
// `sync_cursor` item (`oura_cursor_ds:`, `oura_anchor:`, `counter_hw:`,
// `rec_ts_hw:`). Minting a fresh one on each pairing forked one physical ring
// into N identities: a re-paired ring drained from a zero cursor and every
// frame the previous pairing banked was orphaned under an id nothing reads.
// Seen on a real device — a ring row `oura-a4487268` beside 96,521 archived
// frames and all four cursors under `oura-7e117c66`.
import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/ble/oura_link.dart';
import 'package:openstrap_edge/data/db.dart';

void main() {
  group('ouraReusableDeviceId', () {
    test('reuses the paired ring row id so a re-pair reconciles', () {
      expect(ouraReusableDeviceId({'id': 'oura-7e117c66'}), 'oura-7e117c66');
    });

    test('mints when no ring has ever been paired', () {
      expect(ouraReusableDeviceId(null), isNull);
    });

    test('mints when the row carries no id', () {
      expect(ouraReusableDeviceId({'adapter_id': 'oura'}), isNull);
    });

    // `_sync()` refuses a ring row claiming the primary band's id and tells the
    // user to re-pair with a minted one. Reusing it would rebuild the very
    // state that message asks them to escape, and would interleave the ring's
    // seconds with the band's in one REPLACE-keyed table.
    test('refuses to carry the primary band id forward', () {
      expect(ouraReusableDeviceId({'id': LocalDb.kPrimaryDeviceId}), isNull);
    });
  });
}
