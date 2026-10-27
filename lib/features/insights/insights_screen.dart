import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/money/money.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/category_icons.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/dates.dart';
import '../../domain/budget_math.dart';
import '../../domain/month_tree.dart';
import '../../domain/tree_tones.dart';
import '../../widgets/budget_widgets.dart';
import '../../widgets/money.dart';
import '../../widgets/primitives.dart';
import '../budgets/budgets_screen.dart';
import '../tree/month_tree_view.dart';

/// The month in one plain sentence, the Seasons shelf (one tree per month),
/// then a few honest numbers. No scores, no streaks, no badges.
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  MonthRange? _month;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(settingsProvider.select((x) => x.language));
    final current = ref.watch(currentMonthProvider);
    final month = _month ?? current;
    final isCurrent = month.isSameAs(current);
    final display = ref.watch(displayCurrencyProvider);
    final cats = ref.watch(categoryMapProvider);
    final entries = ref.watch(monthEntriesProvider(month)).asData?.value;
    final prev = ref.watch(monthEntriesProvider(month.previous)).asData?.value;
    final summary = ref.watch(monthSummaryProvider(month));
    final lines = ref.watch(budgetLinesProvider(month));
    final seasons = ref.watch(seasonsProvider);
    final tones = ref.watch(monthTonesProvider(month));

    final children = <Widget>[ScreenTitle(title: s[K.insights], trailing: const CurrencySwitch())];
    if (entries == null || prev == null || summary == null || tones == null) {
      return ListView(padding: const EdgeInsets.symmetric(horizontal: Space.gutter), children: children);
    }

    final byCat = spendByCategory(entries, cats, display);
    final spent = summary.spent;
    final topName = byCat.isEmpty ? '' : (cats[byCat.first.key]?.name(lang) ?? s[K.uncategorised]).toLowerCase();
    final leaves = tones.values.where((t) => t != DayTone.bud).length;
    int count(Set<DayTone> which) => tones.values.where(which.contains).length;

    // The recap sentence.
    final String recap;
    if (byCat.isEmpty) {
      recap = s[K.recapEmpty];
    } else if (isCurrent && summary.hasBudget && lines != null) {
      recap = s.f(K.recapThisMonth, {
        'light': '${count({DayTone.light})}',
        'steady': '${count({DayTone.steady})}',
        'heavier': '${count({DayTone.full, DayTone.heavy})}',
        'within': '${lines.where((l) => !l.isOver).length}',
        'limits': '${lines.length}',
        'category': topName,
      });
    } else if (isCurrent) {
      recap = s.f(K.recapNoBudget, {
        'light': '${count({DayTone.light})}',
        'steady': '${count({DayTone.steady})}',
        'heavier': '${count({DayTone.full, DayTone.heavy})}',
        'category': topName,
      });
    } else {
      recap = s.f(K.recapPast, {'amount': Money.format(spent, display, cents: false), 'leaves': '$leaves', 'category': topName});
    }

    children.add(Container(
      padding: const EdgeInsets.fromLTRB(Space.md, 18, Space.md, 18),
      decoration: BoxDecoration(color: c.accentSoft, borderRadius: Radii.cardAll),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((isCurrent ? s[K.thisMonth] : s.monthYear(month)).toUpperCase(), style: MariType.caption.copyWith(color: c.accent)),
        const SizedBox(height: 6),
        Text(recap, style: MariType.body.copyWith(color: c.textPrimary, height: 25 / 17)),
      ]),
    ));

    // Seasons shelf.
    if (seasons != null && seasons.isNotEmpty) {
      children.add(const SizedBox(height: 26));
      children.add(SectionHeader(
        title: s[K.seasons],
        trailing: Text(s[K.oneTreeAMonth], style: MariType.footnote.copyWith(color: c.textSecondary)),
      ));
      children.add(GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.92,
        children: [
          for (final season in seasons)
            _SeasonTile(
              season: season,
              selected: season.month.isSameAs(month),
              subtitle: season.isCurrent
                  ? s.f(K.seasonLeavesSoFar, {'leaves': '${season.leaves}'})
                  : s.f(K.seasonSpent, {
                      'amount': Money.format(Money.convert(season.spentUsd, Currency.usd, display, ref.watch(currentRateProvider)), display, cents: false),
                      'category': season.topCategoryId == null ? '—' : (cats[season.topCategoryId]?.name(lang) ?? s[K.uncategorised]),
                    }),
              title: s.month(season.month.month),
              growingLabel: s[K.growing],
              onTap: () => setState(() => _month = season.isCurrent ? null : season.month),
            ),
        ],
      ));
    }

    if (byCat.isNotEmpty) {
      final stats = <Widget>[];
      if (summary.hasBudget) {
        stats.add(_Stat(
          label: s[K.spentAgainstBudget],
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Figure(
              big: '${(summary.usedFraction * 100).round()}%',
              small: '${Money.format(spent, display, cents: false)} ${s[K.of]} ${Money.format(summary.budgeted, display, cents: false)}',
            ),
            const SizedBox(height: 10),
            BudgetBar(progress: summary.usedFraction, height: 8),
          ]),
        ));
      }

      // For the month in progress, compare with the same days of last month.
      final today = DateTime.now().day;
      final prevComparable = isCurrent ? prev.where((e) => e.occurredAt.day <= today) : prev;
      final prevSpent = totalSpent(prevComparable, cats, display);
      if (prevSpent > 0) {
        final delta = (spent - prevSpent) / prevSpent;
        final less = spent < prevSpent;
        stats.add(_Stat(
          label: s.f(isCurrent ? K.comparedWithSoFar : K.comparedWith, {'month': s.month(month.previous.month)}),
          child: _Figure(
            big: '${less ? '−' : '+'}${(delta.abs() * 100).round()}%',
            bigColor: less ? c.income : c.spend,
            small: s.f(less ? (isCurrent ? K.lessSoFar : K.less) : (isCurrent ? K.moreSoFar : K.more), {
              'amount': Money.format((spent - prevSpent).abs(), display, cents: false),
            }),
          ),
        ));
      }
      if (stats.isNotEmpty) {
        children.add(const SizedBox(height: 26));
        children.add(MariCard(child: SeparatedColumn(children: stats)));
      }

      children.add(const SizedBox(height: 26));
      children.add(SectionHeader(title: s[K.whereItWent]));
      final max = byCat.first.value;
      children.add(MariCard(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 10),
        child: Column(children: [
          for (var i = 0; i < byCat.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                IconTile(icon: categoryIcon(cats[byCat[i].key]?.icon), tint: categoryTint(byCat[i].key), size: 26),
                const SizedBox(width: 10),
                SizedBox(
                  width: 96,
                  child: Text(cats[byCat[i].key]?.name(lang) ?? s[K.uncategorised],
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: MariType.callout.copyWith(fontSize: 14, color: c.textPrimary)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    child: Container(
                      height: 10,
                      color: c.surfaceSunken,
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: max == 0 ? 0 : byCat[i].value / max,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.tint(categoryTint(byCat[i].key)).ink.withValues(alpha: i == 0 ? 1 : 0.75),
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(Money.format(byCat[i].value, display, cents: false), style: MariType.footnote.copyWith(color: c.textSecondary)),
              ]),
            ),
        ]),
      ));
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(Space.xxs, 10, Space.xxs, 0),
        child: Text(s[K.insightsFootnote], style: MariType.footnote.copyWith(color: c.textTertiary)),
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
      children: children,
    );
  }
}

