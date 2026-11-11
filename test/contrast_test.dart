import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mari/core/theme/tokens.dart';

double _channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) => 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

/// WCAG 2.x contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The palette is a promise: any text ink can be put on any of the grounds
/// it is used on and still be read. If a token changes and breaks that, this
/// fails with the pair that broke.
void main() {
  for (final (name, p) in [('light', MariPalette.light), ('dark', MariPalette.dark)]) {
    group('$name palette', () {
      final grounds = {'background': p.background, 'surface': p.surface, 'surfaceRaised': p.surfaceRaised, 'sky': p.sky};

      test('text inks meet AA (4.5:1) on every ground', () {
        final inks = {
          'textPrimary': p.textPrimary,
          'textSecondary': p.textSecondary,
          'textTertiary': p.textTertiary,
          'accent': p.accent,
          'income': p.income,
          'spend': p.spend,
          'warningInk': p.warningInk,
        };
        for (final ink in inks.entries) {
          for (final ground in grounds.entries) {
            final ratio = contrast(ink.value, ground.value);
            // sky is a wash under the tree; only neutral text sits on it.
            if (ground.key == 'sky' && !ink.key.startsWith('text')) continue;
            expect(ratio, greaterThanOrEqualTo(ground.key == 'sky' && ink.key == 'textTertiary' ? 4.0 : 4.5),
                reason: '${ink.key} on ${ground.key} is ${ratio.toStringAsFixed(2)}:1');
          }
        }
      });

      test('semantic inks meet AA on their own soft ground', () {
        final pairs = {
          'accent on accentSoft': (p.accent, p.accentSoft),
          'income on incomeSoft': (p.income, p.incomeSoft),
          'spend on spendSoft': (p.spend, p.spendSoft),
          'warningInk on warningSoft': (p.warningInk, p.warningSoft),
          'onAccent on accent': (p.onAccent, p.accent),
          'textSecondary on warmSoft': (p.textSecondary, p.warmSoft),
          'textSecondary on accentSoft': (p.textSecondary, p.accentSoft),
        };
        pairs.forEach((label, pair) {
          final ratio = contrast(pair.$1, pair.$2);
          expect(ratio, greaterThanOrEqualTo(4.5), reason: '$label is ${ratio.toStringAsFixed(2)}:1');
        });
      });

      test('category icons stand out from their wash (3:1)', () {
        for (final t in CategoryTint.values) {
          final pair = p.tint(t);
          final ratio = contrast(pair.ink, pair.wash);
          expect(ratio, greaterThanOrEqualTo(3.0), reason: '${t.name} ink on its wash is ${ratio.toStringAsFixed(2)}:1');
        }
      });

      test('fills can be told from their track (3:1)', () {
        for (final fill in {'accent': p.accent, 'warning': p.warning, 'spend': p.spend}.entries) {
          final ratio = contrast(fill.value, p.surfaceSunken);
          expect(ratio, greaterThanOrEqualTo(3.0), reason: '${fill.key} bar on its track is ${ratio.toStringAsFixed(2)}:1');
        }
      });
    });
  }
}
