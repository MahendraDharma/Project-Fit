// Home's day picker: the last two weeks as a strip of dates, today on the
// right, with the month calendar one tap away for anything older.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/day_label.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/date_text.dart';
import '../ui2.dart';
import 'metric_detail.dart' show chooseDay, dayNavLabel;

/// [days] is every day on disk, newest first (as `availableDays` returns it).
/// A date with nothing recorded is shown, dimmed, and cannot be picked.
class WeekStrip extends StatelessWidget {
  final String? day;
  final List<String> days;
  final ValueChanged<String> onDay;

  /// Pinned for the gallery and tests; the wall clock otherwise.
  final DateTime? now;

  const WeekStrip(
      {super.key, required this.day, required this.days, required this.onDay, this.now});

  static const span = 14;

  @override
  Widget build(BuildContext c) {
    if (days.length < 2) return const SizedBox.shrink();
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final code = l?.localeName ?? 'en';
    final today = DateTime.tryParse(todayLabel(now))!;
    final picked = DateTime.tryParse(day ?? '') ?? today;
    // The strip ends today, unless the picked day is older than the strip.
    final end = today.difference(picked).inDays >= span ? picked : today;
    final have = days.toSet();
    final cells = [
      for (var i = span - 1; i >= 0; i--)
        DateTime(end.year, end.month, end.day - i),
    ];

    Widget cell(DateTime d) {
      final label = dayLabelOf(d);
      final on = label == (day ?? todayLabel(now));
      final ok = have.contains(label);
      final top = localizedDate(d, code, pattern: 'EEE');
      return Pressable(
        key: ValueKey('week-$label'),
        onTap: ok && !on ? () => onDay(label) : null,
        semanticLabel: dayNavLabel(label, l),
        child: Semantics(
          selected: on,
          child: Container(
            width: S.x12,
            padding: const EdgeInsets.symmetric(vertical: S.x2),
            decoration: BoxDecoration(
              color: on ? p.ink : const Color(0x00000000),
              borderRadius: R.rLg,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(top,
                  maxLines: 1,
                  style: F.over.copyWith(color: on ? p.bg : p.ink3)),
              const SizedBox(height: S.x1),
              Text('${d.day}',
                  style: F.n17.copyWith(
                      color: on ? p.bg : (ok ? p.ink : p.ink3.withValues(alpha: .5)))),
            ]),
          ),
        ),
      );
    }

    return Row(children: [
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true, // today (the last cell) starts in view
          child: Row(children: [
            for (final d in cells) Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: cell(d),
            ),
          ]),
        ),
      ),
      Pressable(
        onTap: () async {
          final to = await chooseDay(c, days, day);
          if (to != null && to != day) onDay(to);
        },
        semanticLabel: l?.metricDetailChooseDayShowing(dayNavLabel(day, l)) ??
            'Choose a day. Showing ${dayNavLabel(day, l)}',
        child: Icon(LucideIcons.calendarDays, size: 20, color: p.ink2),
      ),
    ]);
  }
}
