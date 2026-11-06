import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/rakia_mark.dart';
import '../components/simulation_banner.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import 'modules.dart';

/// Primary destinations in the compact bottom bar; the rest live in "More".
const List<String> kCompactPrimary = ['mission', 'actions', 'cardio', 'sleep'];

const String kAboutPath = '/about';

/// Chooses the navigation pattern for the window class:
/// compact: bottom bar + "More" sheet; medium: icon rail;
/// expanded and large: labelled sidebar grouped by purpose.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final windowClass = RakiaBreakpoints.of(MediaQuery.sizeOf(context).width);
    final c = RakiaColors.of(context);
    final content = FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SimulationBanner(),
          Expanded(child: child),
        ],
      ),
    );

    if (windowClass == RakiaWindowClass.compact) {
      return Scaffold(
        body: SafeArea(bottom: false, child: content),
        bottomNavigationBar: _CompactBar(location: location),
      );
    }

    final nav = FocusTraversalGroup(
      child: switch (windowClass) {
        RakiaWindowClass.medium => _Sidebar(
          location: location,
          extended: false,
        ),
        RakiaWindowClass.expanded => _Sidebar(
          location: location,
          extended: true,
          width: 240,
        ),
        _ => _Sidebar(location: location, extended: true, width: 272),
      },
    );
    return Scaffold(
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            nav,
            VerticalDivider(width: 1, color: c.borderSubtle),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

class _CompactBar extends StatelessWidget {
  const _CompactBar({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final primary = [
      for (final id in kCompactPrimary) kModules.firstWhere((m) => m.id == id),
    ];
    final current = moduleForPath(location);
    var index = primary.indexWhere((m) => m.id == current?.id);
    if (index < 0) index = primary.length; // "More" owns everything else.

    return NavigationBar(
      key: const Key('nav-compact'),
      selectedIndex: index,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: (i) {
        if (i < primary.length) {
          context.go(primary[i].path);
        } else {
          _showMore(context);
        }
      },
      destinations: [
        for (final m in primary)
          NavigationDestination(
            icon: Icon(m.icon),
            selectedIcon: Icon(m.selectedIcon),
            label: m.shortLabel,
            tooltip: m.label,
          ),
        const NavigationDestination(
          icon: Icon(Icons.more_horiz),
          label: 'More',
          tooltip: 'More modules',
        ),
      ],
    );
  }

  void _showMore(BuildContext context) {
    final others = kModules
        .where((m) => !kCompactPrimary.contains(m.id))
        .toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          key: const Key('nav-more-sheet'),
          shrinkWrap: true,
          children: [
            for (final m in others)
              ListTile(
                leading: Icon(m.icon),
                title: Text(m.label),
                minTileHeight: RakiaSpacing.minTarget + 8,
                selected: location.startsWith(m.path),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.go(m.path);
                },
              ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About RAKIA'),
              minTileHeight: RakiaSpacing.minTarget + 8,
              selected: location == kAboutPath,
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go(kAboutPath);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.location,
    required this.extended,
    this.width = 80,
  });

  final String location;
  final bool extended;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    final items = <Widget>[];
    ModuleGroup? group;
    for (final m in kModules) {
      if (extended && m.group != group) {
        group = m.group;
        items.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              RakiaSpacing.lg,
              RakiaSpacing.xl,
              RakiaSpacing.lg,
              RakiaSpacing.sm,
            ),
            child: Semantics(
              header: true,
              child: Text(group.label.toUpperCase(), style: t.labelSmall),
            ),
          ),
        );
      }
      items.add(
        _NavItem(
          icon: m.icon,
          selectedIcon: m.selectedIcon,
          label: m.label,
          selected: moduleForPath(location)?.id == m.id,
          extended: extended,
          onTap: () => context.go(m.path),
        ),
      );
    }

    return Container(
      key: Key(extended ? 'nav-sidebar' : 'nav-rail'),
      width: width,
      color: c.surface1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: extended ? RakiaSpacing.lg : 0,
              vertical: extended ? RakiaSpacing.md : RakiaSpacing.lg,
            ),
            child: extended
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const RakiaMark(size: 28),
                          const SizedBox(width: RakiaSpacing.sm + 2),
                          // The wordmark is a logo: it scales down to fit
                          // rather than wrapping at very large text sizes.
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'RAKIA',
                                style: t.titleMedium?.copyWith(
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: RakiaSpacing.xs),
                      Text(
                        'Astronaut health intelligence',
                        style: t.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )
                : Center(
                    child: Semantics(
                      label: 'RAKIA',
                      child: const RakiaMark(size: 36),
                    ),
                  ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: RakiaSpacing.xs),
              children: items,
            ),
          ),
          Divider(color: c.borderSubtle),
          _NavItem(
            icon: Icons.info_outline,
            selectedIcon: Icons.info,
            label: 'About RAKIA',
            selected: location == kAboutPath,
            extended: extended,
            onTap: () => context.go(kAboutPath),
          ),
          if (extended)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                RakiaSpacing.lg,
                RakiaSpacing.xs,
                RakiaSpacing.lg,
                RakiaSpacing.lg,
              ),
              child: Text(
                'Research software · not a medical device',
                style: t.bodySmall,
              ),
            )
          else
            const SizedBox(height: RakiaSpacing.sm),
        ],
      ),
    );
  }
}

/// Navigation entry with a visible focus ring, 48dp minimum height and a
/// selected state announced to screen readers.
class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    final fg = widget.selected ? c.onBrand : c.textSecondary;

    Widget item = Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (f) => setState(() => _focused = f),
        borderRadius: BorderRadius.circular(RakiaRadii.sm),
        child: Container(
          constraints: const BoxConstraints(minHeight: RakiaSpacing.minTarget),
          padding: EdgeInsets.symmetric(
            horizontal: widget.extended ? RakiaSpacing.md : 0,
          ),
          decoration: BoxDecoration(
            color: widget.selected ? c.brand : null,
            borderRadius: BorderRadius.circular(RakiaRadii.sm),
            border: Border.all(
              color: _focused ? c.focusRing : const Color(0x00000000),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: widget.extended
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                widget.selected ? widget.selectedIcon : widget.icon,
                color: fg,
              ),
              if (widget.extended) ...[
                const SizedBox(width: RakiaSpacing.md),
                Expanded(
                  child: Text(
                    widget.label,
                    style: t.labelLarge?.copyWith(
                      color: widget.selected ? c.onBrand : c.textPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!widget.extended) {
      item = Tooltip(message: widget.label, child: item);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RakiaSpacing.sm,
        vertical: 2,
      ),
      child: item,
    );
  }
}
