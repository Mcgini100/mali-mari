import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/money/money.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/budget_widgets.dart';
import '../../widgets/entry_tile.dart';
import '../../widgets/money.dart';
import '../../widgets/primitives.dart';
import '../entry/entry_sheet.dart';
import '../review/review_screen.dart';
import '../settings/settings_screen.dart';

/// The one screen people open the app for: how much is left this month.
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
    final display = ref.watch(displayCurrencyProvider);
    final settings = ref.watch(settingsProvider);
    final rate = ref.watch(currentRateProvider);
    final now = DateTime.now();
    final daysLeft = month.days - now.day;

    final hasBudget = summary?.hasBudget ?? false;
    final heroValue = summary == null ? 0 : (hasBudget ? summary.leftToSpend : summary.spent);
    final heroLabel = hasBudget ? s[K.leftToSpend] : s[K.spentThisMonth];

    return CustomScrollView(slivers: [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            // Header: date + settings
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 18),
              child: Row(children: [
                Expanded(child: Text(s.longDate(now), style: MariType.footnote.copyWith(color: c.textSecondary))),
                HeaderIconButton(
                  icon: Icons.settings_rounded,
                  label: s[K.settings],
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
                ),
              ]),
            ),

            // Hero
            Text('${heroLabel.toUpperCase()} · ${s.month(month.month).toUpperCase()}',
                style: MariType.caption.copyWith(color: c.textSecondary)),
            const SizedBox(height: 6),
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
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Segmented<Currency>(
                values: const [Currency.usd, Currency.zig],
                labelOf: (Currency x) => x.symbol,
                selected: display,
                onChanged: (Currency x) =>
                    ref.read(settingsProvider.notifier).edit((st) => st.copyWith(displayCurrency: x)),
              ),
              Text(
                s.f(K.rateLine, {
                  'rate': Money.formatRate(rate),
                  'source': settings.useManualRate ? s[K.rateMine] : s[K.rateOfficial],
                }),
                style: MariType.footnote.copyWith(color: c.textSecondary),
              ),
            ]),
            const SizedBox(height: 12),
            if (summary != null)
              Text(
                hasBudget
                    ? s.f(K.ofBudgetedDaysLeft, {
                        'amount': Money.format(summary.budgeted, display, cents: false),
                        'days': '$daysLeft',
                      })
                    : s.f(K.daysLeftInMonth, {'days': '$daysLeft'}),
                style: MariType.footnote.copyWith(color: c.textSecondary),
              ),
            const SizedBox(height: Space.lg),

            // Review queue
            if (pending.isNotEmpty) ...[
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
              const SizedBox(height: 28),
            ],

            // Budgets
            if (lines != null) ...[
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
                MariCard(child: SeparatedColumn(children: [for (final l in lines.take(4)) BudgetLineTile(line: l)])),
              const SizedBox(height: 28),
            ],

            // Recent
            if (entries != null) ...[
              SectionHeader(title: s[K.recent], action: entries.isEmpty ? null : s[K.seeAll], onAction: () => onOpenTab(1)),
              if (entries.isEmpty)
                MariCard(
                  child: EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: s[K.noEntriesTitle],
                    body: s[K.noEntriesBody],
                  ),
                )
              else
                MariCard(
                  child: SeparatedColumn(children: [
                    for (final e in entries.take(5))
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
