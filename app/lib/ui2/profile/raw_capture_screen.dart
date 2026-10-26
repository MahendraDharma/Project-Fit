// Devices → the band → "Record raw data": a bounded capture of every live
// frame, saved to a file the owner can share (lib/ble/raw_capture.dart).
// Research only — the groundwork for finding the band's optical and
// temperature channels; nothing in the app is scored from a capture.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../ble/raw_capture.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../screens/metric_detail.dart' show detailScaffold;
import '../ui2.dart';

const List<int> kRawCaptureMinutes = [1, 5, 10];

class RawCaptureScreen extends StatefulWidget {
  const RawCaptureScreen({super.key});

  @override
  State<RawCaptureScreen> createState() => _RawCaptureScreenState();
}

class _RawCaptureScreenState extends State<RawCaptureScreen> {
  int _minutes = 5;
  RawCapture? _c;
  Timer? _tick;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    try {
      final running = context.read<AppState>().rawCapture;
      if (running != null && (running.running || running.finished)) {
        _c = running;
        if (running.running) _startTicking();
      }
    } catch (_) {}
  }

  void _startTicking() {
    _tick?.cancel();
    _tick = Timer.periodic(Motion.tick, (_) {
      final c = _c;
      if (c == null || !mounted) return;
      if (c.timeUp) {
        _stop();
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _start() async {
    final app = context.read<AppState>();
    setState(() => _starting = true);
    final c = await app.startRawCapture(_minutes);
    if (!mounted) return;
    setState(() {
      _c = c;
      _starting = false;
    });
    _startTicking();
  }

  void _stop() {
    _tick?.cancel();
    try {
      context.read<AppState>().stopRawCapture();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _share(BuildContext c, RawCapture cap) async {
    final box = c.findRenderObject() as RenderBox?;
    await Share.shareXFiles(
      [
        XFile.fromData(Uint8List.fromList(utf8.encode(cap.toJsonl())),
            mimeType: 'application/x-ndjson', name: cap.fileName),
      ],
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _clock(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    bool connected;
    try {
      connected = c.select<AppState, bool>((a) => a.isConnected);
    } catch (_) {
      connected = false;
    }
    final cap = _c;
    final body = <Widget>[
      Text(
          l?.rawIntro ??
              'Records every live frame the band sends — optical, motion and heart rate — '
                  'exactly as it arrives, and saves it as a file you can share.',
          style: F.body.copyWith(color: p.ink2)),
      const SizedBox(height: S.x5),
    ];
    if (cap == null || (!cap.running && !cap.finished)) {
      body.addAll([
        Wrap(spacing: S.x2, runSpacing: S.x2, children: [
          for (final m in kRawCaptureMinutes)
            Pressable(
              onTap: () => setState(() => _minutes = m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: S.x4, vertical: S.x2),
                decoration: BoxDecoration(
                  color: m == _minutes ? p.wash(C.purple) : p.card,
                  borderRadius: R.rPill,
                  border: Border.all(color: m == _minutes ? p.on(C.purple) : p.line),
                ),
                child: Text(l?.rawMinutes(m) ?? '$m min',
                    style: F.body.copyWith(color: m == _minutes ? p.on(C.purple) : p.ink)),
              ),
            ),
        ]),
        const SizedBox(height: S.x5),
        if (!connected)
          Padding(
            padding: const EdgeInsets.only(bottom: S.x3),
            child: Text(l?.rawNotConnected ?? 'Connect the band first, then start.',
                style: F.cap.copyWith(color: p.on(C.orange))),
          ),
        BigButton(l?.rawStart ?? 'Start recording',
            icon: LucideIcons.circleDot,
            color: C.red,
            busy: _starting,
            onTap: connected && !_starting ? _start : null),
      ]);
    } else {
      final counts = cap.counts;
      body.addAll([
        Surface(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                cap.running
                    ? (l?.rawRecording(_clock(cap.secondsLeft)) ??
                        'Recording… ${_clock(cap.secondsLeft)} left')
                    : (l?.rawDone ?? 'Recording saved'),
                style: F.t2.copyWith(color: p.ink)),
            const SizedBox(height: S.x2),
            Text(l?.rawFrames(cap.frames) ?? '${cap.frames} frames',
                style: F.body.copyWith(color: p.ink2)),
            const SizedBox(height: S.x2),
            Wrap(spacing: S.x2, runSpacing: S.x2, children: [
              for (final e in counts.entries)
                Pill('0x${e.key.toRadixString(16).toUpperCase()} · ${e.value}', C.blue),
            ]),
          ]),
        ),
        const SizedBox(height: S.x5),
        if (cap.running)
          BigButton(l?.rawStopSave ?? 'Stop and save',
              icon: LucideIcons.square, color: C.orange, onTap: _stop)
        else
          Builder(
            builder: (bc) => BigButton(l?.rawShare ?? 'Share the file',
                icon: LucideIcons.share2, onTap: () => _share(bc, cap)),
          ),
      ]);
    }
    return detailScaffold(c, l?.rawTitle ?? 'Record raw data', body);
  }
}
