import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Design tokens. Mirrors design/tokens.json one to one — change both together.
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
    required this.income,
    required this.incomeSoft,
    required this.spend,
    required this.spendSoft,
    required this.warning,
    required this.warningSoft,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color separator;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentSoft;
  final Color onAccent;
  final Color income;
  final Color incomeSoft;
  final Color spend;
  final Color spendSoft;
  final Color warning;
  final Color warningSoft;

  static const light = MariPalette(
    background: Color(0xFFF6F5F2),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEEECE7),
    separator: Color(0xFFE4E1DB),
    textPrimary: Color(0xFF17161A),
    textSecondary: Color(0xFF6C6972),
    textTertiary: Color(0xFFA19DA6),
    accent: Color(0xFF6A4FD3),
    accentSoft: Color(0xFFEEEAFB),
    onAccent: Color(0xFFFFFFFF),
    income: Color(0xFF1E7F55),
    incomeSoft: Color(0xFFE3F2EA),
    spend: Color(0xFFB9502F),
    spendSoft: Color(0xFFF7E7E0),
    warning: Color(0xFFB87A0A),
    warningSoft: Color(0xFFFAF0D9),
  );

  static const dark = MariPalette(
    background: Color(0xFF0D0C0F),
    surface: Color(0xFF18171B),
    surfaceRaised: Color(0xFF211F25),
    surfaceSunken: Color(0xFF111013),
    separator: Color(0xFF2B292F),
    textPrimary: Color(0xFFF3F1F5),
    textSecondary: Color(0xFF9B97A2),
    textTertiary: Color(0xFF66626C),
    accent: Color(0xFFA592F2),
    accentSoft: Color(0xFF2A2440),
    onAccent: Color(0xFF16121F),
    income: Color(0xFF55C291),
    incomeSoft: Color(0xFF15281F),
    spend: Color(0xFFE68667),
    spendSoft: Color(0xFF2E1A14),
    warning: Color(0xFFE5B04E),
    warningSoft: Color(0xFF2C2210),
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
      income: l(a.income, b.income),
      incomeSoft: l(a.incomeSoft, b.incomeSoft),
      spend: l(a.spend, b.spend),
      spendSoft: l(a.spendSoft, b.spendSoft),
      warning: l(a.warning, b.warning),
      warningSoft: l(a.warningSoft, b.warningSoft),
    );
  }
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
  static const double card = 18;
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
}
