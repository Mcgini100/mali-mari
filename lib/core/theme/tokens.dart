import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Design tokens v2: Kariba teal and msasa amber on mist.
/// Mirrors design/tokens.json one to one — change both together.
class MariPalette {
  const MariPalette({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.separator,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.warm,
    required this.warmSoft,
    required this.income,
    required this.incomeSoft,
    required this.spend,
    required this.spendSoft,
    required this.warning,
    required this.warningSoft,
    required this.sky,
    required this.bark,
    required this.bud,
    required this.haze,
    required this.tints,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color separator;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Kariba teal: the brand and every action.
  final Color accent;
  final Color accentSoft;
  final Color onAccent;

  /// Msasa amber: the warm second voice, for moments worth a smile.
  final Color warm;
  final Color warmSoft;

  final Color income;
  final Color incomeSoft;
  final Color spend;
  final Color spendSoft;
  final Color warning;
  final Color warningSoft;

  /// The month tree's ground and wood.
  final Color sky;
  final Color bark;
  final Color bud;
  final Color haze;

  /// Category tints, ink and background per [CategoryTint].
  final Map<CategoryTint, TintPair> tints;

  TintPair tint(CategoryTint t) => tints[t]!;

  static const light = MariPalette(
    background: Color(0xFFF3F5F2),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFE8ECE8),
    separator: Color(0xFFDCE2DD),
    textPrimary: Color(0xFF14211F),
    textSecondary: Color(0xFF5B6B67),
    textTertiary: Color(0xFF94A29E),
    accent: Color(0xFF11756B),
    accentSoft: Color(0xFFDDEFEA),
    onAccent: Color(0xFFFFFFFF),
    warm: Color(0xFFD9822B),
    warmSoft: Color(0xFFFBEBD7),
    income: Color(0xFF0E7C66),
    incomeSoft: Color(0xFFDCF0E9),
    spend: Color(0xFFB5483A),
    spendSoft: Color(0xFFF7E4DF),
    warning: Color(0xFFB7791F),
    warningSoft: Color(0xFFFAEFD9),
    sky: Color(0xFFE3EEEA),
    bark: Color(0xFF6E4E3A),
    bud: Color(0xFFB9C4B4),
    haze: Color(0xFF8FB59A),
    tints: {
      CategoryTint.teal: TintPair(Color(0xFF11756B), Color(0xFFDDEFEA)),
      CategoryTint.amber: TintPair(Color(0xFFB66A1C), Color(0xFFFBEBD7)),
      CategoryTint.sage: TintPair(Color(0xFF4E7A4A), Color(0xFFE2EEDD)),
      CategoryTint.clay: TintPair(Color(0xFFA4523B), Color(0xFFF6E3DC)),
      CategoryTint.sky: TintPair(Color(0xFF2F6F96), Color(0xFFDEEBF3)),
      CategoryTint.plum: TintPair(Color(0xFF7A4E78), Color(0xFFEFE3EE)),
      CategoryTint.sand: TintPair(Color(0xFF8A6D2F), Color(0xFFF3EBD6)),
      CategoryTint.moss: TintPair(Color(0xFF5D6B2A), Color(0xFFECEFD9)),
    },
  );

  static const dark = MariPalette(
    background: Color(0xFF0C1514),
    surface: Color(0xFF142120),
    surfaceRaised: Color(0xFF1B2B29),
    surfaceSunken: Color(0xFF0A1110),
    separator: Color(0xFF243433),
    textPrimary: Color(0xFFE9F1EE),
    textSecondary: Color(0xFF93A6A1),
    textTertiary: Color(0xFF5F716C),
    accent: Color(0xFF4FC3B0),
    accentSoft: Color(0xFF143A35),
    onAccent: Color(0xFF06201C),
    warm: Color(0xFFF0A54C),
    warmSoft: Color(0xFF3A2812),
    income: Color(0xFF57C9A0),
    incomeSoft: Color(0xFF12302A),
    spend: Color(0xFFF08A6E),
    spendSoft: Color(0xFF3A1D16),
    warning: Color(0xFFE9B44C),
    warningSoft: Color(0xFF33260F),
    sky: Color(0xFF112523),
    bark: Color(0xFF9A7760),
    bud: Color(0xFF3E504B),
    haze: Color(0xFF3F8F7E),
    tints: {
      CategoryTint.teal: TintPair(Color(0xFF4FC3B0), Color(0xFF143A35)),
      CategoryTint.amber: TintPair(Color(0xFFF0A54C), Color(0xFF3A2812)),
      CategoryTint.sage: TintPair(Color(0xFF8CC183), Color(0xFF1D3020)),
      CategoryTint.clay: TintPair(Color(0xFFEE9A80), Color(0xFF3A1F17)),
      CategoryTint.sky: TintPair(Color(0xFF7DB9DE), Color(0xFF14293A)),
      CategoryTint.plum: TintPair(Color(0xFFCF9ACB), Color(0xFF2E1C2D)),
      CategoryTint.sand: TintPair(Color(0xFFDDBD72), Color(0xFF332811)),
      CategoryTint.moss: TintPair(Color(0xFFB4C46A), Color(0xFF262C12)),
    },
  );

  static MariPalette lerp(MariPalette a, MariPalette b, double t) {
    Color l(Color x, Color y) => Color.lerp(x, y, t)!;
    return MariPalette(
      background: l(a.background, b.background),
      surface: l(a.surface, b.surface),
      surfaceRaised: l(a.surfaceRaised, b.surfaceRaised),
      surfaceSunken: l(a.surfaceSunken, b.surfaceSunken),
      separator: l(a.separator, b.separator),
      textPrimary: l(a.textPrimary, b.textPrimary),
      textSecondary: l(a.textSecondary, b.textSecondary),
      textTertiary: l(a.textTertiary, b.textTertiary),
      accent: l(a.accent, b.accent),
      accentSoft: l(a.accentSoft, b.accentSoft),
      onAccent: l(a.onAccent, b.onAccent),
      warm: l(a.warm, b.warm),
      warmSoft: l(a.warmSoft, b.warmSoft),
      income: l(a.income, b.income),
      incomeSoft: l(a.incomeSoft, b.incomeSoft),
      spend: l(a.spend, b.spend),
      spendSoft: l(a.spendSoft, b.spendSoft),
      warning: l(a.warning, b.warning),
      warningSoft: l(a.warningSoft, b.warningSoft),
      sky: l(a.sky, b.sky),
      bark: l(a.bark, b.bark),
      bud: l(a.bud, b.bud),
      haze: l(a.haze, b.haze),
      tints: {
        for (final k in CategoryTint.values)
          k: TintPair(l(a.tints[k]!.ink, b.tints[k]!.ink), l(a.tints[k]!.wash, b.tints[k]!.wash)),
      },
    );
  }
}

enum CategoryTint { teal, amber, sage, clay, sky, plum, sand, moss }

class TintPair {
  const TintPair(this.ink, this.wash);
  final Color ink;
  final Color wash;
}

/// Msasa leaf tones: how a day went. Illustration colours, the same in both themes.
class LeafColors {
  static const light = Color(0xFF5E9B57);
  static const steady = Color(0xFFA3A03C);
  static const full = Color(0xFFE0A13A);
  static const heavy = Color(0xFFC8652E);
  static const gold = Color(0xFFE9BE45);
}

/// 8pt grid. 4 and 12 are the only half-steps; screen gutters are 20.
class Space {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
  static const double gutter = 20;
}

class Radii {
  static const double control = 12;
  static const double card = 20;
  static const double sheet = 28;
  static const double pill = 999;

  static const BorderRadius controlAll = BorderRadius.all(Radius.circular(control));
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
}

class Motion {
  static const Duration balanceRoll = Duration(milliseconds: 520);
  static const Curve balanceRollCurve = Curves.easeOutCubic;
  static const Duration sheetRise = Duration(milliseconds: 380);
  static const Curve sheetCurve = Cubic(0.2, 0.9, 0.25, 1);
  static const Duration currencySwap = Duration(milliseconds: 260);
  static const Curve currencySwapCurve = Curves.easeOutQuart;
  static const Duration press = Duration(milliseconds: 120);
  static const double pressScale = 0.97;

  /// Wind turns the crown gently around the trunk.
  static const double treeSwayPeriodS = 11.4;
  static const double treeSwayYaw = 0.07;

  /// Each leaf flutters on its own phase.
  static const double leafFlutterPeriodS = 3.7;
  static const double leafFlutter = 0.015;

  /// A new day's leaf overshoots a little, then settles.
  static const Duration leafGrow = Duration(milliseconds: 600);
}
