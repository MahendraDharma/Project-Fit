// The sync pill at the top of Home: "Sync" at rest, "Syncing… 42%" while a
// full sync runs (band, derive, Garmin watch, Health — see
// `sync/full_sync.dart`), "Sync complete" with a tick for a few seconds
// after. The owner's reference was Bevel's: one place that says whether a
// sync is happening, how far it is, and that it ended.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../sync/full_sync.dart';
import '../ui2.dart';

class SyncPill extends StatelessWidget {
  /// A fixed state, for the gallery. Null follows the app's own sync.
  final SyncRun? run;
  const SyncPill({super.key, this.run});

  @override
  Widget build(BuildContext c) {
    final fixed = run;
    if (fixed != null) return _Pill(fixed, null);
    final FullSync sync;
    try {
      sync = c.read<AppState>().fullSync;
    } catch (_) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<SyncRun>(
      valueListenable: sync,
      builder: (c, r, _) => _Pill(r, sync.run),
    );
  }
}

class _Pill extends StatelessWidget {
  final SyncRun r;
  final VoidCallback? onTap;
  const _Pill(this.r, this.onTap);

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final (Widget lead, String text, Color? accent) = switch (r.phase) {
      SyncPhase.running => (
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              value: r.pct <= 0 ? null : r.pct,
              strokeWidth: 2,
              color: p.ink2,
              backgroundColor: p.line,
            ),
          ),
          l?.syncPillRunning(r.percent) ?? 'Syncing… ${r.percent}%',
          null,
        ),
      SyncPhase.done => (
          Icon(LucideIcons.circleCheck, size: 16, color: p.on(C.green)),
          l?.syncPillDone ?? 'Sync complete',
          C.green,
        ),
      SyncPhase.idle => (
          Icon(LucideIcons.refreshCw, size: 14, color: p.ink2),
          l?.syncPillIdle ?? 'Sync',
          null,
        ),
    };
    final body = AnimatedContainer(
      duration: motion(c, Motion.base),
      padding: const EdgeInsets.symmetric(horizontal: S.x3, vertical: S.x1 + 2),
      decoration: BoxDecoration(
        color: accent == null ? p.card : Color.alphaBlend(p.wash(accent), p.card),
        borderRadius: R.rPill,
        border: Border.all(color: accent == null ? p.line : p.on(accent).withValues(alpha: .35)),
      ),
      child: AnimatedSize(
        duration: motion(c, Motion.base),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          lead,
          const SizedBox(width: S.x2),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: F.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: accent == null ? p.ink : p.on(accent),
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        ]),
      ),
    );
    return Semantics(
      liveRegion: r.phase != SyncPhase.idle,
      child: r.running || onTap == null
          ? body
          : Pressable(onTap: onTap!, semanticLabel: text, child: body),
    );
  }
}
