import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Type scale (design/tokens.json → type). System face: SF Pro on iOS,
/// Roboto on Android — no font download, native feel. Every style carries
/// tabular figures so money never jitters when it changes.
class MariType {
  static const List<FontFeature> _tnum = [FontFeature.tabularFigures()];

  static const display = TextStyle(fontSize: 44, height: 48 / 44, fontWeight: FontWeight.w600, letterSpacing: -1.4, fontFeatures: _tnum);
  static const title1 = TextStyle(fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w600, letterSpacing: -0.6, fontFeatures: _tnum);
  static const title2 = TextStyle(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600, letterSpacing: -0.3, fontFeatures: _tnum);
  static const headline = TextStyle(fontSize: 17, height: 22 / 17, fontWeight: FontWeight.w600, letterSpacing: -0.2, fontFeatures: _tnum);
  static const body = TextStyle(fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w400, letterSpacing: -0.2, fontFeatures: _tnum);
  static const callout = TextStyle(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w400, letterSpacing: -0.1, fontFeatures: _tnum);
  static const subhead = TextStyle(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w500, letterSpacing: -0.1, fontFeatures: _tnum);
  static const footnote = TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w400, fontFeatures: _tnum);
  static const caption = TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600, letterSpacing: 0.4, fontFeatures: _tnum);
  static const button = TextStyle(fontSize: 17, height: 22 / 17, fontWeight: FontWeight.w600, letterSpacing: -0.2);
  static const amountEntry = TextStyle(fontSize: 56, height: 64 / 56, fontWeight: FontWeight.w600, letterSpacing: -2, fontFeatures: _tnum);
}

/// Gives widgets the full Mari palette (semantic colours Material lacks).
class MariTheme extends ThemeExtension<MariTheme> {
  const MariTheme(this.palette);
  final MariPalette palette;

  @override
  MariTheme copyWith({MariPalette? palette}) => MariTheme(palette ?? this.palette);

  @override
  MariTheme lerp(covariant ThemeExtension<MariTheme>? other, double t) {
    if (other is! MariTheme) return this;
    return MariTheme(MariPalette.lerp(palette, other.palette, t));
  }
}

extension MariThemeContext on BuildContext {
  MariPalette get colors => Theme.of(this).extension<MariTheme>()!.palette;
}

ThemeData buildMariTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? MariPalette.dark : MariPalette.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    secondary: p.accent,
    onSecondary: p.onAccent,
    error: p.spend,
    onError: p.onAccent,
    surface: p.surface,
    onSurface: p.textPrimary,
  );

  final text = TextTheme(
    displayLarge: MariType.display.copyWith(color: p.textPrimary),
    headlineMedium: MariType.title1.copyWith(color: p.textPrimary),
    titleLarge: MariType.title2.copyWith(color: p.textPrimary),
    titleMedium: MariType.headline.copyWith(color: p.textPrimary),
    bodyLarge: MariType.body.copyWith(color: p.textPrimary),
    bodyMedium: MariType.callout.copyWith(color: p.textPrimary),
    bodySmall: MariType.footnote.copyWith(color: p.textSecondary),
    labelLarge: MariType.button.copyWith(color: p.textPrimary),
    labelSmall: MariType.caption.copyWith(color: p.textSecondary),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    dividerColor: p.separator,
    textTheme: text,
    extensions: [MariTheme(p)],
    // Restraint: no ink ripples. Pressable surfaces scale instead (see Pressable).
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.accent.withValues(alpha: 0.25),
      selectionHandleColor: p.accent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.background,
      modalBackgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.textPrimary,
      contentTextStyle: MariType.callout.copyWith(color: p.background),
      actionTextColor: p.accentSoft,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      elevation: 0,
    ),
    cupertinoOverrideTheme: CupertinoThemeData(primaryColor: p.accent, brightness: brightness),
  );
}
