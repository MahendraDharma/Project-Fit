// What the last session with the paired Garmin watch did, on the watch's own
// page: when it ran, how many of the watch's new health files were read, and
// — one tap down — its log, with a copy button.
//
// The Garmin link has never met a real watch (`ble/garmin_link.dart`, R6).
// When its cards stay empty, "it doesn't work" cannot say whether the connect,
// the channel or the files failed; this card can, and the copied log is what
// gets the next fix right.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ble/garmin_link.dart';
import '../../l10n/app_localizations.dart';
import '../ui2.dart';
import 'devices.dart' show formatDayTime;
import 'profile.dart' show SetRow;

class GarminSessionCard extends StatefulWidget {
  /// A fixed report, for the gallery. Null reads the stored one and re-reads
  /// it whenever a session ends.
  final GarminSyncReport? report;
  const GarminSessionCard({super.key, this.report});

  @override
  State<GarminSessionCard> createState() => _GarminSessionCardState();
}

class _GarminSessionCardState extends State<GarminSessionCard> {
  GarminSyncReport? _r;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _r = widget.report;
    if (_r == null) {
      _load();
      GarminLink.instance.progress.addListener(_onProgress);
    }
  }

  void _onProgress() {
    // null again = the session ended and its report is written.
    if (GarminLink.instance.progress.value == null) _load();
  }

  Future<void> _load() async {
    final r = await GarminSyncReport.load();
    if (mounted) setState(() => _r = r);
  }

  @override
  void dispose() {
    if (widget.report == null) GarminLink.instance.progress.removeListener(_onProgress);
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final r = _r;
    if (r == null) return const SizedBox.shrink();
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final when = formatDayTime(DateTime.fromMillisecondsSinceEpoch(r.atMs), l);
    final good = r.ok && r.listed >= 0;
    final sub = r.listed < 0
        ? (l?.garminNoFileList ??
            'The watch did not send its file list, so nothing was read.')
        : (l?.garminFilesRead(r.read, r.listed) ??
            '${r.read} of ${r.listed} new health files read');
    final log = r.lines.join('\n');
    return Surface(
      pad: const EdgeInsets.symmetric(horizontal: S.x4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SetRow(good ? LucideIcons.circleCheck : LucideIcons.circleAlert,
            good ? C.green : C.orange, l?.garminLastSession(when) ?? 'Last sync: $when',
            sub: sub, chevron: false),
        Divider(color: p.line, height: 1),
        SetRow(LucideIcons.scrollText, C.blue, l?.garminSessionDetails ?? 'Sync details',
            value: _open ? '−' : '+',
            chevron: false,
            onTap: () => setState(() => _open = !_open)),
        if (_open) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: S.x3),
            child: SelectableText(log, style: F.cap.copyWith(color: p.ink2)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(LucideIcons.copy, size: 16),
              label: Text(l?.garminCopyDetails ?? 'Copy details'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: log));
                if (!c.mounted) return;
                ScaffoldMessenger.maybeOf(c)?.showSnackBar(
                    SnackBar(content: Text(l?.garminDetailsCopied ?? 'Copied.')));
              },
            ),
          ),
          const SizedBox(height: S.x2),
        ],
      ]),
    );
  }
}
