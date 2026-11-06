import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';

/// The RAKIA brand mark: a bold "R" on the brand violet with a lime point,
/// matching the app icon (tool/generate_icons.py). Decorative; the product
/// name is always present as text or a semantic label next to it.
class RakiaMark extends StatelessWidget {
  const RakiaMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.225),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [RakiaPalette.violet, RakiaPalette.violetText],
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: EdgeInsets.only(right: size * 0.04),
                  child: Text(
                    'R',
                    style: TextStyle(
                      fontFamily: RakiaType.sans,
                      fontWeight: FontWeight.w700,
                      fontSize: size * 0.62,
                      height: 1,
                      color: const Color(0xFFFFFFFF),
                    ),
                    textScaler: TextScaler.noScaling,
                  ),
                ),
              ),
              Positioned(
                left: size * (0.5 + 0.235 - 0.075),
                top: size * (0.5 - 0.235 - 0.075),
                child: Container(
                  width: size * 0.15,
                  height: size * 0.15,
                  decoration: const BoxDecoration(
                    color: RakiaPalette.lime,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
