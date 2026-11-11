import 'package:flutter_test/flutter_test.dart';
import 'package:mari/core/money/money.dart';
import 'package:mari/domain/budget_math.dart';
import 'package:mari/domain/month_tree.dart';
import 'package:mari/domain/tree_tones.dart';
import 'package:mari/features/home/home_state.dart';

const rate = 26.66;

HomeState state({
  required DateTime now,
  int spent = 0,
  int budgeted = 0,
  Map<int, DayTone> tones = const {},
  Map<int, DayTotals> days = const {},
  Currency display = Currency.usd,
}) =>
    buildHomeState(
      now: now,
      summary: MonthSummary(currency: display, spent: spent, income: 0, budgeted: budgeted),
      tones: tones,
      days: days,
      display: display,
      zigPerUsd: rate,
    );

void main() {
  test('with a budget the hero is what is left, spread over the days left including today', () {
    final s = state(now: DateTime(2026, 10, 27, 18, 40), spent: 45118, budgeted: 60000);
    expect(s.hasBudget, isTrue);
    expect(s.heroMinor, 14882);
    expect(s.daysLeft, 5); // 27, 28, 29, 30, 31
    expect(s.perDayMinor, 14882 ~/ 5);
    expect(s.isOver, isFalse);
  });

  test('without a budget the hero is what was spent and there is no pace', () {
    final s = state(now: DateTime(2026, 10, 9), spent: 12000);
    expect(s.hasBudget, isFalse);
    expect(s.heroMinor, 12000);
    expect(s.perDayMinor, isNull);
    expect(s.pace, Pace.none);
  });

  test('over budget: negative hero, no per-day figure, pace is over', () {
    final s = state(now: DateTime(2026, 10, 20), spent: 70000, budgeted: 60000);
    expect(s.heroMinor, -10000);
    expect(s.perDayMinor, isNull);
    expect(s.pace, Pace.over);
    expect(s.isOver, isTrue);
  });

  test('pace compares budget used with how much of the month has gone', () {
    // Day 15 of 30: half the month.
    final now = DateTime(2026, 11, 15);
    expect(state(now: now, spent: 30000, budgeted: 60000).pace, Pace.onTrack); // 50% used
    expect(state(now: now, spent: 34000, budgeted: 60000).pace, Pace.onTrack); // within tolerance
    expect(state(now: now, spent: 40000, budgeted: 60000).pace, Pace.ahead); // 67% used
    expect(state(now: DateTime(2026, 11, 29), spent: 52000, budgeted: 60000).pace, Pace.ahead); // 87% used, near the limit
  });

  test('the last day of the month still has one day left, never zero', () {
    final s = state(now: DateTime(2026, 2, 28, 23, 59), spent: 100, budgeted: 1100);
    expect(s.daysLeft, 1);
    expect(s.perDayMinor, 1000);
    expect(s.elapsedFraction, 1.0);
  });

  test('leaves count logged days; today reads from the tones and day totals', () {
    final s = state(
      now: DateTime(2026, 10, 3, 9),
      tones: const {1: DayTone.light, 2: DayTone.bud, 3: DayTone.steady},
      days: const {3: DayTotals(spendUsd: 1375, incomeUsd: 0, entries: [])},
      display: Currency.zig,
    );
    expect(s.leaves, 2);
    expect(s.todayTone, DayTone.steady);
    expect(s.todaySpendMinor, Money.convert(1375, Currency.usd, Currency.zig, rate));
    expect(s.dayPart, DayPart.morning);
  });

  test('day parts follow the greeting hours', () {
    expect(DayPart.of(DateTime(2026, 1, 1, 0)), DayPart.morning);
    expect(DayPart.of(DateTime(2026, 1, 1, 12)), DayPart.afternoon);
    expect(DayPart.of(DateTime(2026, 1, 1, 17)), DayPart.evening);
  });
}
