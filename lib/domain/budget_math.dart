import '../core/money/money.dart';
import 'models.dart';

/// Pure functions over confirmed entries. Nothing here touches the database,
/// so it is all unit-tested in test/budget_math_test.dart.

bool _countsAsSpend(Entry e, Map<String, Category> cats) {
  if (e.status != EntryStatus.confirmed || e.direction != Direction.moneyOut) return false;
  final kind = cats[e.categoryId]?.kind ?? CategoryKind.expense;
  return kind == CategoryKind.expense;
}

bool _countsAsIncome(Entry e, Map<String, Category> cats) {
  if (e.status != EntryStatus.confirmed || e.direction != Direction.moneyIn) return false;
  final kind = cats[e.categoryId]?.kind ?? CategoryKind.income;
  return kind != CategoryKind.transfer;
}

/// Spending in [currency] using each entry's frozen equivalent.
int totalSpent(Iterable<Entry> entries, Map<String, Category> cats, Currency currency, {String? categoryId}) {
  var sum = 0;
  for (final e in entries) {
    if (!_countsAsSpend(e, cats)) continue;
    if (categoryId != null && (e.categoryId ?? 'other') != categoryId) continue;
    sum += e.amountIn(currency);
  }
  return sum;
}

int totalIncome(Iterable<Entry> entries, Map<String, Category> cats, Currency currency) {
  var sum = 0;
  for (final e in entries) {
    if (_countsAsIncome(e, cats)) sum += e.amountIn(currency);
  }
  return sum;
}

/// Spend per category id in [currency], largest first.
List<MapEntry<String, int>> spendByCategory(Iterable<Entry> entries, Map<String, Category> cats, Currency currency) {
  final map = <String, int>{};
  for (final e in entries) {
    if (!_countsAsSpend(e, cats)) continue;
    final id = e.categoryId ?? 'other';
    map[id] = (map[id] ?? 0) + e.amountIn(currency);
  }
  final list = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return list;
}

class BudgetLine {
  const BudgetLine({required this.category, required this.budget, required this.spent, required this.limit});

  final Category category;
  final Budget budget;

  /// Both in the budget's own currency.
  final int spent;
  final int limit;

  double get progress => limit <= 0 ? 0 : spent / limit;
  bool get isOver => spent > limit;
  bool get isNearLimit => !isOver && progress >= 0.85;
  int get remaining => limit - spent;
}

/// Lines for every budgeted category. With rollover on, unspent money from
/// [previousMonth] is added to this month's limit (never a negative carry).
List<BudgetLine> budgetLines({
  required Iterable<Budget> budgets,
  required Map<String, Category> categories,
  required Iterable<Entry> thisMonth,
  Iterable<Entry> previousMonth = const [],
}) {
  final lines = <BudgetLine>[];
  for (final b in budgets) {
    final cat = categories[b.categoryId];
    if (cat == null) continue;
    final spent = totalSpent(thisMonth, categories, b.currency, categoryId: b.categoryId);
    var limit = b.amountMinor;
    if (b.rollover) {
      final prevSpent = totalSpent(previousMonth, categories, b.currency, categoryId: b.categoryId);
      final carry = b.amountMinor - prevSpent;
      if (carry > 0) limit += carry;
    }
    lines.add(BudgetLine(category: cat, budget: b, spent: spent, limit: limit));
  }
  lines.sort((a, b) {
    final c = b.progress.compareTo(a.progress);
    return c != 0 ? c : a.category.sortOrder.compareTo(b.category.sortOrder);
  });
  return lines;
}

class MonthSummary {
  const MonthSummary({required this.currency, required this.spent, required this.income, required this.budgeted});

  final Currency currency;
  final int spent;
  final int income;

  /// Sum of all limits converted into [currency] at today's rate (0 when no budgets).
  final int budgeted;

  bool get hasBudget => budgeted > 0;
  int get leftToSpend => budgeted - spent;
  double get usedFraction => budgeted <= 0 ? 0 : spent / budgeted;
}

MonthSummary summarize({
  required List<BudgetLine> lines,
  required Iterable<Entry> thisMonth,
  required Map<String, Category> categories,
  required Currency display,
  required double zigPerUsd,
}) {
  var budgeted = 0;
  for (final l in lines) {
    budgeted += Money.convert(l.limit, l.budget.currency, display, zigPerUsd);
  }
  return MonthSummary(
    currency: display,
    spent: totalSpent(thisMonth, categories, display),
    income: totalIncome(thisMonth, categories, display),
    budgeted: budgeted,
  );
}
