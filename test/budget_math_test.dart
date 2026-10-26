import 'package:flutter_test/flutter_test.dart';
import 'package:mari/core/money/money.dart';
import 'package:mari/data/seed/default_categories.dart';
import 'package:mari/domain/budget_math.dart';
import 'package:mari/domain/models.dart';

const rate = 26.66;
final cats = {for (final c in defaultCategories) c.id: c};

Entry entry(
  String id,
  double amount,
  Currency cur, {
  Direction dir = Direction.moneyOut,
  String? cat = 'groceries',
  EntryStatus status = EntryStatus.confirmed,
  DateTime? at,
}) {
  final minor = (amount * 100).round();
  final eq = Money.equivalents(minor, cur, rate);
  return Entry(
    id: id,
    amountMinor: minor,
    currency: cur,
    usdMinor: eq.usd,
    zigMinor: eq.zig,
    rateUsed: rate,
    direction: dir,
    categoryId: cat,
    note: '',
    counterparty: '',
    occurredAt: at ?? DateTime(2026, 10, 5),
    source: EntrySource.manual,
    rawSourceText: null,
    status: status,
    sourceRef: null,
    createdAt: DateTime(2026, 10, 5),
  );
}

void main() {
  test('spending excludes income, cash-outs and unconfirmed entries', () {
    final list = [
      entry('a', 10, Currency.usd),
      entry('b', 266.6, Currency.zig), // = US$10.00
      entry('c', 850, Currency.usd, dir: Direction.moneyIn, cat: 'salary'),
      entry('d', 50, Currency.usd, cat: 'cash_out'),
      entry('e', 99, Currency.usd, status: EntryStatus.pendingReview),
    ];
    expect(totalSpent(list, cats, Currency.usd), 2000);
    expect(totalIncome(list, cats, Currency.usd), 85000);
  });

  test('uncategorised spending counts, filed under other', () {
    final list = [entry('a', 5, Currency.usd, cat: null)];
    expect(totalSpent(list, cats, Currency.usd), 500);
    expect(spendByCategory(list, cats, Currency.usd).single.key, 'other');
  });

  test('budget lines measure in the budget currency and flag pace', () {
    final lines = budgetLines(
      budgets: const [
        Budget(categoryId: 'groceries', amountMinor: 10000, currency: Currency.usd),
        Budget(categoryId: 'transport', amountMinor: 1000, currency: Currency.usd),
      ],
      categories: cats,
      thisMonth: [
        entry('a', 90, Currency.usd),
        entry('b', 12, Currency.usd, cat: 'transport'),
      ],
    );
    final groceries = lines.firstWhere((l) => l.category.id == 'groceries');
    final transport = lines.firstWhere((l) => l.category.id == 'transport');
    expect(groceries.isNearLimit, isTrue);
    expect(transport.isOver, isTrue);
    expect(lines.first.category.id, 'transport', reason: 'most used first');
  });

  test('rollover adds last month\'s unspent amount, never a debt', () {
    const budget = Budget(categoryId: 'groceries', amountMinor: 10000, currency: Currency.usd, rollover: true);
    final under = budgetLines(
      budgets: const [budget],
      categories: cats,
      thisMonth: const [],
      previousMonth: [entry('p', 60, Currency.usd, at: DateTime(2026, 9, 3))],
    );
    expect(under.single.limit, 14000);

    final over = budgetLines(
      budgets: const [budget],
      categories: cats,
      thisMonth: const [],
      previousMonth: [entry('p', 150, Currency.usd, at: DateTime(2026, 9, 3))],
    );
    expect(over.single.limit, 10000);
  });

  test('summary converts budgets to the display currency', () {
    final lines = budgetLines(
      budgets: const [Budget(categoryId: 'groceries', amountMinor: 10000, currency: Currency.usd)],
      categories: cats,
      thisMonth: [entry('a', 40, Currency.usd)],
    );
    final s = summarize(lines: lines, thisMonth: [entry('a', 40, Currency.usd)], categories: cats, display: Currency.zig, zigPerUsd: rate);
    expect(s.budgeted, 266600);
    expect(s.spent, 106640);
    expect(s.leftToSpend, 266600 - 106640);
  });
}
