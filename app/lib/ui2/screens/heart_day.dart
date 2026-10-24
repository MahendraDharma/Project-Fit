// The day's heart rate as its own screen: the curve and its zones, the day's
// figures, and the resting heart rate and HRV trends behind them. What
// "Today's heart rate" on Home opens — not the strain screen.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/day_label.dart';
import '../../l10n/app_localizations.dart';
import '../ui2.dart';
import 'detail_v4.dart';
import 'home_screen.dart' show repoOf;
import 'home_vitals.dart';
import 'metric_detail.dart' show dayNavRow, detailScaffold;

class HeartRateDayScreen extends StatefulWidget {
  /// The day to open. Null is today.
  final String? day;
  final HomeVitals? data;
  const HeartRateDayScreen({super.key, this.day, this.data});

  @override
  State<HeartRateDayScreen> createState() => _HeartRateDayScreenState();
}

class _HeartRateDayScreenState extends State<HeartRateDayScreen> {
  HomeVitals? _v;
  late String _day = widget.day ?? todayLabel();
  List<String> _days = const [];

  @override
  void initState() {
    super.initState();
    _v = widget.data;
    if (_v == null) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repo = repoOf(context);
    if (repo == null) return;
    try {
      final v = await HomeVitals.load(repo, _day);
      var days = _days;
      try {
        days = await repo.availableDays();
      } catch (_) {}
      if (mounted) setState(() => (_v = v, _days = days));
    } catch (_) {}
  }

  void _goDay(String d) {
    setState(() => _day = d);
    _load();
  }

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    final v = _v;
    return detailScaffold(c, l?.homeHeartTitle ?? 'Today\'s heart rate', [
      ...dayNavRow(_day, _days, _goDay),
      if (v == null)
        const Padding(
          padding: EdgeInsets.only(top: S.x8),
          child: Center(child: CircularProgressIndicator()),
        )
      else ...[
        DetailTiles([
          if (v.hrAvg != null)
            DetailTile(icon: LucideIcons.heartPulse, label: l?.detailAvgHr ?? 'Average HR', value: '${v.hrAvg}', unit: 'bpm'),
          if (v.rhr != null)
            DetailTile(icon: LucideIcons.heart, label: l?.detailRestingHr ?? 'Resting HR', value: '${v.rhr!.round()}', unit: 'bpm'),
        ]),
        const SizedBox(height: S.x3),
        if (v.hasHeart)
          DayHeartCard(v)
        else
          StatusCard(l?.hrDayNoneTitle ?? 'No heart rate for this day',
              l?.hrDayNoneBody ?? 'Nothing was recorded from the band on this day.',
              icon: LucideIcons.heart),
        TrendSection(const [(key: 'resting_hr', ext: null), (key: 'hrv', ext: null)],
            key: ValueKey('t$_day'), until: _day),
      ],
    ]);
  }
}
