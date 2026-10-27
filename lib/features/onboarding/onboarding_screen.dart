import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/language.dart';
import '../../core/l10n/strings.dart';
import '../../core/money/money.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../domain/month_tree.dart';
import '../../widgets/primitives.dart';
import '../tree/month_tree_view.dart';

/// A sample month for the welcome screen, so people see the payoff first.
final Map<int, DayTone> _demoTones = () {
  final r = treeRng(424242);
  return {
    for (var d = 1; d <= 30; d++)
      d: () {
        final v = r();
        if (v < 0.07) return DayTone.bud;
        if (v < 0.15) return DayTone.gold;
        if (v < 0.45) return DayTone.light;
        if (v < 0.72) return DayTone.steady;
        if (v < 0.9) return DayTone.full;
        return DayTone.heavy;
      }(),
  };
}();

/// Four calm steps: welcome, language, home currency and today's rate, privacy.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  Currency _home = Currency.usd;
  late final TextEditingController _rate;
  double? _official;
  bool _rateEdited = false;

  @override
  void initState() {
    super.initState();
    _rate = TextEditingController(text: Money.formatRate(ref.read(currentRateProvider)));
    _fetchRate();
  }

  Future<void> _fetchRate() async {
    final r = await ref.read(rateControllerProvider).refresh();
    if (!mounted || r == null) return;
    setState(() {
      _official = r;
      if (!_rateEdited) _rate.text = Money.formatRate(r);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    _rate.dispose();
    super.dispose();
  }

  void _go(int page) {
    FocusScope.of(context).unfocus();
    setState(() => _page = page);
    _pages.animateToPage(page, duration: Motion.sheetRise, curve: Motion.sheetCurve);
  }

  Future<void> _finish() async {
    HapticFeedback.lightImpact();
    final entered = double.tryParse(_rate.text.replaceAll(',', '').trim());
    final official = _official;
    final useOwn = entered != null && entered > 0 && (official == null || (entered - official).abs() > 0.005);
    await ref.read(settingsProvider.notifier).edit((s) => s.copyWith(
          onboarded: true,
          homeCurrency: _home,
          displayCurrency: _home,
          useManualRate: useOwn,
          manualRate: useOwn ? entered : s.manualRate,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(settingsProvider.select((x) => x.language));

    Widget dots() => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < 4; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _page ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(color: i == _page ? c.textPrimary : c.separator, borderRadius: BorderRadius.circular(9)),
            ),
        ]);

    Widget choice({required bool selected, required String title, required String subtitle, required VoidCallback onTap}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.sm),
        child: Pressable(
          onTap: onTap,
          haptic: true,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? c.accent : c.separator, width: selected ? 2 : 1),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: MariType.headline.copyWith(color: c.textPrimary)),
                  Text(subtitle, style: MariType.footnote.copyWith(color: c.textSecondary)),
                ]),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? c.accent : Colors.transparent,
                  border: selected ? null : Border.all(color: c.separator, width: 1.5),
                ),
                child: selected ? Icon(Icons.check_rounded, size: 16, color: c.onAccent) : null,
              ),
            ]),
          ),
        ),
      );
    }

    Widget page({required Widget body, required String button, required VoidCallback onButton, bool centered = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        child: Column(children: [
          Expanded(
            child: centered
                ? Center(child: SingleChildScrollView(child: body))
                : SingleChildScrollView(padding: const EdgeInsets.only(top: Space.xxl), child: body),
          ),
          dots(),
          const SizedBox(height: Space.md),
          MariButton(label: button, onPressed: onButton),
          const SizedBox(height: Space.md),
        ]),
      );
    }

    Widget promise(IconData icon, K title, K body) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 24, color: c.accent),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s[title], style: MariType.headline.copyWith(color: c.textPrimary)),
                const SizedBox(height: 2),
                Text(s[body], style: MariType.callout.copyWith(color: c.textSecondary)),
              ]),
            ),
          ]),
        );

    final pages = [
      page(
        centered: true,
        button: s[K.getStarted],
        onButton: () => _go(1),
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: Radii.cardAll,
              gradient: RadialGradient(center: Alignment.bottomCenter, radius: 1.25, colors: [c.surface, c.sky]),
            ),
            child: MonthTreeView(year: 2026, month: 9, tones: _demoTones, reveal: true),
          ),
          const SizedBox(height: Space.lg),
          Text.rich(TextSpan(children: [
            TextSpan(text: 'Mari', style: MariType.display.copyWith(fontSize: 64, height: 1, fontWeight: FontWeight.w700, letterSpacing: -3, color: c.textPrimary)),
            TextSpan(text: '.', style: MariType.display.copyWith(fontSize: 64, height: 1, fontWeight: FontWeight.w700, color: c.warm)),
          ])),
          const SizedBox(height: Space.sm),
          Text(lang.tagline, style: MariType.title2.copyWith(fontWeight: FontWeight.w500, color: c.textSecondary)),
          const SizedBox(height: Space.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(s[K.welcomeBody], style: MariType.body.copyWith(color: c.textSecondary)),
          ),
        ]),
      ),
      page(
        button: s[K.continueLabel],
        onButton: () => _go(2),
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s[K.chooseLanguage], style: MariType.title1.copyWith(color: c.textPrimary)),
          const SizedBox(height: Space.xxs),
          Text(s[K.chooseLanguageBody], style: MariType.callout.copyWith(color: c.textSecondary)),
          const SizedBox(height: Space.md),
          for (final l in AppLanguage.values)
            choice(
              selected: l == lang,
              title: l.nativeName,
              subtitle: l.tagline,
              onTap: () => ref.read(settingsProvider.notifier).edit((st) => st.copyWith(language: l)),
            ),
        ]),
      ),
      page(
        button: s[K.continueLabel],
        onButton: () => _go(3),
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s[K.homeCurrencyTitle], style: MariType.title1.copyWith(color: c.textPrimary)),
          const SizedBox(height: Space.xxs),
          Text(s[K.homeCurrencyBody], style: MariType.callout.copyWith(color: c.textSecondary)),
          const SizedBox(height: Space.md),
          choice(selected: _home == Currency.usd, title: s[K.usDollars], subtitle: s[K.usDollarsBody], onTap: () => setState(() => _home = Currency.usd)),
          choice(selected: _home == Currency.zig, title: 'ZiG', subtitle: s[K.zigBody], onTap: () => setState(() => _home = Currency.zig)),
          const SizedBox(height: Space.xs),
          Text(s[K.todaysRate], style: MariType.footnote.copyWith(color: c.textSecondary)),
          const SizedBox(height: 6),
          MariTextField(
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            onChanged: (_) => _rateEdited = true,
          ),
          const SizedBox(height: 6),
          Text(_official == null ? s[K.rateOnboardingOffline] : s[K.rateOnboardingFetched],
              style: MariType.footnote.copyWith(color: c.textTertiary)),
        ]),
      ),
      page(
        button: s[K.plantTree],
        onButton: _finish,
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s[K.treeHowTitle], style: MariType.title1.copyWith(color: c.textPrimary)),
          const SizedBox(height: Space.lg),
          promise(Icons.eco_rounded, K.treeHow1Title, K.treeHow1Body),
          promise(Icons.spa_rounded, K.treeHow2Title, K.treeHow2Body),
          promise(Icons.collections_bookmark_rounded, K.treeHow3Title, K.treeHow3Body),
          promise(Icons.lock_rounded, K.promiseLocalTitle, K.promiseLocalBody),
        ]),
      ),
    ];

    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _page > 0) _go(_page - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(children: [
            SizedBox(
              height: 44,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _page == 0
                    ? null
                    : Pressable(
                        onTap: () => _go(_page - 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.chevron_left_rounded, color: c.accent, size: 28),
                            Text(s[K.back], style: MariType.body.copyWith(color: c.accent)),
                          ]),
                        ),
                      ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: pages,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
