import '../core/money/money.dart';
import '../core/util/dates.dart';
import 'budget_math.dart';
import 'models.dart';
import 'month_tree.dart';

/// Spend and income for one calendar day, in US$ minor units (each entry's
/// frozen equivalent, so a day never changes colour when the rate moves).
class DayTotals {
  const DayTotals({required this.spendUsd, required this.incomeUsd, required this.entries});
  final int spendUsd;
  final int incomeUsd;
  final List<Entry> entries;
  bool get hasEntries => entries.isNotEmpty;
}

Map<int, DayTotals> totalsByDay(Iterable<Entry> monthEntries, Map<String, Category> cats) {
  final spend = <int, int>{};
  final income = <int, int>{};
  final lists = <int, List<Entry>>{};
  for (final e in monthEntries) {
    if (e.status != EntryStatus.confirmed) continue;
    final d = e.occurredAt.day;
    lists.putIfAbsent(d, () => []).add(e);
    final kind = cats[e.categoryId]?.kind ?? (e.direction == Direction.moneyIn ? CategoryKind.income : CategoryKind.expense);
    if (e.direction == Direction.moneyOut && kind == CategoryKind.expense) spend[d] = (spend[d] ?? 0) + e.usdMinor;
    if (e.direction == Direction.moneyIn && kind != CategoryKind.transfer) income[d] = (income[d] ?? 0) + e.usdMinor;
  }
  return {
    for (final d in lists.keys)
      d: DayTotals(spendUsd: spend[d] ?? 0, incomeUsd: income[d] ?? 0, entries: lists[d]!..sort((a, b) => a.occurredAt.compareTo(b.occurredAt))),
  };
}

/// The daily pace a day is measured against: the month's budget spread over
/// its days, or with no budget, the average spend on days that had any.
int dailyPaceUsd({required int budgetUsd, required MonthRange month, required Map<int, DayTotals> days}) {
  if (budgetUsd > 0) return (budgetUsd / month.days).round();
  final spendDays = days.values.where((d) => d.spendUsd > 0).toList();
  if (spendDays.isEmpty) return 0;
  return (spendDays.fold<int>(0, (a, d) => a + d.spendUsd) / spendDays.length).round();
}

/// A tone for every day from 1 to [lastDay]; days after it have no leaf yet.
Map<int, DayTone> toneMonth({required Map<int, DayTotals> days, required int pace, required int lastDay}) {
  return {
    for (var d = 1; d <= lastDay; d++)
      d: dayTone(
        spend: days[d]?.spendUsd ?? 0,
        income: days[d]?.incomeUsd ?? 0,
        pace: pace,
        hasEntries: days[d]?.hasEntries ?? false,
      ),
  };
}

/// The last day of [month] that can have a leaf, as seen from [now].
int lastLeafDay(MonthRange month, DateTime now) {
  final current = MonthRange.of(now);
  if (month.isSameAs(current)) return now.day;
  return month.start.isAfter(now) ? 0 : month.days;
}

/// Sum of all budget limits in US$ at [zigPerUsd].
int budgetTotalUsd(Iterable<Budget> budgets, double zigPerUsd) =>
    budgets.fold<int>(0, (a, b) => a + Money.convert(b.amountMinor, b.currency, Currency.usd, zigPerUsd));

/// One month on the Seasons shelf.
class Season {
  const Season({
    required this.month,
    required this.tones,
    required this.spentUsd,
    required this.topCategoryId,
    required this.isCurrent,
  });

  final MonthRange month;
  final Map<int, DayTone> tones;
  final int spentUsd;
  final String? topCategoryId;
  final bool isCurrent;

  int get leaves => tones.values.where((t) => t != DayTone.bud).length;
  int count(Set<DayTone> which) => tones.values.where(which.contains).length;
}

/// Every month from the first one with a record up to now, newest first,
/// at most [limit] of them. The current month is always included.
List<Season> buildSeasons({
  required List<Entry> allConfirmed,
  required Map<String, Category> cats,
  required int budgetUsd,
  required DateTime now,
  int limit = 12,
}) {
  final byMonth = <MonthRange, List<Entry>>{};
  for (final e in allConfirmed) {
    byMonth.putIfAbsent(MonthRange.of(e.occurredAt), () => []).add(e);
  }
  final current = MonthRange.of(now);
  var first = current;
  for (final m in byMonth.keys) {
    if (m.start.isBefore(first.start)) first = m;
  }

  final seasons = <Season>[];
  for (var m = current; !m.start.isBefore(first.start) && seasons.length < limit; m = m.previous) {
    final entries = byMonth[m] ?? const <Entry>[];
    final days = totalsByDay(entries, cats);
    final pace = dailyPaceUsd(budgetUsd: budgetUsd, month: m, days: days);
    final byCat = spendByCategory(entries, cats, Currency.usd);
    seasons.add(Season(
      month: m,
      tones: toneMonth(days: days, pace: pace, lastDay: lastLeafDay(m, now)),
      spentUsd: totalSpent(entries, cats, Currency.usd),
      topCategoryId: byCat.isEmpty ? null : byCat.first.key,
      isCurrent: m.isSameAs(current),
    ));
  }
  return seasons;
}