class _SeasonTile extends StatelessWidget {
  const _SeasonTile({
    required this.season,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.growingLabel,
    required this.onTap,
  });

  final Season season;
  final bool selected;
  final String title;
  final String subtitle;
  final String growingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? c.accent : c.separator, width: selected ? 2 : 0.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: RadialGradient(center: Alignment.bottomCenter, radius: 1.25, colors: [c.surface, c.sky]),
              ),
              child: Stack(children: [
                Positioned.fill(
                  child: MonthTreeView(
                    year: season.month.year,
                    month: season.month.month,
                    tones: season.tones,
                    animate: false,
                  ),
                ),
                if (season.isCurrent)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.pill)),
                      child: Text(growingLabel.toUpperCase(),
                          style: MariType.caption.copyWith(fontSize: 10, letterSpacing: 0.3, color: c.accent)),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(title, style: MariType.subhead.copyWith(fontWeight: FontWeight.w600, color: c.textPrimary)),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: MariType.footnote.copyWith(fontSize: 12, height: 16 / 12, color: c.textSecondary)),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(Space.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label.toUpperCase(), style: MariType.caption.copyWith(color: c.textSecondary)),
        const SizedBox(height: Space.xs),
        child,
      ]),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.big, required this.small, this.bigColor});
  final String big;
  final String small;
  final Color? bigColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: Space.xs, children: [
      Text(big, style: MariType.title1.copyWith(color: bigColor ?? c.textPrimary)),
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(small, style: MariType.callout.copyWith(color: c.textSecondary)),
      ),
    ]);
  }
}
