import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../capture/capture_service.dart';
import '../../core/l10n/language.dart';
import '../../core/l10n/strings.dart';
import '../../core/money/money.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/export/csv_export.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sheet.dart';
import 'consent_screen.dart';
import 'shortcut_guide_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with WidgetsBindingObserver {
  bool? _listenerOn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkListener();
  }

  Future<void> _checkListener() async {
    final svc = ref.read(captureServiceProvider);
    if (!svc.supportsNotificationCapture) return;
    final on = await svc.isListenerEnabled();
    if (mounted) setState(() => _listenerOn = on);
  }

  Future<void> _toggleCapture(bool on) async {
    if (on) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ConsentScreen()));
    } else {
      await ref.read(settingsProvider.notifier).edit((s) => s.copyWith(captureEnabled: false));
      await ref.read(captureServiceProvider).syncFilters();
    }
    _checkListener();
  }

  Future<void> _export() async {
    final entries = await ref.read(entryRepositoryProvider).allConfirmed();
    final cats = ref.read(categoryMapProvider);
    await shareCsv(entries, cats);
  }

  Future<void> _deleteAll() async {
    final s = ref.read(stringsProvider);
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(s[K.deleteAllTitle], style: MariType.headline.copyWith(color: c.textPrimary)),
        content: Text(s[K.deleteAllBody], style: MariType.callout.copyWith(color: c.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s[K.cancel], style: TextStyle(color: c.accent))),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s[K.deleteEverything], style: TextStyle(color: c.spend, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final capture = ref.read(captureServiceProvider);
    await ref.read(databaseProvider).wipeEverything();
    ref.read(settingsProvider.notifier).resetInMemory();
    await capture.syncFilters(); // capture is off again in the reset settings
    HapticFeedback.heavyImpact();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final rate = ref.watch(currentRateProvider);
    final latest = ref.watch(latestOfficialRateProvider).asData?.value;
    final notifier = ref.read(settingsProvider.notifier);
    final android = ref.read(captureServiceProvider).supportsNotificationCapture;

    String rateFooter() {
      if (settings.useManualRate) return s[K.rateFooterManual];
      if (latest == null) return s[K.rateFooterNever];
      return s.f(K.rateFooterUpdated, {'when': '${s.dayLabel(latest.at, DateTime.now())} ${s.time(latest.at)}'});
    }

    final captureSubtitle = !settings.captureEnabled
        ? s[K.captureSubtitle]
        : (_listenerOn == false ? s[K.captureNeedsPermission] : s[K.captureOn]);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: c.accent,
      ),
      body: DepthScaler(
        child: ColoredBox(
          color: c.background,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
            children: [
              ScreenTitle(title: s[K.settings]),
              MariList(label: s[K.money], footer: rateFooter(), children: [
                MariListTile(
                  icon: Icons.currency_exchange_rounded,
                  title: s[K.showAmountsIn],
                  trailing: Segmented<Currency>(
                    values: const [Currency.usd, Currency.zig],
                    labelOf: (x) => x.symbol,
                    selected: settings.displayCurrency,
                    onChanged: (x) => notifier.edit((st) => st.copyWith(displayCurrency: x)),
                  ),
                ),
                MariListTile(
                  icon: Icons.home_rounded,
                  title: s[K.homeCurrency],
                  trailing: Segmented<Currency>(
                    values: const [Currency.usd, Currency.zig],
                    labelOf: (x) => x.symbol,
                    selected: settings.homeCurrency,
                    onChanged: (x) => notifier.edit((st) => st.copyWith(homeCurrency: x)),
                  ),
                ),
                MariListTile(
                  icon: Icons.trending_flat_rounded,
                  title: s[K.exchangeRate],
                  value: '${Money.formatRate(rate)} · ${settings.useManualRate ? s[K.rateMine] : s[K.rateOfficial]}',
                  onTap: () => showMariSheet<void>(context, builder: (_) => const RateSheet()),
                ),
              ]),
              MariList(
                label: s[K.capture],
                footer: android ? s[K.captureFooterAndroid] : s[K.captureFooterIos],
                children: [
                  if (android) ...[
                    MariListTile(
                      icon: Icons.notifications_active_rounded,
                      title: s[K.readMoneyAlerts],
                      subtitle: captureSubtitle,
                      trailing: MariSwitch(value: settings.captureEnabled, onChanged: _toggleCapture),
                    ),
                    if (settings.captureEnabled)
                      MariListTile(
                        icon: Icons.tune_rounded,
                        title: s[K.sourcesAndSenders],
                        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ConsentScreen())),
                      ),
                  ],
                  if (!android)
                    MariListTile(
                      icon: Icons.bolt_rounded,
                      title: s[K.iphoneShortcut],
                      value: s[K.setUp],
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ShortcutGuideScreen())),
                    ),
                ],
              ),
              MariList(label: s[K.app], children: [
                MariListTile(
                  icon: Icons.translate_rounded,
                  title: s[K.language],
                  value: settings.language.nativeName,
                  onTap: () => showMariSheet<void>(context, builder: (_) => const LanguageSheet()),
                ),
                MariListTile(
                  icon: Icons.dark_mode_rounded,
                  title: s[K.appearance],
                  trailing: Segmented<ThemeMode>(
                    values: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
                    labelOf: (m) => switch (m) {
                      ThemeMode.system => s[K.themeAuto],
                      ThemeMode.light => s[K.themeLight],
                      ThemeMode.dark => s[K.themeDark],
                    },
                    selected: settings.themeMode,
                    onChanged: (m) => notifier.edit((st) => st.copyWith(themeMode: m)),
                  ),
                ),
              ]),
              MariList(label: s[K.yourData], footer: s[K.dataFooter], children: [
                MariListTile(icon: Icons.ios_share_rounded, title: s[K.exportCsv], onTap: _export),
                MariListTile(icon: Icons.delete_rounded, title: s[K.deleteAll], destructive: true, onTap: _deleteAll),
              ]),
              Center(child: Text('Mari 1.0.0', style: MariType.footnote.copyWith(color: c.textTertiary))),
            ],
          ),
        ),
      ),
    );
  }
}

