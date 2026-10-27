import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/money/money.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/dates.dart';
import '../../domain/month_tree.dart';
import '../../widgets/entry_tile.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sheet.dart';
import '../entry/entry_sheet.dart';
import 'month_tree_view.dart';

/// Opens one day of the month tree: its leaf, one kind sentence, its records,
/// and a way to add something forgotten.
Future<void> showDaySheet(BuildContext context, DateTime day) {
  return showMariSheet<void>(context, builder: (_) => _DaySheet(day: dateOnly(day)));
}

K toneTitle(DayTone tone) => switch (tone) {
      DayTone.bud => K.toneBud,
      DayTone.gold => K.toneGold,
      DayTone.light => K.toneLight,
      DayTone.steady => K.toneSteady,
      DayTone.full => K.toneFull,
      DayTone.heavy => K.toneHeavy,
    };

class _DaySheet extends ConsumerWidget {
  const _DaySheet({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    final month = MonthRange.of(day);
    final tone = ref.watch(monthTonesProvider(month))?[day.day] ?? DayTone.bud;
    final totals = ref.watch(dayTotalsProvider(month))?[day.day];
    final paceUsd = ref.watch(dailyPaceUsdProvider(month));
    final hasBudget = ref.watch(budgetTotalUsdProvider) > 0;
    final display = ref.watch(displayCurrencyProvider);
    final rate = ref.watch(currentRateProvider);

    String amount(int usd) => Money.format(Money.convert(usd, Currency.usd, display, rate), display);
    final spend = amount(totals?.spendUsd ?? 0);
    final pace = amount(paceUsd);
    final line = switch (tone) {
      DayTone.bud => s[K.dayBudBody],
      DayTone.gold => s.f(K.dayGoldBody, {'amount': amount(totals?.incomeUsd ?? 0)}),
      DayTone.light => s.f(hasBudget ? K.dayLightBody : K.dayLightPlain, {'amount': spend, 'pace': pace}),
      DayTone.steady => s.f(hasBudget ? K.daySteadyBody : K.daySteadyPlain, {'amount': spend, 'pace': pace}),
      DayTone.full => s.f(hasBudget ? K.dayFullBody : K.dayFullPlain, {'amount': spend, 'pace': pace}),
      DayTone.heavy => s.f(K.dayHeavyBody, {'amount': spend}),
    };
    final entries = totals?.entries ?? const [];

    return Column(mainAxisSize: MainAxisSize.min, children: [
      SheetHeader(
        title: s.longDate(day),
        leading: s[K.done],
      ),
      Flexible(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xxs, Space.gutter, Space.xl),
          children: [
            MariCard(
              padding: const EdgeInsets.all(Space.md),
              child: Row(children: [
                Container(
                  width: 34,
                  height: 26,
                  decoration: BoxDecoration(color: toneColor(tone, c), borderRadius: BorderRadius.circular(20)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s[toneTitle(tone)], style: MariType.headline.copyWith(color: c.textPrimary)),
                    const SizedBox(height: 2),
                    Text(line, style: MariType.footnote.copyWith(color: c.textSecondary)),
                  ]),
                ),
              ]),
            ),
            if (entries.isNotEmpty) ...[
              const SizedBox(height: Space.sm),
              MariCard(
                child: SeparatedColumn(children: [
                  for (final e in entries)
                    EntryTile(entry: e, onTap: () => showEntrySheet(context, entry: e, mode: EntrySheetMode.edit)),
                ]),
              ),
            ],
            const SizedBox(height: Space.sm),
            MariButton(
              label: s[K.addToThisDay],
              icon: Icons.add_rounded,
              variant: entries.isEmpty ? ButtonVariant.primary : ButtonVariant.secondary,
              onPressed: () async {
                final nav = Navigator.of(context);
                final root = Navigator.of(context, rootNavigator: true).context;
                nav.pop();
                await showEntrySheet(root, initialDate: day);
              },
            ),
          ],
        ),
      ),
    ]);
  }
}
