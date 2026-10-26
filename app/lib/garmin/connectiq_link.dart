// The Garmin watch through Connect IQ — beside Garmin Connect, not instead of
// it.
//
// Garmin Connect owns the watch's Bluetooth link and cannot be turned off, so
// the direct link (`ble/garmin_link.dart`) has to fight it for the watch. This
// is the path Garmin made for companion apps: the ProjectFit Bridge app on the
// watch (`garmin-bridge/`) reads the watch's own stress, Body Battery, SpO2
// and daily steps and transmits them; Garmin's Connect IQ Mobile SDK
// (`ios/ConnectIQBridge/`) carries them here, alongside Garmin Connect.
//
// ONE SYNC: ask the watch app for everything newer than what is stored
// ({"cmd": "pull", "since": s}), store each message as it lands, finish on the
// app's "end" message or a timeout. Stored under [kCiqDeviceId] with the same
// vendor keys the direct link writes, so the Stress and Body Battery screens
// read either.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ble/adapters/garmin.dart' show kGarminAttribution;
import '../data/db.dart';
import '../data/observation.dart';

/// `observation.device_id` of everything this path stores.
const String kCiqDeviceId = 'garmin_ciq';

/// `SharedPreferences` key of the last [CiqSyncReport].
const String kCiqReportPref = 'connectiq_last_sync';

/// The watch app's message keys -> how they are stored.
const Map<String, ({String name, String unit, bool ours})> kCiqKinds = {
  'stress': (name: 'stress_level', unit: '', ours: false),
  'body_battery': (name: 'body_battery', unit: '%', ours: false),
  'spo2': (name: 'spo2', unit: '%', ours: false),
  'steps_day': (name: 'steps', unit: 'steps', ours: true),
};

@immutable
class CiqDevice {
  final String uuid, name, model;
  final bool connected;
  const CiqDevice(this.uuid, this.name, this.model, this.connected);

  static CiqDevice? from(Object? m) {
    if (m is! Map) return null;
    return CiqDevice(
      '${m['uuid'] ?? ''}',
      '${m['name'] ?? ''}',
      '${m['model'] ?? ''}',
      m['connected'] == true,
    );
  }

  String get label => name.isNotEmpty ? name : (model.isNotEmpty ? model : 'Garmin');
}

/// What the last sync did, for the device card.
@immutable
class CiqSyncReport {
  final int atMs;

  /// The watch app's answer to the ask: 'success', 'device_not_available',
  /// 'app_not_found', ... ; 'timeout' when the ask went out but no end came.
  final String outcome;
  final int stored;
  final bool ended;
  const CiqSyncReport(
      {required this.atMs, required this.outcome, required this.stored, required this.ended});

  bool get ok => outcome == 'success' && ended;

  Map<String, Object?> toJson() => {'at': atMs, 'outcome': outcome, 'stored': stored, 'ended': ended};

