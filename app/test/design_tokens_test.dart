import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakia/design/colors.dart';
import 'package:rakia/design/contrast.dart';
import 'package:rakia/design/tokens.dart';

void main() {
  group('contrastRatio', () {
    test('matches WCAG reference values', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21.0, 1e-9),
      );
      expect(
        contrastRatio(const Color(0xFF777777), const Color(0xFF777777)),
        closeTo(1.0, 1e-9),
      );
      // #767676 on white is the classic 4.54:1 boundary grey.
      expect(
        contrastRatio(const Color(0xFF767676), const Color(0xFFFFFFFF)),
        closeTo(4.54, 0.01),
      );
    });
  });

  for (final entry in {
    'dark': RakiaColors.dark,
    'light': RakiaColors.light,
  }.entries) {
    final c = entry.value;
    final surfaces = {
      'canvas': c.canvas,
      'surface1': c.surface1,
      'surface2': c.surface2,
      'surface3': c.surface3,
    };

    group('${entry.key} theme contrast (WCAG 2.2 AA)', () {
      void expectText(String name, Color fg) {
        for (final s in surfaces.entries) {
          test('$name text on ${s.key} >= 4.5:1', () {
            expect(contrastRatio(fg, s.value), greaterThanOrEqualTo(4.5));
          });
        }
      }

      void expectUi(String name, Color fg) {
        for (final s in surfaces.entries) {
          test('$name on ${s.key} >= 3:1 (non-text)', () {
            expect(contrastRatio(fg, s.value), greaterThanOrEqualTo(3.0));
          });
        }
      }

      expectText('primary', c.textPrimary);
      expectText('secondary', c.textSecondary);
      expectText('brand', c.brandText);
      expectText('within-baseline', c.statusWithinBaseline);
      expectText('watch', c.statusWatch);
      expectText('act', c.statusAct);
      expectText('insufficient-data', c.statusInsufficient);
      expectText('data-quality', c.statusDataQuality);
      expectText('simulated', c.simulated);
      expectUi('control border', c.borderControl);
      expectUi('focus ring', c.focusRing);

      test('text on action fill >= 4.5:1', () {
        expect(contrastRatio(c.onAction, c.action), greaterThanOrEqualTo(4.5));
      });
      test('text on brand fill >= 4.5:1', () {
        expect(contrastRatio(c.onBrand, c.brand), greaterThanOrEqualTo(4.5));
      });
    });
  }

  test('reference palette values are preserved', () {
    // From the owner-supplied references (docs/design/DESIGN_SYSTEM.md §2).
    expect(RakiaPalette.violet, const Color(0xFF7D39EB));
    expect(RakiaPalette.lime, const Color(0xFFC6FF33));
    expect(RakiaPalette.canvasDark, const Color(0xFF08060E));
  });

  test('breakpoints classify widths', () {
    expect(RakiaBreakpoints.of(390), RakiaWindowClass.compact);
    expect(RakiaBreakpoints.of(599.9), RakiaWindowClass.compact);
    expect(RakiaBreakpoints.of(600), RakiaWindowClass.medium);
    expect(RakiaBreakpoints.of(1023), RakiaWindowClass.medium);
    expect(RakiaBreakpoints.of(1024), RakiaWindowClass.expanded);
    expect(RakiaBreakpoints.of(1440), RakiaWindowClass.large);
  });
}
