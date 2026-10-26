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
import '../../widgets/budget_widgets.dart';
import '../../widgets/money.dart';
import '../../widgets/primitives.dart';
import '../budgets/budgets_screen.dart';

/// Three numbers said plainly, then one ranked list. No chart wall.
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
    final display = ref.watch(displayCurrencyProvider);
    final cats = ref.watch(categoryMapProvider);
    final entries = ref.watch(monthEntriesProvider(month)).asData?.value;
    final prev = ref.watch(monthEntriesProvider(month.previous)).asData?.value;
    final summary = ref.watch(monthSummaryProvider(month));
    final isCurrent = month.isSameAs(current);

    final header = Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        HeaderIconButton(
          icon: Icons.chevron_left_rounded,
          label: s[K.previousMonth],
          onTap: () => setState(() => _month = month.previous),
        ),
        Expanded(
          child: Text(s.monthYear(month), textAlign: TextAlign.center, style: MariType.headline.copyWith(color: c.textPrimary)),
        ),
        HeaderIconButton(
          icon: Icons.chevron_right_rounded,
          label: s[K.nextMonth],
          onTap: isCurrent ? null : () => setState(() => _month = month.next),
        ),
      ]),
    );

    final children = <Widget>[ScreenTitle(title: s[K.insights], trailing: const CurrencySwitch()), header];

    if (entries == null || prev == null || summary == null) {
      return ListView(padding: const EdgeInsets.symmetric(horizontal: Space.gutter), children: children);
    }

    final byCat = spendByCategory(entries, cats, display);
    final spent = summary.spent;
    // For the month in progress, compare with the same days of last month, not all of it.
    final today = DateTime.now().day;
    final prevComparable = isCurrent ? prev.where((e) => e.occurredAt.day <= today) : prev;
    final prevSpent = totalSpent(prevComparable, cats, display);

    if (byCat.isEmpty) {
      children.add(MariCard(
        child: EmptyState(icon: Icons.insights_rounded, title: s[K.nothingSpentTitle], body: s[K.nothingSpentBody]),
      ));
    } else {
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

      final top = byCat.first;
      final topCat = cats[top.key];
      stats.add(_Stat(
        label: s[K.biggestCategory],
        child: Row(children: [
          IconTile(icon: categoryIcon(topCat?.icon)),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(topCat?.name(lang) ?? s[K.uncategorised], style: MariType.headline.copyWith(color: c.textPrimary)),
              Text(s.f(K.shareOfSpending, {'percent': '${(top.value / spent * 100).round()}'}),
                  style: MariType.footnote.copyWith(color: c.textSecondary)),
            ]),
          ),
          Text(Money.format(top.value, display, cents: false), style: MariType.headline.copyWith(color: c.textPrimary)),
        ]),
      ));

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

      children.add(MariCard(child: SeparatedColumn(children: stats)));
      children.add(const SizedBox(height: Space.lg));
      children.add(SectionHeader(title: s[K.whereItWent]));

      final max = byCat.first.value;
      children.add(MariCard(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 10),
        child: Column(children: [
          for (var i = 0; i < byCat.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                SizedBox(
                  width: 112,
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
                            color: i == 0 ? c.accent : c.textPrimary.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(Money.format(byCat[i].value, display, cents: false),
                    style: MariType.footnote.copyWith(color: c.textSecondary)),
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