  static CiqSyncReport? fromJson(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, Object?>;
      return CiqSyncReport(
        atMs: m['at'] as int,
        outcome: m['outcome'] as String,
        stored: m['stored'] as int,
        ended: m['ended'] as bool,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<CiqSyncReport?> load() async =>
      fromJson((await SharedPreferences.getInstance()).getString(kCiqReportPref));
}

/// One watch-app message -> observations. Pure. Values outside a kind's
/// plausible range are dropped, never clamped.
@visibleForTesting
List<Observation> ciqObservations(Object? data) {
  if (data is! Map) return const [];
  final kind = kCiqKinds[data['k']];
  final d = data['d'];
  if (kind == null || d is! List) return const [];
  final out = <Observation>[];
  for (var i = 0; i + 1 < d.length; i += 2) {
    final t = d[i], v = d[i + 1];
    if (t is! num || v is! num) continue;
    if (!_plausible(data['k'] as String, v)) continue;
    out.add(Observation(
      at: DateTime.fromMillisecondsSinceEpoch(t.toInt() * 1000),
      sourceKind: ObservationSource.vendor,
      key: kind.ours ? kind.name : null,
      vendorKey: kind.ours ? null : kind.name,
      value: v,
      unit: kind.unit,
      attribution: kGarminAttribution,
    ));
  }
  return out;
}

bool _plausible(String k, num v) => switch (k) {
      'stress' || 'body_battery' => v >= 0 && v <= 100,
      'spo2' => v >= 70 && v <= 100,
      'steps_day' => v >= 0 && v <= 150000,
      _ => false,
    };

class ConnectIqLink {
  ConnectIqLink._();
  static final ConnectIqLink instance = ConnectIqLink._();

  static const MethodChannel _ch = MethodChannel('projectfit/connectiq');

  /// Ticks when the chosen watches or their connection change.
  final ValueNotifier<int> devicesRevision = ValueNotifier<int>(0);

  /// 0..1 while a sync runs, null otherwise.
  final ValueNotifier<double?> progress = ValueNotifier<double?>(null);

  bool _attached = false;
  Completer<void>? _end;
  int _stored = 0;

  bool get _supported => !kIsWeb && Platform.isIOS;

  /// Start listening to the native side. Idempotent; call once at launch.
  void attach() {
    if (_attached || !_supported) return;
    _attached = true;
    _ch.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'devicesChanged':
          devicesRevision.value++;
        case 'message':
          final args = call.arguments;
          if (args is Map) await _onMessage(args['data']);
      }
      return null;
    });
  }

  Future<void> _onMessage(Object? data) async {
    if (data is Map && data['k'] == 'end') {
      final e = _end;
      if (e != null && !e.isCompleted) e.complete();
      return;
    }
    final rows = ciqObservations(data);
    if (rows.isEmpty) return;
    try {
      _stored += await LocalDb.putObservations(rows, deviceId: kCiqDeviceId);
    } catch (e) {
      debugPrint('[connectiq] store: $e');
    }
    // A message arrived: creep toward the end without claiming it.
    final p = progress.value;
    if (p != null) progress.value = p + (0.9 - p) * 0.25;
  }

  Future<List<CiqDevice>> devices() async {
    if (!_supported) return const [];
    try {
      final raw = await _ch.invokeMethod<List<Object?>>('devices');
      return [for (final m in raw ?? const []) ?CiqDevice.from(m)];
    } on MissingPluginException {
      return const [];
    } catch (e) {
      debugPrint('[connectiq] devices: $e');
      return const [];
    }
  }

  Future<bool> configured() async => (await devices()).isNotEmpty;

  /// Opens Garmin Connect to pick the watch(es) to share; it comes back
  /// through the app's URL scheme and [devicesRevision] ticks.
  Future<void> selectDevices() async {
    if (!_supported) return;
    try {
      await _ch.invokeMethod<void>('selectDevices');
    } catch (e) {
      debugPrint('[connectiq] select: $e');
    }
  }

  /// Whether ProjectFit Bridge is on the first chosen watch: (installed,
  /// version), or null when the watch did not answer.
  Future<(bool, int)?> appStatus() async {
    if (!_supported) return null;
    try {
      final m = await _ch.invokeMethod<Map<Object?, Object?>>('appStatus');
      if (m == null) return null;
      return (m['installed'] == true, (m['version'] as num?)?.toInt() ?? 0);
    } catch (e) {
      debugPrint('[connectiq] app status: $e');
      return null;
    }
  }

  /// Ask the watch to open ProjectFit Bridge (it shows a prompt there).
  Future<String> openApp() async {
    if (!_supported) return 'unsupported';
    try {
      return await _ch.invokeMethod<String>('openApp') ?? 'failed';
    } catch (e) {
      return 'failed';
    }
  }

  bool _busy = false;

  /// Pull everything newer than what is stored. True when the watch app
  /// answered and finished. Serialised: a second call while one runs is a
  /// no-op that returns false.
  Future<bool> sync({Duration wait = const Duration(seconds: 45)}) async {
    if (_busy || !_supported) return false;
    _busy = true;
    attach();
    progress.value = 0;
    _stored = 0;
    final end = _end = Completer<void>();
    var outcome = 'failed';
    var ended = false;
    try {
      if (!await configured()) {
        outcome = 'no_device';
        return false;
      }
      final since = await _newestStoredSec();
      outcome = await _ch.invokeMethod<String>('pull', {'since': since}) ?? 'failed';
      if (outcome != 'success') return false;
      progress.value = 0.1;
      await end.future.timeout(wait);
      ended = true;
      return true;
    } on TimeoutException {
      return false;
    } catch (e) {
      debugPrint('[connectiq] sync: $e');
      return false;
    } finally {
      _end = null;
      try {
        await (await SharedPreferences.getInstance()).setString(
            kCiqReportPref,
            jsonEncode(CiqSyncReport(
              atMs: DateTime.now().millisecondsSinceEpoch,
              outcome: outcome,
              stored: _stored,
              ended: ended,
            ).toJson()));
      } catch (_) {}
      progress.value = null;
      _busy = false;
    }
  }

  /// Where the pull starts, in seconds: the OLDEST of each series' newest
  /// stored sample, so a run cut short after one series (the watch's
  /// background run sends a few messages at a time) still catches the
  /// others up. Rows already stored come back as the same rows. 0 = never.
  Future<int> _newestStoredSec() async {
    final ts = (await LocalDb.newestVendorTsByKey(kCiqDeviceId)).values;
    return ts.isEmpty ? 0 : ts.reduce((a, b) => a < b ? a : b) ~/ 1000;
  }
}
