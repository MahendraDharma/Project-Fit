// HEALTH SNAPSHOT — Garmin's two-minute still check, from the WHOOP band.
//
// Two minutes sitting still with the band streaming beat-to-beat intervals,
// then one dated entry: heart rate, HRV (RMSSD and SDNN), breathing rate from
// the heart's breathing rhythm (RSA), and stress on the same 0–100 scale as the
// Stress card (this window against your own nights). Garmin's snapshot also
// has SpO₂; the WHOOP 4.0 only has an overnight experiment, so it is left out
// rather than shown as a guess.
//
// Plumbing is reused, not rebuilt: the quiet window the breathing screen
// already owns turns the band's live HR stream on and buffers RR-bearing
// frames; `LocalRepository.spotCheck` decodes them off the UI isolate. A run
// whose beats are mostly artefact (moving, loose band) is refused and says so.
// History lives in preferences (last [kSnapshotKeep]) — no schema change.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:projectfit_analytics/onehz.dart' as ana;
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../state/prefs.dart';
import '../ui2.dart';
import 'home_screen.dart' show denseDays, pointsOf, repoOf;
import 'metric_detail.dart' show detailScaffold;

/// Seconds of recording, as Garmin's Health Snapshot.
const int kSnapshotSeconds = 120;

/// Least cleaned beats and clean share a snapshot needs to be a reading.
const int kSnapshotMinBeats = 60;
const double kSnapshotMinClean = 0.8;

const String kSnapshotPrefsKey = 'health_snapshots';
const int kSnapshotKeep = 30;

/// One finished snapshot, or why there is none. Pure: [spot] is
/// `spotCheck`'s map, [restRmssd] the median of recent nights (or null).
Map<String, dynamic>? snapshotOf(
    Map<String, dynamic> spot, double? restRmssd, int atSec) {
  if (spot['ok'] != true) return null;
  final beats = (spot['n_beats'] as num?)?.toInt() ?? 0;
  final clean = (spot['clean_fraction'] as num?)?.toDouble() ?? 0;
  final rmssd = (spot['rmssd'] as num?)?.toDouble();
  if (beats < kSnapshotMinBeats || clean < kSnapshotMinClean || rmssd == null) {
    return null;
  }
  return {
    't': atSec,
    'hr': spot['mean_hr'],
    'rmssd': rmssd.round(),
    'sdnn': spot['sdnn'],
    'resp': (spot['resp_brpm'] as num?)?.toDouble(),
    'stress': restRmssd == null
        ? null
        : ana.stressScoreOf(rmssd, restRmssd).round(),
    'beats': beats,
  };
}

List<Map<String, dynamic>> readSnapshots() {
  try {
    final raw = jsonDecode(Prefs.getString(kSnapshotPrefsKey, '[]'));
    return [for (final e in raw as List) (e as Map).cast<String, dynamic>()];
  } catch (_) {
    return const [];
  }
}

void _saveSnapshot(Map<String, dynamic> s) {
  final all = [s, ...readSnapshots()].take(kSnapshotKeep).toList();
  Prefs.setString(kSnapshotPrefsKey, jsonEncode(all));
}

enum _Phase { idle, recording, computing, done, failed }

class HealthSnapshotScreen extends StatefulWidget {
  const HealthSnapshotScreen({super.key});

  @override
  State<HealthSnapshotScreen> createState() => _HealthSnapshotState();
}

