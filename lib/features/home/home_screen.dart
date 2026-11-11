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
import '../tree/leaf_key_sheet.dart';
import '../tree/month_tree_view.dart';
import 'home_state.dart';

/// The screen people open Mari for. One object answers the two questions in
/// order: the number (what is left, and what that means per day), then the
/// month's tree underneath it. Everything else on the screen is a list.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  /// Switches the shell to another tab (1 = history, 2 = budgets).
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    final state = ref.watch(homeStateProvider);
    final month = ref.watch(currentMonthProvider);
    final today = ref.watch(todayProvider);
    final lines = ref.watch(budgetLinesProvider(month));
    final entries = ref.watch(monthEntriesProvider(month)).asData?.value;
    final pending = ref.watch(pendingEntriesProvider).asData?.value ?? const [];

    // Read at build time, so the greeting is right whenever the screen is redrawn.
    final greeting = switch (DayPart.of(ref.watch(clockProvider)())) {
      DayPart.morning => s[K.greetMorning],
      DayPart.afternoon => s[K.greetAfternoon],
      DayPart.evening => s[K.greetEvening],
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Space.xxs, bottom: Space.sm),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(greeting, style: MariType.title2.copyWith(color: c.textPrimary)),
                Text(s.longDate(today), style: MariType.callout.copyWith(color: c.textSecondary)),
              ]),
            ),
            HeaderIconButton(
              icon: Icons.settings_rounded,
              label: s[K.settings],
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
            ),
          ]),
        ),

        _MonthCard(state: state),

        if (state != null) ...[
          const SizedBox(height: Space.sm),
          _TodayRow(state: state, onTap: () => showDaySheet(context, today)),
        ],

        if (pending.isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          _ReviewBanner(count: pending.length),
        ],

        if (lines != null) ...[
          const SizedBox(height: 28),
          SectionHeader(title: s[K.budgets], action: lines.isEmpty ? null : s[K.seeAll], onAction: () => onOpenTab(2)),
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

        if (entries != null) ...[
          const SizedBox(height: 28),
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
      ],
    );
  }
}

/// The month in one object: what is left, how that sits against the calendar,
/// and the tree the month has grown so far.
class _MonthCard extends ConsumerWidget {
  const _MonthCard({required this.state});

  /// Null while the first read is on its way; the card keeps its size so
  /// nothing below it jumps.
  final HomeState? state;

  static const double _treeHeight = 208;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    final st = state;

