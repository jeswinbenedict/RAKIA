import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/neumorphism.dart';
import '../design/tokens.dart';

/// Card width below which trailing header content moves under the title.
const double kNarrowCardWidth = 480;

/// The standard content surface: a raised soft panel with one radius and one
/// padding scale, an optional heading row with trailing content, and an
/// optional tap target that sinks in when pressed and shows a focus ring.
class SurfaceCard extends StatefulWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailing,
    this.onTap,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(RakiaSpacing.xl),
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Label for the whole card when it is tappable.
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;

  @override
  State<SurfaceCard> createState() => _SurfaceCardState();
}

class _SurfaceCardState extends State<SurfaceCard> {
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;

    Widget? buildHeader(bool narrow) => widget.title == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: RakiaSpacing.lg),
            child: narrow && widget.trailing != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _titleRow(context, c, t),
                      const SizedBox(height: RakiaSpacing.md),
                      widget.trailing!,
                    ],
                  )
                : _titleRow(context, c, t, withTrailing: true),
          );

    final body = LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ?buildHeader(constraints.maxWidth < kNarrowCardWidth),
            widget.child,
          ],
        ),
      ),
    );

    final interactive = widget.onTap != null;
    final focusBorder = _focused
        ? Border.all(color: c.focusRing, width: 2)
        : null;

    if (!interactive) {
      return NeuSurface(radius: RakiaRadii.md, child: body);
    }
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (f) => setState(() => _focused = f),
          borderRadius: BorderRadius.circular(RakiaRadii.md),
          child: AnimatedNeuSurface(
            pressed: _pressed,
            depth: RakiaDepth.panel,
            radius: RakiaRadii.md,
            border: focusBorder,
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _titleRow(
    BuildContext context,
    RakiaColors c,
    TextTheme t, {
    bool withTrailing = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.leadingIcon != null) ...[
          ExcludeSemantics(
            // The icon sits in a small inset well.
            child: SizedBox(
              width: 40,
              height: 40,
              child: NeuSurface(
                style: NeuStyle.inset,
                depth: RakiaDepth.control,
                radius: RakiaRadii.sm,
                child: Center(
                  child: Icon(widget.leadingIcon, size: 20, color: c.brandText),
                ),
              ),
            ),
          ),
          const SizedBox(width: RakiaSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(widget.title!, style: t.titleSmall),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(widget.subtitle!, style: t.bodySmall),
              ],
            ],
          ),
        ),
        if (withTrailing && widget.trailing != null) ...[
          const SizedBox(width: RakiaSpacing.md),
          widget.trailing!,
        ],
      ],
    );
  }
}