class _HealthSnapshotState extends State<HealthSnapshotScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => _tick());
  _Phase _phase = _Phase.idle;
  DateTime? _startedAt;
  Map<String, dynamic>? _result;
  String? _why;
  List<Map<String, dynamic>> _history = readSnapshots();

  int get _elapsed => _startedAt == null
      ? 0
      : DateTime.now().difference(_startedAt!).inSeconds;

  void _tick() {
    if (_phase != _Phase.recording) return;
    if (_elapsed >= kSnapshotSeconds) {
      _finish();
    } else {
      setState(() {});
    }
  }

  Future<void> _start() async {
    final app = context.read<AppState>();
    final l = AppLocalizations.of(context);
    if (!app.isConnected) {
      setState(() {
        _phase = _Phase.failed;
        _why = l?.snapshotNotConnected ?? 'Connect your band first.';
      });
      return;
    }
    await app.openBreathingWindow();
    if (!mounted) return;
    if (!app.breathingWindowOpen) {
      setState(() {
        _phase = _Phase.failed;
        _why = l?.snapshotBusy ??
            'The band is busy with a breathing session. Try again after it.';
      });
      return;
    }
    setState(() {
      _phase = _Phase.recording;
      _startedAt = DateTime.now();
      _result = null;
      _why = null;
    });
    _ticker.start();
  }

  Future<void> _finish() async {
    _ticker.stop();
    final app = context.read<AppState>();
    final repo = repoOf(context);
    final l = AppLocalizations.of(context);
    final frames = app.takeQuietWindowFrames();
    setState(() => _phase = _Phase.computing);
    Map<String, dynamic>? snap;
    try {
      final spot = repo == null
          ? const <String, dynamic>{}
          : await repo.spotCheck(frames);
      final nights = repo == null
          ? const <double?>[]
          : denseDays(pointsOf(await repo.getChart('hrv')), 15);
      snap = snapshotOf(spot, ana.restReferenceRmssd(nights),
          DateTime.now().millisecondsSinceEpoch ~/ 1000);
    } catch (_) {
      snap = null;
    }
    if (!mounted) return;
    if (snap == null) {
      setState(() {
        _phase = _Phase.failed;
        _why = l?.snapshotUnreadable ??
            'Not enough clean beats to read. Sit still with the band snug on '
                'your wrist and try again.';
      });
      return;
    }
    _saveSnapshot(snap);
    setState(() {
      _phase = _Phase.done;
      _result = snap;
      _history = readSnapshots();
    });
  }

  Future<void> _abort() async {
    _ticker.stop();
    if (_phase == _Phase.recording) {
      await context.read<AppState>().closeBreathingWindow();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    final p = P.of(c);
    final recording = _phase == _Phase.recording;
    return PopScope(
      canPop: !recording,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !recording) return;
        await _abort();
        if (c.mounted) Navigator.of(c).maybePop();
      },
      child: detailScaffold(c, l?.snapshotTitle ?? 'Health Snapshot', [
        Text(
          l?.snapshotIntro ??
              'Two minutes sitting still. The band records every beat, then '
                  'this saves your heart rate, heart-rate variability, '
                  'breathing rate and stress as one entry.',
          style: F.body.copyWith(color: p.ink2, height: 1.5),
        ),
        const SizedBox(height: S.x4),
        if (recording) _recording(c, p, l) else _action(c, l),
        if (_phase == _Phase.failed && _why != null) ...[
          const SizedBox(height: S.x3),
          StatusCard(l?.snapshotFailedTitle ?? 'No snapshot this time', _why!,
              icon: LucideIcons.triangleAlert),
        ],
        if (_result != null) ...[
          const SizedBox(height: S.x4),
          SnapshotCard(_result!),
        ],
        if (_history.length > (_result == null ? 0 : 1)) ...[
          const SizedBox(height: S.x5),
          Text(l?.snapshotHistory ?? 'Earlier snapshots',
              style: F.head.copyWith(color: p.ink)),
          const SizedBox(height: S.x2),
          for (final s in _history.skip(_result == null ? 0 : 1)) ...[
            SnapshotCard(s, compact: true),
            const SizedBox(height: S.x2),
          ],
        ],
        const SizedBox(height: S.x3),
        Text(
          l?.snapshotFootnote ??
              'Stress uses the same scale as the Stress card: as calm as your '
                  'nights reads 0. No blood oxygen: the band only has an '
                  'overnight experiment for it.',
          style: F.cap.copyWith(color: p.ink3),
        ),
      ]),
    );
  }

  Widget _action(BuildContext c, AppLocalizations? l) => BigButton(
        _phase == _Phase.computing
            ? (l?.snapshotReading ?? 'Reading…')
            : (l?.snapshotStart ?? 'Start a 2-minute snapshot'),
        icon: LucideIcons.heartPulse,
        color: C.green,
        busy: _phase == _Phase.computing,
        onTap: _phase == _Phase.computing ? null : _start,
      );

  Widget _recording(BuildContext c, P p, AppLocalizations? l) {
    final left = (kSnapshotSeconds - _elapsed).clamp(0, kSnapshotSeconds);
    final hr = context.watch<AppState>().liveHr;
    return Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}',
            style: F.n34.copyWith(color: p.ink)),
        const SizedBox(height: S.x2),
        ClipRRect(
          borderRadius: R.rPill,
          child: LinearProgressIndicator(
            value: _elapsed / kSnapshotSeconds,
            minHeight: 8,
            backgroundColor: p.track,
            color: p.on(C.green),
          ),
        ),
        const SizedBox(height: S.x3),
        Text(
          hr == null
              ? (l?.snapshotStayStill ?? 'Stay still and breathe normally.')
              : (l?.snapshotLiveHr('$hr') ??
                  '$hr bpm · stay still and breathe normally.'),
          style: F.body.copyWith(color: p.ink2),
        ),
        const SizedBox(height: S.x3),
        TextButton(
          onPressed: () async {
            await _abort();
            if (mounted) setState(() => _phase = _Phase.idle);
          },
          child: Text(l?.snapshotCancel ?? 'Cancel'),
        ),
      ]),
    );
  }
}

/// One snapshot's numbers. [compact] is the history row.
class SnapshotCard extends StatelessWidget {
  final Map<String, dynamic> s;
  final bool compact;
  const SnapshotCard(this.s, {super.key, this.compact = false});

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    final p = P.of(c);
    final t = DateTime.fromMillisecondsSinceEpoch(
        ((s['t'] as num?) ?? 0).toInt() * 1000);
    final when = '${t.day}/${t.month} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    String v(Object? x, [int dp = 0]) =>
        x is num ? (dp == 0 ? '${x.round()}' : x.toStringAsFixed(dp)) : '—';
    final cells = [
      (l?.snapshotHr ?? 'Heart rate', '${v(s['hr'])} bpm'),
      (l?.snapshotHrv ?? 'HRV', '${v(s['rmssd'])} ms'),
      (l?.snapshotResp ?? 'Breathing', '${v(s['resp'], 1)} /min'),
      (l?.snapshotStress ?? 'Stress', v(s['stress'])),
    ];
    return Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(when, style: (compact ? F.cap : F.head).copyWith(color: p.ink)),
        const SizedBox(height: S.x2),
        Wrap(spacing: S.x5, runSpacing: S.x2, children: [
          for (final (label, value) in cells)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: F.cap.copyWith(color: p.ink3)),
              Text(value,
                  style: (compact ? F.body : F.head).copyWith(color: p.ink)),
            ]),
        ]),
      ]),
    );
  }
}