class RateSheet extends ConsumerStatefulWidget {
  const RateSheet({super.key});

  @override
  ConsumerState<RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends ConsumerState<RateSheet> {
  late bool _manual;
  late final TextEditingController _rate;
  bool _fetching = false;
  bool? _fetchFailed;

  @override
  void initState() {
    super.initState();
    final st = ref.read(settingsProvider);
    _manual = st.useManualRate;
    _rate = TextEditingController(text: Money.formatRate(st.useManualRate ? st.manualRate : ref.read(currentRateProvider)));
  }

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  double? get _parsed {
    final v = double.tryParse(_rate.text.replaceAll(',', '').trim());
    return v == null || v <= 0 ? null : v;
  }

  Future<void> _refresh() async {
    setState(() {
      _fetching = true;
      _fetchFailed = null;
    });
    final r = await ref.read(rateControllerProvider).refresh();
    if (!mounted) return;
    setState(() {
      _fetching = false;
      _fetchFailed = r == null;
    });
  }

  Future<void> _save() async {
    final v = _parsed;
    await ref.read(settingsProvider.notifier).edit(
          (st) => st.copyWith(useManualRate: _manual, manualRate: _manual && v != null ? v : st.manualRate),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    final latest = ref.watch(latestOfficialRateProvider).asData?.value;
    final canSave = !_manual || _parsed != null;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      SheetHeader(title: s[K.exchangeRate], leading: s[K.cancel], trailing: s[K.save], onTrailing: canSave ? _save : null),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            MariCard(
              padding: const EdgeInsets.all(Space.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s[K.officialRate].toUpperCase(), style: MariType.caption.copyWith(color: c.textSecondary)),
                const SizedBox(height: 6),
                Text(
                  latest == null ? '—' : '1 US\$ = ${Money.formatRate(latest.zigPerUsd)} ZiG',
                  style: MariType.title2.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: Space.xxs),
                Text(
                  _fetchFailed == true
                      ? s[K.rateOffline]
                      : (latest == null ? s[K.rateFooterNever] : s.f(K.rateFooterUpdated, {'when': '${s.dayLabel(latest.at, DateTime.now())} ${s.time(latest.at)}'})),
                  style: MariType.footnote.copyWith(color: _fetchFailed == true ? c.spend : c.textSecondary),
                ),
                const SizedBox(height: Space.sm),
                MariButton(
                  label: _fetching ? s[K.refreshing] : s[K.refreshRate],
                  icon: Icons.refresh_rounded,
                  variant: ButtonVariant.secondary,
                  small: true,
                  expand: false,
                  onPressed: _fetching ? null : _refresh,
                ),
              ]),
            ),
            const SizedBox(height: Space.md),
            MariCard(
              child: SeparatedColumn(children: [
                MariListTile(
                  title: s[K.useMyOwnRate],
                  subtitle: s[K.useMyOwnRateBody],
                  trailing: MariSwitch(value: _manual, onChanged: (v) => setState(() => _manual = v)),
                ),
                if (_manual)
                  Padding(
                    padding: const EdgeInsets.all(Space.md),
                    child: MariTextField(
                      controller: _rate,
                      hint: '32.00',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: Space.sm),
            Text(s[K.rateExplainer], style: MariType.footnote.copyWith(color: c.textTertiary)),
          ]),
        ),
      ),
    ]);
  }
}

class LanguageSheet extends ConsumerWidget {
  const LanguageSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    final current = ref.watch(settingsProvider.select((x) => x.language));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SheetHeader(title: s[K.language], leading: s[K.done]),
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        child: MariCard(
          child: SeparatedColumn(children: [
            for (final l in AppLanguage.values)
              MariListTile(
                title: l.nativeName,
                subtitle: l.tagline,
                trailing: l == current ? Icon(Icons.check_rounded, color: c.accent) : null,
                chevron: false,
                onTap: () => ref.read(settingsProvider.notifier).edit((st) => st.copyWith(language: l)),
              ),
          ]),
        ),
      ),
    ]);
  }
}
