import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/dates.dart';
import '../../domain/models.dart';
import '../../domain/month_tree.dart';
import '../../domain/tree_tones.dart';
import 'data_providers.dart';
import 'ledger_providers.dart';
import 'rate_providers.dart';
import 'time_providers.dart';

/// How many months the Seasons shelf keeps.
const int kSeasonsShown = 12;

/// Budget total in US$ at today's rate (0 when there are no limits).
final budgetTotalUsdProvider = Provider<int>((ref) {
  final budgets = ref.watch(budgetsProvider).asData?.value ?? const <Budget>[];
  return budgetTotalUsd(budgets, ref.watch(currentRateProvider));
});

/// Spend, income and records per day of [month], or null while loading.
final dayTotalsProvider = Provider.family<Map<int, DayTotals>?, MonthRange>((ref, month) {
  final entries = ref.watch(monthEntriesProvider(month)).asData?.value;
  if (entries == null) return null;
  return totalsByDay(entries, ref.watch(categoryMapProvider));
});

/// The daily pace leaves are measured against, in US$ minor units.
final dailyPaceUsdProvider = Provider.family<int, MonthRange>((ref, month) {
  return dailyPaceUsd(
    budgetUsd: ref.watch(budgetTotalUsdProvider),
    month: month,
    days: ref.watch(dayTotalsProvider(month)) ?? const {},
  );
});

/// One tone per day that has happened so far in [month], or null while loading.
final monthTonesProvider = Provider.family<Map<int, DayTone>?, MonthRange>((ref, month) {
  final days = ref.watch(dayTotalsProvider(month));
  if (days == null) return null;
  return toneMonth(
    days: days,
    pace: ref.watch(dailyPaceUsdProvider(month)),
    lastDay: lastLeafDay(month, ref.watch(todayProvider)),
  );
});

/// Records for the months the shelf can show, and no further back: the query
/// stays the same size however many years of history there are.
final seasonEntriesProvider = StreamProvider<List<Entry>>((ref) {
  final current = ref.watch(currentMonthProvider);
  final from = DateTime(current.year, current.month - (kSeasonsShown - 1));
  return ref.watch(entryRepositoryProvider).watchConfirmed(from: from);
});

/// The Seasons shelf: up to [kSeasonsShown] months, newest first, the current month always included.
final seasonsProvider = Provider<List<Season>?>((ref) {
  final entries = ref.watch(seasonEntriesProvider).asData?.value;
  if (entries == null) return null;
  return buildSeasons(
    allConfirmed: entries,
    cats: ref.watch(categoryMapProvider),
    budgetUsd: ref.watch(budgetTotalUsdProvider),
    now: ref.watch(todayProvider),
    limit: kSeasonsShown,
  );
});
