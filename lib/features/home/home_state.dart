import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/money/money.dart';
import '../../core/util/dates.dart';
import '../../domain/budget_math.dart';
import '../../domain/month_tree.dart';
import '../../domain/tree_tones.dart';

enum DayPart {
  morning,
  afternoon,
  evening;

  static DayPart of(DateTime t) => t.hour < 12
      ? DayPart.morning
      : t.hour < 17
          ? DayPart.afternoon
          : DayPart.evening;
}

/// Everything Home shows, worked out once and away from the widgets, so the
/// screen only lays things out and these numbers can be tested without it.
/// Money is in [display] minor units.
class HomeState {
  const HomeState({
    required this.now,
    required this.month,
    required this.display,
    required this.hasBudget,
    required this.heroMinor,
    required this.daysLeft,
    required this.perDayMinor,
    required this.usedFraction,
    required this.elapsedFraction,
    required this.pace,
    required this.tones,
    required this.leaves,
    required this.todayTone,
    required this.todaySpendMinor,
    required this.todayCount,
  });

  final DateTime now;
  final MonthRange month;
  final Currency display;
  final bool hasBudget;

  /// With a budget: what is left this month (negative when over).
  /// Without one: what has been spent.
  final int heroMinor;

  /// Days left in the month, today included. Never below 1.
  final int daysLeft;

  /// What is left, spread over [daysLeft]. Null without a budget or when over.
  final int? perDayMinor;

  /// Share of the budget used (can pass 1) and share of the month gone.
  final double usedFraction;
  final double elapsedFraction;
  final Pace pace;

  final Map<int, DayTone> tones;
  final int leaves;

  final DayTone todayTone;
  final int todaySpendMinor;
  final int todayCount;

  DayPart get dayPart => DayPart.of(now);
  bool get isOver => pace == Pace.over;
}

HomeState buildHomeState({
  required DateTime now,
  required MonthSummary summary,
  required Map<int, DayTone> tones,
  required Map<int, DayTotals> days,
  required Currency display,
  required double zigPerUsd,
}) {
  final month = MonthRange.of(now);
  final hasBudget = summary.hasBudget;
  final left = summary.leftToSpend;
  final daysLeft = (month.days - now.day + 1).clamp(1, month.days);
  final elapsed = now.day / month.days;
  final used = summary.usedFraction;

  final today = days[now.day];
  return HomeState(
    now: now,
    month: month,
    display: display,
    hasBudget: hasBudget,
    heroMinor: hasBudget ? left : summary.spent,
    daysLeft: daysLeft,
    perDayMinor: hasBudget && left >= 0 ? left ~/ daysLeft : null,
    usedFraction: used,
    elapsedFraction: elapsed,
    pace: paceOf(summary, elapsed: elapsed),
    tones: tones,
    leaves: tones.values.where((t) => t != DayTone.bud).length,
    todayTone: tones[now.day] ?? DayTone.bud,
    todaySpendMinor: Money.convert(today?.spendUsd ?? 0, Currency.usd, display, zigPerUsd),
    todayCount: today?.entries.length ?? 0,
  );
}

/// Null while the first read from the database is still on its way.
final homeStateProvider = Provider<HomeState?>((ref) {
  final month = ref.watch(currentMonthProvider);
  final summary = ref.watch(monthSummaryProvider(month));
  final tones = ref.watch(monthTonesProvider(month));
  final days = ref.watch(dayTotalsProvider(month));
  if (summary == null || tones == null || days == null) return null;
  // The clock is read for the hour (greeting); todayProvider makes this
  // recompute when the date changes.
  ref.watch(todayProvider);
  return buildHomeState(
    now: ref.watch(clockProvider)(),
    summary: summary,
    tones: tones,
    days: days,
    display: ref.watch(displayCurrencyProvider),
    zigPerUsd: ref.watch(currentRateProvider),
  );
});