    final Widget body;
    if (st == null) {
      body = const SizedBox(height: _treeHeight + 150);
    } else {
      final monthName = s.month(st.month.month);
      final rate = ref.watch(currentRateProvider);
      final manualRate = ref.watch(settingsProvider.select((x) => x.useManualRate));
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(
              st.hasBudget ? s.f(K.leftToSpendIn, {'month': monthName}) : s.f(K.spentInMonth, {'month': monthName}),
              style: MariType.subhead.copyWith(color: c.textSecondary),
            ),
          ),
          const SizedBox(width: Space.xs),
          Segmented<Currency>(
            values: const [Currency.usd, Currency.zig],
            labelOf: (x) => x.symbol,
            selected: st.display,
            onChanged: (x) => ref.read(settingsProvider.notifier).edit((v) => v.copyWith(displayCurrency: x)),
          ),
        ]),
        const SizedBox(height: Space.xxs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: AnimatedMoney(
            minor: st.heroMinor,
            currency: st.display,
            style: MariType.display.copyWith(color: st.isOver ? c.spend : c.textPrimary),
          ),
        ),
        if (st.hasBudget) ...[
          const SizedBox(height: Space.xs),
          PaceTrack(
            used: st.usedFraction,
            elapsed: st.elapsedFraction,
            pace: st.pace,
            semanticLabel: s.f(K.paceLine, {
              'day': '${st.now.day}',
              'days': '${st.month.days}',
              'used': '${(st.usedFraction * 100).round()}',
              'elapsed': '${(st.elapsedFraction * 100).round()}',
            }),
          ),
          const SizedBox(height: Space.xs),
          _paceSentence(s, st, monthName, c),
        ],
        const SizedBox(height: 2),
        Text(
          s.f(K.rateLine, {'rate': Money.formatRate(rate), 'source': manualRate ? s[K.rateMine] : s[K.rateOfficial]}),
          style: MariType.footnote.copyWith(color: c.textSecondary),
        ),
        SizedBox(
          height: _treeHeight,
          child: MonthTreeView(
            year: st.month.year,
            month: st.month.month,
            tones: st.tones,
            reveal: true,
            semanticLabel: s.f(K.treeSemantics, {'month': monthName, 'leaves': '${st.leaves}'}),
            onDayTap: (d) => showDaySheet(context, DateTime(st.month.year, st.month.month, d)),
          ),
        ),
        Row(children: [
          Expanded(
            child: Text(
              s.f(K.treeLeavesDay, {'leaves': '${st.leaves}', 'day': '${st.now.day}'}),
              style: MariType.footnote.copyWith(color: c.textSecondary),
            ),
          ),
          _LeafKeyButton(label: s[K.leafKeyTitle]),
        ]),
      ]);
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: Radii.heroAll,
        gradient: RadialGradient(center: Alignment.bottomCenter, radius: 1.25, colors: [c.surface, c.sky]),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.xxs),
      child: body,
    );
  }

  /// The per-day figure carries the weight; the rest of the sentence is quieter.
  static Widget _paceSentence(Strings s, HomeState st, String monthName, MariPalette c) {
    final perDay = st.perDayMinor;
    final String lead;
    final String rest;
    if (perDay == null) {
      lead = '${s.f(K.paceOverTitle, {'amount': Money.format(-st.heroMinor, st.display, cents: false)})}.';
      rest = s[K.paceOverBody];
    } else {
      lead = s.f(K.paceTitle, {'amount': Money.format(perDay, st.display)});
      rest = s.f(K.paceBody, {'days': '${st.daysLeft}', 'month': monthName});
    }
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: lead, style: MariType.subhead.copyWith(fontWeight: FontWeight.w600, color: c.textPrimary)),
        TextSpan(text: ' $rest', style: MariType.callout.copyWith(color: c.textSecondary)),
      ]),
    );
  }
}

/// Five leaves in a row: the key to the tree's colours, one tap away.
class _LeafKeyButton extends StatelessWidget {
  const _LeafKeyButton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: () => showLeafKeySheet(context),
      semanticLabel: label,
      child: SizedBox(
        height: Space.tapTarget,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final tone in kLeafKeyOrder.where((t) => t != DayTone.bud)) ...[
            LeafDot(tone: tone),
            const SizedBox(width: 3),
          ],
          const SizedBox(width: 3),
          Icon(Icons.info_outline_rounded, size: 18, color: c.textSecondary),
        ]),
      ),
    );
  }
}

/// Today in one line, with today's leaf. Opens the day.
class _TodayRow extends ConsumerWidget {
  const _TodayRow({required this.state, required this.onTap});
  final HomeState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    final line = state.todayCount == 0
        ? s[K.todayNothing]
        : s.f(state.todayCount == 1 ? K.todayOne : K.todayMany, {
            'amount': Money.format(state.todaySpendMinor, state.display),
            'count': '${state.todayCount}',
          });
    return Pressable(
      onTap: onTap,
      child: MariCard(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 14),
        child: Row(children: [
          LeafDot(tone: state.todayTone, width: 22, height: 17),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(line, style: MariType.callout.copyWith(color: c.textPrimary))),
          Icon(Icons.chevron_right_rounded, size: 20, color: c.textTertiary),
        ]),
      ),
    );
  }
}

class _ReviewBanner extends ConsumerWidget {
  const _ReviewBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    return Pressable(
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
            child: Text('$count', style: MariType.subhead.copyWith(color: c.onAccent, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.f(K.toReview, {'count': '$count'}), style: MariType.headline.copyWith(color: c.textPrimary)),
              Text(s[K.toReviewSub], style: MariType.footnote.copyWith(color: c.textSecondary)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: c.accent),
        ]),
      ),
    );
  }
}
