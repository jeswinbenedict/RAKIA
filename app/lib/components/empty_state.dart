import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/neumorphism.dart';
import '../design/tokens.dart';

/// Explains what is missing and what will appear here, instead of showing
/// an empty chart or invented numbers.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: double.infinity,
      child: NeuSurface(
        radius: RakiaRadii.md,
        padding: const EdgeInsets.all(RakiaSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icon, color: c.brandText, size: 28)),
            const SizedBox(height: RakiaSpacing.md),
            Semantics(header: true, child: Text(title, style: t.titleMedium)),
            const SizedBox(height: RakiaSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                message,
                style: t.bodyMedium?.copyWith(color: c.textSecondary),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: RakiaSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
