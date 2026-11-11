import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/shell/shell.dart';
import 'providers.dart';

/// The most the system text size may enlarge Mari's type.
const double kMaxTextScale = 1.35;

class MariApp extends ConsumerWidget {
  const MariApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final onboarded = ref.watch(settingsProvider.select((s) => s.onboarded));

    // Framework widgets (date pickers, text selection) stay in English: Flutter
    // ships no Shona or Ndebele material localisations. Mari's own words come
    // from Strings, in the language the person chose.
    return MaterialApp(
      title: 'Mari',
      debugShowCheckedModeBanner: false,
      theme: buildMariTheme(Brightness.light),
      darkTheme: buildMariTheme(Brightness.dark),
      themeMode: themeMode,
      // Larger system text is honoured up to 1.35x. Past that the hero figure
      // and the keypad would clip, so Mari stops growing instead of breaking.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: kMaxTextScale,
        child: child ?? const SizedBox.shrink(),
      ),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: onboarded ? const Shell(key: ValueKey('shell')) : const OnboardingScreen(key: ValueKey('onboarding')),
      ),
    );
  }
}
