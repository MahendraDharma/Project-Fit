// The four-tab shell.
//
// Today · Sleep · Activity · Health. Stable: the contents personalise, the
// mental map does not. Each domain owns an accent, so colour tells you where
// you are before the label does. Profile is not a tab; every tab's header
// carries the avatar into it.
//
// There is no fifth tab, and the type system is what says so — [ShellDomain]
// is a closed enum and [AppShell] takes a builder keyed by it, so "just add a
// tab for X" is a change to this file with a reviewer attached, not something
// a screen can do on its own. Anything that feels like another destination is
// a section or a pushed screen inside the domain that owns it.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import 'grammar.dart';
import 'theme.dart';

/// The four primary destinations, in bar order.
enum ShellDomain {
  today('Today', LucideIcons.house, C.domHome),
  sleep('Sleep', LucideIcons.moon, C.domSleep),
  activity('Activity', LucideIcons.dumbbell, C.domMove),
  health('Health', LucideIcons.heartPulse, C.domHealth);

  const ShellDomain(this.label, this.icon, this.accent);

  final String label;
  final IconData icon;

  /// [label] in the user's language. Own keys rather than the screen titles,
  /// so two tabs can never end up with the same translated word.
  String title(BuildContext c) {
    final l = AppLocalizations.of(c);
    return switch (this) {
          ShellDomain.today => l?.tabToday,
          ShellDomain.sleep => l?.tabSleep,
          ShellDomain.activity => l?.tabActivity,
          ShellDomain.health => l?.tabHealth,
        } ??
        label;
  }

  /// The domain's pigment. Use `P.of(context).on(accent)` for text and
  /// `.fill(accent)` for a filled surface — the raw value is not AA-safe.
  final Color accent;
}

// There is no `Domain` InheritedWidget. There was one, promising that a screen
// "and anything it pushes" could pick up its accent without threading it — but
// nothing ever read it, and a pushed route could not have: `MaterialApp.home`
// is the gate, so `Navigator.of` pushes above the shell entirely. Screens take
// their accent as a parameter, which is honest about where it comes from.

class AppShell extends StatefulWidget {
  /// Builds the body of one domain. Called lazily — a tab is not built until
  /// it is first selected, then kept alive by the [IndexedStack].
  final Widget Function(BuildContext context, ShellDomain domain) builder;

  final ShellDomain initial;

  /// Notified on every tab change, including a re-tap of the current tab
  /// (which domains conventionally use to scroll to top) and a return via Back.
  final void Function(ShellDomain domain)? onSelect;

  /// Pinned between the domain and the tab bar, above every tab. This is not
  /// a general slot — it exists for state that is RUNNING and is not on
  /// screen, which today means a minimised workout. A domain's own content
  /// belongs inside the domain.
  final Widget? banner;

  /// The green + in the middle of the tab bar. Null: no + (a bare shell).
  final VoidCallback? onQuickAdd;

  const AppShell({
    super.key,
    required this.builder,
    this.initial = ShellDomain.today,
    this.onSelect,
    this.banner,
    this.onQuickAdd,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late ShellDomain _current = widget.initial;
  late final Set<ShellDomain> _built = {widget.initial};
  // Tabs are kept alive, not pushed onto the Navigator. Keep their history
  // here so Android Back can return to the previous tab. A restored tab or
  // cold-launch deep link has Today as its way back into the app.
  late final List<ShellDomain> _history = [
    if (widget.initial != ShellDomain.today) ShellDomain.today,
  ];

  void _select(ShellDomain d) {
    setState(() {
      // Each tab at most once, most recent last, so switching back and forth
      // between two tabs does not add a Back press per switch. Today stays in
      // as the way back into the app even while it is the tab on screen.
      if (d != _current) {
        _history.remove(_current);
        // Leaving Today puts it back at the bottom, never on top: it is the
        // last stop before Back leaves the app.
        if (_current == ShellDomain.today) {
          _history.insert(0, _current);
        } else {
          _history.add(_current);
        }
        if (d != ShellDomain.today) _history.remove(d);
      }
      _current = d;
      _built.add(d);
    });
    widget.onSelect?.call(d);
  }

  void _back() {
    if (_history.isEmpty) return;
    setState(() {
      _current = _history.removeLast();
      _built.add(_current);
    });
    widget.onSelect?.call(_current);
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return PopScope<Object?>(
      canPop: _history.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _current.index,
                  children: [
                    // An unvisited tab is an empty box, not a built screen — the
                    // old shell built all forty screens' worth of state on launch.
                    for (final d in ShellDomain.values)
                      if (_built.contains(d))
                        widget.builder(c, d)
                      else
                        const SizedBox.shrink(),
                  ],
                ),
              ),
              if (widget.banner != null) widget.banner!,
            ],
          ),
        ),
        bottomNavigationBar: _TabBar(
            current: _current, onTap: _select, onQuickAdd: widget.onQuickAdd),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final ShellDomain current;
  final ValueChanged<ShellDomain> onTap;
  final VoidCallback? onQuickAdd;

  const _TabBar({required this.current, required this.onTap, this.onQuickAdd});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final tabs = [
      for (final d in ShellDomain.values)
        _Tab(domain: d, on: d == current, onTap: () => onTap(d)),
    ];
    // A dark floating pill of icons, centred over the page: the selected tab
    // is a light disc, and the green + in the middle opens the quick log.
    // Labels are for the screen reader; the icons carry the meaning on screen.
    return ColoredBox(
      color: p.bg,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(S.x3, S.x1, S.x3, S.x3),
        child: Center(
          heightFactor: 1,
          child: Container(
            decoration: BoxDecoration(
              color: p.navBg,
              borderRadius: R.rPill,
              boxShadow: p.el(2),
            ),
            padding: const EdgeInsets.all(S.x1 + 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...tabs.take(2),
                if (onQuickAdd != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: S.x1),
                    child: Pressable(
                      onTap: onQuickAdd,
                      semanticLabel: l?.navQuickAdd ?? 'Log or start something',
                      child: Container(
                        width: S.x12,
                        height: S.x12,
                        decoration: BoxDecoration(
                          color: p.fill(C.green),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(LucideIcons.plus, size: 24, color: p.inkOnFill),
                      ),
                    ),
                  ),
                ...tabs.skip(2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final ShellDomain domain;
  final bool on;
  final VoidCallback onTap;

  const _Tab({required this.domain, required this.on, required this.onTap});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return Semantics(
      selected: on,
      child: Pressable(
        onTap: onTap,
        semanticLabel: domain.title(c),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: AnimatedContainer(
            duration: motion(c, Motion.base),
            width: S.x12,
            height: S.x12,
            decoration: BoxDecoration(
              color: on ? p.navOn : p.navBg,
              shape: BoxShape.circle,
            ),
            child: Icon(domain.icon, size: 22, color: on ? p.navOnInk : p.navInk),
          ),
        ),
      ),
    );
  }
}
