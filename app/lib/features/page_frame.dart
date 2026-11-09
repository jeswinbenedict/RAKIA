import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// Shared page scaffold: browser-tab title, adaptive gutters, a readable
/// maximum width and a page heading announced as a header.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.eyebrow,
    required this.summary,
    required this.body,
  });

  final String title;
  final String eyebrow;
  final String summary;
  final Widget body;

  static double gutterFor(RakiaWindowClass w) => switch (w) {
    RakiaWindowClass.compact => RakiaSpacing.lg,
    RakiaWindowClass.medium => RakiaSpacing.xl,
    RakiaWindowClass.expanded => RakiaSpacing.xxl,
    RakiaWindowClass.large => RakiaSpacing.xxxl,
  };

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    final w = RakiaBreakpoints.of(MediaQuery.sizeOf(context).width);
    final gutter = gutterFor(w);
    return Title(
      title: '$title · RAKIA',
      color: c.brand,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(gutter, gutter, gutter, RakiaSpacing.xxxl),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow.toUpperCase(), style: t.labelSmall),
                const SizedBox(height: RakiaSpacing.sm),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: w == RakiaWindowClass.compact
                        ? t.headlineSmall
                        : t.headlineMedium,
                  ),
                ),
                const SizedBox(height: RakiaSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Text(
                    summary,
                    style: t.bodyLarge?.copyWith(color: c.textSecondary),
                  ),
                ),
                const SizedBox(height: RakiaSpacing.xl),
                body,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A section title inside a page, announced as a heading.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}
