import 'package:flutter_test/flutter_test.dart';
import 'package:mari/core/money/money.dart';
import 'package:mari/core/util/dates.dart';
import 'package:mari/data/seed/default_categories.dart';
import 'package:mari/domain/models.dart';
import 'package:mari/domain/month_tree.dart';
import 'package:mari/domain/tree_tones.dart';

const rate = 26.66;
final cats = {for (final c in defaultCategories) c.id: c};
var _n = 0;

Entry e(DateTime at, double usd, {Direction dir = Direction.moneyOut, String cat = 'groceries', EntryStatus status = EntryStatus.confirmed}) {
  final minor = (usd * 100).round();
  final eq = Money.equivalents(minor, Currency.usd, rate);
  return Entry(
    id: 'e${_n++}',
    amountMinor: minor,
    currency: Currency.usd,
    usdMinor: eq.usd,
    zigMinor: eq.zig,
    rateUsed: rate,
    direction: dir,
    categoryId: cat,
    note: '',
    counterparty: '',
    occurredAt: at,
    source: EntrySource.manual,
    rawSourceText: null,
    status: status,
    sourceRef: null,
    createdAt: at,
  );
}

void main() {
  final oct = MonthRange(2026, 10);

  test('day totals count spending and income, not cash-outs or pending', () {
    final days = totalsByDay([
      e(DateTime(2026, 10, 3, 9), 12),
      e(DateTime(2026, 10, 3, 12), 50, cat: 'cash_out'),
      e(DateTime(2026, 10, 3, 18), 850, dir: Direction.moneyIn, cat: 'salary'),
      e(DateTime(2026, 10, 4), 99, status: EntryStatus.pendingReview),
    ], cats);
    expect(days.keys, [3]);
    expect(days[3]!.spendUsd, 1200);
    expect(days[3]!.incomeUsd, 85000);
    expect(days[3]!.entries, hasLength(3), reason: 'a cash-out still counts as logging the day');
  });

  test('pace is the budget per day, or the average spending day without one', () {
    final days = totalsByDay([e(DateTime(2026, 10, 1), 10), e(DateTime(2026, 10, 2), 30)], cats);
    expect(dailyPaceUsd(budgetUsd: 62000, month: oct, days: days), 2000);
    expect(dailyPaceUsd(budgetUsd: 0, month: oct, days: days), 2000);
    expect(dailyPaceUsd(budgetUsd: 0, month: oct, days: const {}), 0);
  });

  test('every day up to the last gets a tone; later days none', () {
    final days = totalsByDay([e(DateTime(2026, 10, 2), 40)], cats);
    final tones = toneMonth(days: days, pace: 2000, lastDay: 5);
    expect(tones.keys, [1, 2, 3, 4, 5]);
    expect(tones[1], DayTone.bud);
    expect(tones[2], DayTone.heavy);
  });

  test('last leaf day: today this month, all of a past month, none of a future one', () {
    final now = DateTime(2026, 10, 27, 18);
    expect(lastLeafDay(oct, now), 27);
    expect(lastLeafDay(MonthRange(2026, 9), now), 30);
    expect(lastLeafDay(MonthRange(2026, 11), now), 0);
  });

  test('seasons run from the first month with records to now, newest first', () {
    final now = DateTime(2026, 10, 27);
    final seasons = buildSeasons(
      allConfirmed: [
        e(DateTime(2026, 8, 5), 20, cat: 'transport'),
        e(DateTime(2026, 8, 6), 5),
        e(DateTime(2026, 10, 2), 9),
      ],
      cats: cats,
      budgetUsd: 0,
      now: now,
    );
    expect(seasons.map((s) => s.month.month), [10, 9, 8]);
    expect(seasons.first.isCurrent, isTrue);
    expect(seasons.last.topCategoryId, 'transport');
    expect(seasons.last.leaves, 2);
    expect(seasons[1].leaves, 0, reason: 'a month with nothing logged is all buds');
    expect(seasons.last.tones, hasLength(31));
  });

  test('with no records at all, the shelf still shows this month', () {
    final seasons = buildSeasons(allConfirmed: const [], cats: cats, budgetUsd: 0, now: DateTime(2026, 10, 27));
    expect(seasons, hasLength(1));
    expect(seasons.single.isCurrent, isTrue);
  });
}
