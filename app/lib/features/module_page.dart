import 'package:flutter/material.dart';

import '../components/accent_box.dart';
import '../components/empty_state.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../navigation/modules.dart';
import 'page_frame.dart';

/// A module page before data exists: what the module tracks, any caveat,
/// and an honest empty state. No placeholder numbers or fake charts.
class ModulePage extends StatelessWidget {
  const ModulePage({
    super.key,
    required this.module,
    this.emptyAction,
    this.header,
  });

  final ModuleSpec module;

  /// Optional content above the empty state, e.g. the astronaut's record.
  final Widget? header;

  /// Optional action under the empty state, e.g. starting the simulation.
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context) {
    final w = RakiaBreakpoints.of(MediaQuery.sizeOf(context).width);
    final empty = EmptyState(
      icon: module.selectedIcon,
      title: module.emptyTitle,
      message: module.emptyMessage,
      action: emptyAction,
    );
    final tracks = _TracksCard(module: module);

    final Widget body;
    if (w == RakiaWindowClass.expanded || w == RakiaWindowClass.large) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: empty),
          const SizedBox(width: RakiaSpacing.xl),
          Expanded(flex: 2, child: tracks),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          empty,
          const SizedBox(height: RakiaSpacing.lg),
          tracks,
        ],
      );
    }

    return PageFrame(
      title: module.label,
      eyebrow: module.group.label,
      summary: module.summary,
      body: header == null
          ? body
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header!,
                const SizedBox(height: RakiaSpacing.xl),
                body,
              ],
            ),
    );
  }
}

class _TracksCard extends StatelessWidget {
  const _TracksCard({required this.module});

  final ModuleSpec module;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(RakiaSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text('What this module tracks', style: t.titleSmall),
            ),
            const SizedBox(height: RakiaSpacing.md),
            for (final item in module.tracks)
              Padding(
                padding: const EdgeInsets.only(bottom: RakiaSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: ExcludeSemantics(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: c.brandText,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: RakiaSpacing.md),
                    Expanded(child: Text(item, style: t.bodyMedium)),
                  ],
                ),
              ),
            if (module.note != null) ...[
              const SizedBox(height: RakiaSpacing.md),
              AccentBox(
                color: c.surface3,
                accent: c.brandText,
                child: Text(
                  module.note!,
                  style: t.bodySmall?.copyWith(color: c.textPrimary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
