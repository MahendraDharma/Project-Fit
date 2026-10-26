// The Garmin watch through Connect IQ, on the Devices screen: pick the watch
// in Garmin Connect, see whether ProjectFit Bridge is on it, sync, and what
// the last sync did. See lib/garmin/connectiq_link.dart.
//
// iPhone only (the Connect IQ Mobile SDK bridge is iOS); elsewhere, and on a
// phone with nothing to show, the card is absent.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../garmin/connectiq_link.dart';
import '../../l10n/app_localizations.dart';
import '../ui2.dart';
import 'devices.dart' show formatDayTime;
import 'profile.dart' show SetRow;

const String kCiqGuideUrl =
    'https://github.com/MahendraDharma/Project-Fit/blob/main/docs/GARMIN_BRIDGE.md';

/// A fixed state, for the gallery.
typedef CiqPreview = ({List<CiqDevice> devices, (bool, int)? app, CiqSyncReport? report});

class GarminConnectIqCard extends StatefulWidget {
  final CiqPreview? preview;
  const GarminConnectIqCard({super.key, this.preview});

  @override
  State<GarminConnectIqCard> createState() => _GarminConnectIqCardState();
}

class _GarminConnectIqCardState extends State<GarminConnectIqCard> {
  List<CiqDevice> _devices = const [];
  (bool, int)? _app;
  CiqSyncReport? _report;
  bool _syncing = false;

  bool get _live => widget.preview == null;

  @override
  void initState() {
    super.initState();
    final pv = widget.preview;
    if (pv != null) {
      _devices = pv.devices;
      _app = pv.app;
      _report = pv.report;
      return;
    }
    if (kIsWeb || !Platform.isIOS) return;
    ConnectIqLink.instance.devicesRevision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    if (_live) ConnectIqLink.instance.devicesRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final d = await ConnectIqLink.instance.devices();
    final r = await CiqSyncReport.load();
    if (!mounted) return;
    setState(() {
      _devices = d;
      _report = r;
    });
    if (d.isNotEmpty) {
      final a = await ConnectIqLink.instance.appStatus();
      if (mounted) setState(() => _app = a);
    }
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    await ConnectIqLink.instance.sync();
    if (!mounted) return;
    setState(() => _syncing = false);
    _load();
  }

  String _reason(AppLocalizations? l, CiqSyncReport r) => switch (r.outcome) {
        'device_not_available' || 'no_device' =>
          l?.ciqReasonNotAvailable ?? 'the watch is out of reach',
        'app_not_found' => l?.ciqReasonAppMissing ?? 'ProjectFit is not on the watch',
        'success' => l?.ciqReasonNoAnswer ?? 'the watch did not send its data back in time',
        _ => l?.ciqReasonOther(r.outcome) ?? 'the watch refused (${r.outcome})',
      };

  @override
  Widget build(BuildContext c) {
    if (_live && (kIsWeb || !Platform.isIOS)) return const SizedBox.shrink();
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final guide = SetRow(LucideIcons.bookOpen, C.blue,
        l?.ciqInstallGuide ?? 'How to put ProjectFit on the watch',
        onTap: () => launchUrl(Uri.parse(kCiqGuideUrl), mode: LaunchMode.externalApplication));
    final choose = SetRow(LucideIcons.watch, C.green,
        _devices.isEmpty
            ? (l?.ciqChooseWatch ?? 'Choose the watch in Garmin Connect')
            : (l?.ciqChooseAgain ?? 'Choose again in Garmin Connect'),
        onTap: ConnectIqLink.instance.selectDevices);
    final rows = <Widget>[];
    if (_devices.isEmpty) {
      rows.addAll([
        Padding(
          padding: const EdgeInsets.symmetric(vertical: S.x3),
          child: Text(
              l?.ciqIntro ??
                  'Brings in your watch\'s stress, Body Battery, SpO₂ and steps while Garmin '
                      'Connect keeps working as usual.',
              style: F.body.copyWith(color: p.ink2)),
        ),
        Divider(color: p.line, height: 1),
        guide,
        Divider(color: p.line, height: 1),
        choose,
      ]);
    } else {
      final d = _devices.first;
      final app = _app;
      final r = _report;
      rows.addAll([
        SetRow(LucideIcons.watch, d.connected ? C.green : C.orange, d.label,
            sub: d.connected
                ? (l?.ciqConnected ?? 'Connected')
                : (l?.ciqNotConnected ?? 'Not connected right now'),
            chevron: false),
        Divider(color: p.line, height: 1),
        SetRow(
          app?.$1 == true ? LucideIcons.circleCheck : LucideIcons.circleAlert,
          app?.$1 == true ? C.green : C.orange,
          app == null
              ? (l?.ciqAppUnknown ?? 'The watch did not answer')
              : app.$1
                  ? (l?.ciqAppInstalled(app.$2) ?? 'ProjectFit is on the watch (version ${app.$2})')
                  : (l?.ciqAppMissing ?? 'ProjectFit is not on the watch yet'),
          chevron: false,
        ),
        if (app?.$1 != true) ...[Divider(color: p.line, height: 1), guide],
        Divider(color: p.line, height: 1),
        SetRow(LucideIcons.refreshCw, C.purple, l?.ciqSyncNow ?? 'Sync now',
            sub: r == null
                ? ''
                : r.ok
                    ? (l?.ciqLastSyncOk(formatDayTime(DateTime.fromMillisecondsSinceEpoch(r.atMs), l), r.stored) ??
                        'Last sync: ${r.stored} readings')
                    : (l?.ciqLastSyncFailed(
                            formatDayTime(DateTime.fromMillisecondsSinceEpoch(r.atMs), l), _reason(l, r)) ??
                        'Last sync did not finish: ${_reason(l, r)}'),
            trailing: _syncing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: p.ink3))
                : null,
            onTap: _syncing || !_live ? null : _sync),
        Divider(color: p.line, height: 1),
        SetRow(LucideIcons.smartphone, C.teal, l?.ciqOpenOnWatch ?? 'Open ProjectFit on the watch',
            onTap: ConnectIqLink.instance.openApp),
        Divider(color: p.line, height: 1),
        choose,
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text((l?.ciqTitle ?? 'Garmin watch (with Garmin Connect)').toUpperCase(),
          style: F.over.copyWith(color: p.ink3)),
      const SizedBox(height: S.x3),
      Surface(
        pad: const EdgeInsets.symmetric(horizontal: S.x4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
      ),
    ]);
  }
}
