import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/money/money.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../domain/month_tree.dart';
import '../../widgets/budget_widgets.dart';
import '../../widgets/entry_tile.dart';
import '../../widgets/money.dart';
import '../../widgets/primitives.dart';
import '../entry/entry_sheet.dart';
import '../review/review_screen.dart';
import '../settings/settings_screen.dart';
import '../tree/day_sheet.dart';
import '../tree/month_tree_view.dart';

Map<DayTone, String> legendLabels(Strings s) => {
      DayTone.light: s[K.legendLight],
      DayTone.steady: s[K.legendSteady],
      DayTone.full: s[K.legendFull],
      DayTone.heavy: s[K.legendHeavy],
      DayTone.gold: s[K.legendGold],
      DayTone.bud: s[K.legendBud],
    };

/// The screen people open Mari for: this month's tree, what's left, and what
/// that means for today.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  /// Switches the shell to another tab (1 = history, 2 = budgets).
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    final month = ref.watch(currentMonthProvider);
    final summary = ref.watch(monthSummaryProvider(month));
    final lines = ref.watch(budgetLinesProvider(month));
    final entries = ref.watch(monthEntriesProvider(month)).asData?.value;
    final pending = ref.watch(pendingEntriesProvider).asData?.value ?? const [];
    final tones = ref.watch(monthTonesProvider(month));
    final days = ref.watch(dayTotalsProvider(month));
    final display = ref.watch(displayCurrencyProvider);
    final settings = ref.watch(settingsProvider);
    final rate = ref.watch(currentRateProvider);
    final now = DateTime.now();
    final daysLeft = month.days - now.day + 1; // including today

    final hasBudget = summary?.hasBudget ?? false;
    final heroValue = summary == null ? 0 : (hasBudget ? summary.leftToSpend : summary.spent);
    final heroLabel = hasBudget ? s[K.leftToSpend] : s[K.spentThisMonth];
    final leaves = tones?.values.where((t) => t != DayTone.bud).length ?? 0;

    final greeting = now.hour < 12
        ? s[K.greetMorning]
        : now.hour < 17
            ? s[K.greetAfternoon]
            : s[K.greetEvening];

    // Today, in one line.
    final today = days?[now.day];
    final todaySpend = Money.convert(today?.spendUsd ?? 0, Currency.usd, display, rate);
    final todayLine = today == null || !today.hasEntries
        ? s[K.todayNothing]
        : s.f(today.entries.length == 1 ? K.todayOne : K.todayMany, {
            'amount': Money.format(todaySpend, display),
            'count': '${today.entries.length}',
          });

    return CustomScrollView(slivers: [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            // Greeting + settings
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(greeting, style: MariType.title1.copyWith(fontSize: 26, height: 32 / 26, color: c.textPrimary)),
                    const SizedBox(height: 2),
                    Text(s.longDate(now), style: MariType.callout.copyWith(color: c.textSecondary)),
                  ]),
                ),
                HeaderIconButton(
                  icon: Icons.settings_rounded,
                  label: s[K.settings],
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
                ),
              ]),
            ),

            // The month tree
            _TreeCard(
              title: s[K.thisMonthsTree],
              meta: s.f(K.treeLeavesDay, {'leaves': '$leaves', 'day': '${now.day}'}),
              child: tones == null
                  ? const SizedBox.shrink()
                  : MonthTreeView(
                      year: month.year,
                      month: month.month,
                      tones: tones,
                      reveal: true,
                      semanticLabel: s.f(K.treeSemantics, {'month': s.month(month.month), 'leaves': '$leaves'}),
                      onDayTap: (d) => showDaySheet(context, DateTime(month.year, month.month, d)),
                    ),
              legend: TreeLegend(labels: legendLabels(s)),
            ),

            // What's left
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text('${heroLabel.toUpperCase()} · ${s.month(month.month).toUpperCase()}',
                  style: MariType.caption.copyWith(color: c.textSecondary)),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 52,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedMoney(
                  minor: heroValue,
                  currency: display,
                  style: MariType.display.copyWith(color: hasBudget && heroValue < 0 ? c.spend : c.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Segmented<Currency>(
                values: const [Currency.usd, Currency.zig],
                labelOf: (x) => x.symbol,
                selected: display,
                onChanged: (x) => ref.read(settingsProvider.notifier).edit((st) => st.copyWith(displayCurrency: x)),
              ),
              Text(
                s.f(K.rateLine, {
                  'rate': Money.formatRate(rate),
                  'source': settings.useManualRate ? s[K.rateMine] : s[K.rateOfficial],
                }),
                style: MariType.footnote.copyWith(color: c.textSecondary),
              ),
            ]),

            // What that means for today
            const SizedBox(height: 14),
            _PaceCard(
              title: !hasBudget || summary == null
                  ? s[K.todayTitle]
                  : summary.leftToSpend >= 0
                      ? s.f(K.paceTitle, {'amount': Money.format(summary.leftToSpend ~/ daysLeft, display)})
                      : s.f(K.paceOverTitle, {'amount': Money.format(-summary.leftToSpend, display, cents: false)}),
              body: !hasBudget || summary == null
                  ? todayLine
                  : '${summary.leftToSpend >= 0 ? s.f(K.paceBody, {'days': '$daysLeft', 'month': s.month(month.month)}) : s[K.paceOverBody]} $todayLine',
            ),

            // Review queue
            if (pending.isNotEmpty) ...[
              const SizedBox(height: Space.sm),
              Pressable(
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ReviewScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 14),
                  decoration: BoxDecoration(color: c.accentSoft, borderRadius: Radii.cardAll),
                  child: Row(children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                      child: Text('${pending.length}', style: MariType.subhead.copyWith(color: c.onAccent, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.f(K.toReview, {'count': '${pending.length}'}), style: MariType.headline.copyWith(color: c.textPrimary)),
                        Text(s[K.toReviewSub], style: MariType.footnote.copyWith(color: c.textSecondary)),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.accent),
                  ]),
                ),
              ),
            ],

            // Budgets
            if (lines != null) ...[
              const SizedBox(height: 26),
              SectionHeader(title: s[K.budgets], action: s[K.seeAll], onAction: () => onOpenTab(2)),
              if (lines.isEmpty)
                MariCard(
                  child: EmptyState(
                    icon: Icons.pie_chart_outline_rounded,
                    title: s[K.noBudgetsTitle],
                    body: s[K.noBudgetsBody],
                    action: MariButton(label: s[K.setALimit], small: true, expand: false, onPressed: () => onOpenTab(2)),
                  ),
                )
              else
                MariCard(child: SeparatedColumn(children: [for (final l in lines.take(3)) BudgetLineTile(line: l)])),
            ],

            // Recent
            if (entries != null) ...[
              const SizedBox(height: 26),
              SectionHeader(title: s[K.recent], action: entries.isEmpty ? null : s[K.seeAll], onAction: () => onOpenTab(1)),
              if (entries.isEmpty)
                MariCard(child: EmptyState(icon: Icons.eco_rounded, title: s[K.noEntriesTitle], body: s[K.noEntriesBody]))
              else
                MariCard(
                  child: SeparatedColumn(children: [
                    for (final e in entries.take(4))
                      EntryTile(entry: e, onTap: () => showEntrySheet(context, entry: e, mode: EntrySheetMode.edit)),
                  ]),
                ),
            ],
            const SizedBox(height: Space.xl),
          ]),
        ),
      ),
    ]);
  }
}

class _TreeCard extends StatelessWidget {
  const _TreeCard({required this.title, required this.meta, required this.child, required this.legend});
  final String title;
  final String meta;
  final Widget child;
  final Widget legend;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        borderRadius: Radii.cardAll,
        gradient: RadialGradient(
          center: Alignment.bottomCenter,
          radius: 1.25,
          colors: [c.surface, c.sky],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(title.toUpperCase(), style: MariType.caption.copyWith(color: c.textSecondary))),
          Text(meta, style: MariType.footnote.copyWith(color: c.textSecondary)),
        ]),
        const SizedBox(height: 6),
        SizedBox(height: 236, child: child),
        const SizedBox(height: 4),
        legend,
      ]),
    );
  }
}

class _PaceCard extends StatelessWidget {
  const _PaceCard({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 14),
      decoration: BoxDecoration(color: c.warmSoft, borderRadius: Radii.cardAll),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.wb_sunny_rounded, color: c.warm, size: 24),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: MariType.headline.copyWith(color: c.textPrimary)),
            const SizedBox(height: 2),
            Text(body, style: MariType.footnote.copyWith(color: c.textSecondary)),
          ]),
        ),
      ]),
    );
  }
}
