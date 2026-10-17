// MONTHLY REPORT — the last 30 days against the 30 before them.
//
// The WHOOP-style monthly assessment, reduced to the one question it can answer
// honestly: did anything actually move? Each metric's two 30-day means are
// compared with analytics `periodChange`, which calls a change only when it
// exceeds the smallest worthwhile change (0.2 × the earlier month's day-to-day
// SD, Hopkins 2004). Everything else is "steady", which is the common answer.
//
// NO VERDICT COLOUR, for the same reason as What Changed: an arrow says which
// way, never whether that is good. A metric short of data in either month says
// how many days it has instead of a number.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:projectfit_analytics/onehz.dart'
    show PeriodChange, periodChange, periodChangeMinDays;

import '../../data/local_repository.dart';
import '../../l10n/app_localizations.dart';
import '../ui2.dart';
import 'home_screen.dart' show denseDays, pointsOf, repoOf;
import 'metric_detail.dart' show detailScaffold, specOf;

/// Metrics in the report, in the order a day is lived.
const List<String> kMonthlyMetrics = [
  'sleep',
  'readiness',
  'hrv',
  'resting_hr',
  'resp_rate',
  'strain',
  'steps',
];

/// Days per period.
const int kMonthDays = 30;

/// One metric's row: the comparison, or how many days each month has.
class MonthlyRow {
  final String key;
  final PeriodChange? change;
  final int previousDays;
  final int currentDays;
  const MonthlyRow(this.key, this.change,
      {required this.previousDays, required this.currentDays});
}

/// One metric's row from a dense 60-day window (oldest first). PURE.
MonthlyRow monthlyRow(String key, List<double?> sixtyDays) {
  final prev = sixtyDays.sublist(0, kMonthDays);
  final cur = sixtyDays.sublist(kMonthDays);
  final m = periodChange(prev, cur);
  return MonthlyRow(key, m.value,
      previousDays: prev.where((v) => v != null).length,
      currentDays: cur.where((v) => v != null).length);
}

/// Every row, loaded: one `getChart` per metric, the read the trend cards do.
Future<List<MonthlyRow>> loadMonthlyRows(LocalRepository repo) async {
  final out = <MonthlyRow>[];
  for (final key in kMonthlyMetrics) {
    try {
      final points = pointsOf(await repo.getChart(specOf(key).chartKey));
      out.add(monthlyRow(key, denseDays(points, 2 * kMonthDays)));
    } catch (_) {/* a series we cannot read is a row we do not draw */}
  }
  return out;
}

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key, this.rows});

  /// Injected rows (tests, gallery); loaded from the repository when null.
  final List<MonthlyRow>? rows;

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  List<MonthlyRow>? _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.rows;
    if (_rows == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    final repo = repoOf(context);
    final rows = repo == null ? <MonthlyRow>[] : await loadMonthlyRows(repo);
    if (mounted) setState(() => _rows = rows);
  }

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    final rows = _rows;
    return detailScaffold(
        c, l?.monthlyReportTitle ?? 'Your month',
        sub: l?.monthlyReportSub ?? 'LAST 30 DAYS AGAINST THE 30 BEFORE', [
      if (rows == null) ...[
        const SizedBox(height: S.x8),
        const Center(child: CircularProgressIndicator()),
      ] else ...[
        for (final r in rows) ...[
          MonthlyRowTile(r),
          const SizedBox(height: S.x2),
        ],
        const SizedBox(height: S.x2),
        Text(
          l?.monthlyReportFootnote ??
              'A change is named only when it is bigger than 0.2 of your usual '
                  'day-to-day spread in the earlier month (Hopkins). Smaller '
                  'differences are day-to-day noise and read as steady.',
          style: F.cap.copyWith(color: P.of(c).ink3),
        ),
      ],
    ]);
  }
}

/// One metric's month: the current mean, the earlier one, and which way it
/// moved — or how many days each month has when that is too few.
class MonthlyRowTile extends StatelessWidget {
  const MonthlyRowTile(this.r, {super.key});
  final MonthlyRow r;

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final spec = specOf(r.key);
    final ch = r.change;
    String fmt(double v) =>
        v.abs() >= 100 ? v.round().toString() : v.toStringAsFixed(1);
    final unit = spec.unit.isEmpty ? '' : ' ${spec.unit}';

    final String main, detail;
    final IconData icon;
    if (ch == null) {
      final have = r.previousDays < r.currentDays ? r.previousDays : r.currentDays;
      main = l?.monthlyReportNotEnough ?? 'Not enough days yet';
      detail = l?.monthlyReportNotEnoughDetail(have, periodChangeMinDays) ??
          '$have of $periodChangeMinDays measured days in the thinner month';
      icon = LucideIcons.hourglass;
    } else {
      main = '${fmt(ch.currentMean)}$unit';
      detail = l?.monthlyReportWas(fmt(ch.previousMean) + unit,
              ch.currentDays, ch.previousDays) ??
          'was ${fmt(ch.previousMean)}$unit · ${ch.currentDays} and '
              '${ch.previousDays} days measured';
      icon = switch (ch.direction) {
        'up' => LucideIcons.arrowUpRight,
        'down' => LucideIcons.arrowDownRight,
        _ => LucideIcons.minus,
      };
    }

    return Surface(
      child: Row(children: [
        Icon(spec.icon, size: 18, color: p.on(spec.color)),
        const SizedBox(width: S.x3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(spec.title, style: F.cap.copyWith(color: p.ink2)),
            Text(main, style: F.head.copyWith(color: p.ink)),
            Text(detail, style: F.cap.copyWith(color: p.ink3)),
          ]),
        ),
        Icon(icon,
            size: 20,
            color: ch == null || ch.direction == 'steady' ? p.ink3 : p.ink,
            semanticLabel: ch?.direction),
      ]),
    );
  }
}
