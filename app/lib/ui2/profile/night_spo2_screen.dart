// Devices → the band → "Night SpO2": the unattended nightly red/IR recording
// (state/night_optics_recorder.dart) and its calibration against the Garmin
// watch's own SpO2 (ble/night_optics.dart). No percentage is shown until the
// person's own pairs support a fit.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../ble/night_optics.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../state/night_optics_recorder.dart';
import '../screens/metric_detail.dart' show detailScaffold;
import '../ui2.dart';

class NightSpo2Screen extends StatefulWidget {
  const NightSpo2Screen({super.key});

  @override
  State<NightSpo2Screen> createState() => _NightSpo2ScreenState();
}

class _NightData {
  final Map<String, List<OpticWindow>> nights;
  final List<({int atMs, double spo2})> refs;
  final List<CalPair> pairs;
  final CalibrationResult cal;
  const _NightData(this.nights, this.refs, this.pairs, this.cal);
}

class _NightSpo2ScreenState extends State<NightSpo2Screen> {
  Future<_NightData>? _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= _load();
  }

  Future<_NightData> _load() async {
    NightOpticsRecorder? rec;
    try {
      rec = context.read<AppState>().nightOptics;
    } catch (_) {}
    final nights = rec == null ? <String, List<OpticWindow>>{} : await rec.loadNights();
    final all = [for (final w in nights.values) ...w];
    var refs = <({int atMs, double spo2})>[];
    if (all.isNotEmpty) {
      final from = all.map((w) => w.atMs).reduce((a, b) => a < b ? a : b) - 600000;
      final to = all.map((w) => w.atMs).reduce((a, b) => a > b ? a : b) + 600000;
      try {
        refs = await NightOpticsRecorder.garminSpo2(from, to);
      } catch (_) {}
    }
    final pairs = pairWithReference(all, refs);
    return _NightData(nights, refs, pairs, fitCalibration(pairs));
  }

  Future<void> _share(BuildContext c, _NightData d) async {
    final box = c.findRenderObject() as RenderBox?;
    final body = jsonEncode({
      'kind': 'projectfit-night-optics',
      'v': 1,
      'nights': {
        for (final e in d.nights.entries) e.key: [for (final w in e.value) w.toJson()]
      },
      'garmin_spo2': [for (final r in d.refs) {'t': r.atMs, 'v': r.spo2}],
    });
    await Share.shareXFiles(
      [
        XFile.fromData(Uint8List.fromList(utf8.encode(body)),
            mimeType: 'application/json', name: 'projectfit-night-spo2.json'),
      ],
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    NightOpticsRecorder? rec;
    try {
      rec = context.watch<AppState>().nightOptics;
    } catch (_) {}
    final body = <Widget>[
      Text(
          l?.nightSpo2Intro ??
              'Every night from 21:00 to 09:00 the band\'s red and infrared light is scored '
                  'every 30 seconds while you lie still. The app compares it with the SpO2 '
                  'your Garmin watch measures the same night, and shows a percentage only '
                  'once enough nights agree.',
          style: F.body.copyWith(color: p.ink2)),
      const SizedBox(height: S.x5),
    ];
    if (rec != null) {
      final r = rec;
      body.addAll([
        Surface(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(l?.nightSpo2Auto ?? 'Record automatically every night',
                    style: F.t2.copyWith(color: p.ink)),
              ),
              Switch(value: r.enabled, onChanged: (v) => r.setEnabled(v)),
            ]),
            const SizedBox(height: S.x2),
            Text(
                r.active
                    ? (l?.nightSpo2Recording(r.good, r.windows) ??
                        'Recording now · ${r.good} of ${r.windows} windows usable')
                    : (l?.nightSpo2Waiting ??
                        'Starts by itself after 21:00 while the band is connected'),
                style: F.body.copyWith(color: r.active ? p.on(C.green) : p.ink2)),
          ]),
        ),
        const SizedBox(height: S.x4),
      ]);
    }
    body.add(FutureBuilder<_NightData>(
      future: _data,
      builder: (bc, snap) {
        final d = snap.data;
        if (d == null) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _calibrationCard(bc, d),
          const SizedBox(height: S.x4),
          if (d.nights.isNotEmpty) ...[
            Surface(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l?.nightSpo2Nights ?? 'Nights', style: F.t2.copyWith(color: p.ink)),
                const SizedBox(height: S.x2),
                for (final e in d.nights.entries.toList().reversed.take(7))
                  Padding(
                    padding: const EdgeInsets.only(top: S.x1),
                    child: Text(
                        '${e.key} · ${l?.nightSpo2Usable(e.value.where((w) => w.ok).length, e.value.length) ?? '${e.value.where((w) => w.ok).length} of ${e.value.length} usable'}',
                        style: F.body.copyWith(color: p.ink2)),
                  ),
              ]),
            ),
            const SizedBox(height: S.x4),
            Builder(
              builder: (sc) => BigButton(l?.nightSpo2Share ?? 'Share the data',
                  icon: LucideIcons.share2, onTap: () => _share(sc, d)),
            ),
          ],
        ]);
      },
    ));
    body.addAll([
      const SizedBox(height: S.x4),
      Text(
          l?.nightSpo2Tip ??
              'On the Garmin watch, turn Pulse Ox on during sleep, and sync the watch in '
                  'the morning. Wear the WHOOP snug.',
          style: F.cap.copyWith(color: p.ink2)),
    ]);
    return detailScaffold(c, l?.nightSpo2Title ?? 'Night SpO2', body);
  }

  Widget _calibrationCard(BuildContext c, _NightData d) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final cal = d.cal;
    final lines = <Widget>[
      Text(l?.nightSpo2Calibration ?? 'Calibration with Garmin',
          style: F.t2.copyWith(color: p.ink)),
      const SizedBox(height: S.x2),
    ];
    switch (cal) {
      case CalibrationPending(:final reason, :final pairs):
        lines.add(Text(
            switch (reason) {
              'spread' => l?.nightSpo2PendingSpread(pairs) ??
                  '$pairs pairs, but the Garmin readings barely vary yet. More nights are needed.',
              'fit' => l?.nightSpo2PendingFit(pairs) ??
                  '$pairs pairs, but the band does not follow the Garmin readings closely enough yet.',
              _ => l?.nightSpo2PendingPairs(pairs, kMinCalPairs) ??
                  '$pairs of $kMinCalPairs readings paired so far.',
            },
            style: F.body.copyWith(color: p.ink2)));
      case CalibrationReady(cal: final k):
        final last = d.nights.isEmpty ? null : d.nights.values.last.where((w) => w.ok).toList();
        lines.add(Text(
            l?.nightSpo2Ready(k.pairs, (k.r2 * 100).round()) ??
                'Calibrated from ${k.pairs} readings (fit ${(k.r2 * 100).round()}%).',
            style: F.body.copyWith(color: p.ink2)));
        if (last != null && last.isNotEmpty) {
          final v = [for (final w in last) k.spo2(w.r)]..sort();
          final median = v[v.length ~/ 2], low = v[(v.length * 0.05).floor()];
          lines.addAll([
            const SizedBox(height: S.x3),
            Text(
                l?.nightSpo2LastNight(median.round(), low.round()) ??
                    'Last night ≈ ${median.round()}% (lowest ≈ ${low.round()}%)',
                style: F.t2.copyWith(color: p.ink)),
          ]);
        }
    }
    return Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines));
  }
}
