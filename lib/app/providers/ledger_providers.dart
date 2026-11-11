import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/dates.dart';
import '../../data/seed/default_categories.dart';
import '../../domain/budget_math.dart';
import '../../domain/models.dart';
import 'data_providers.dart';
import 'rate_providers.dart';
import 'settings_providers.dart';

// ---------------------------------------------------------------- catalog

final categoriesProvider = StreamProvider<List<Category>>((ref) => ref.watch(categoryRepositoryProvider).watchAll());

final categoryMapProvider = Provider<Map<String, Category>>((ref) {
  final list = ref.watch(categoriesProvider).asData?.value ?? defaultCategories;
  return {for (final c in list) c.id: c};
});

final budgetsProvider = StreamProvider<List<Budget>>((ref) => ref.watch(budgetRepositoryProvider).watchAll());

// ---------------------------------------------------------------- entries

final monthEntriesProvider = StreamProvider.family<List<Entry>, MonthRange>(
  (ref, month) => ref.watch(entryRepositoryProvider).watchMonth(month),
);

/// Every confirmed record, newest first. Only History (search across all
/// time) should watch this; month screens use [monthEntriesProvider].
final allEntriesProvider = StreamProvider<List<Entry>>((ref) => ref.watch(entryRepositoryProvider).watchConfirmed());

final pendingEntriesProvider = StreamProvider<List<Entry>>((ref) => ref.watch(entryRepositoryProvider).watchPending());

/// Budget lines for a month, or null while the first data is still loading.
final budgetLinesProvider = Provider.family<List<BudgetLine>?, MonthRange>((ref, month) {
  final budgets = ref.watch(budgetsProvider).asData?.value;
  final thisMonth = ref.watch(monthEntriesProvider(month)).asData?.value;
  final prevMonth = ref.watch(monthEntriesProvider(month.previous)).asData?.value;
  if (budgets == null || thisMonth == null || prevMonth == null) return null;
  return budgetLines(
    budgets: budgets,
    categories: ref.watch(categoryMapProvider),
    thisMonth: thisMonth,
    previousMonth: prevMonth,
  );
});

final monthSummaryProvider = Provider.family<MonthSummary?, MonthRange>((ref, month) {
  final lines = ref.watch(budgetLinesProvider(month));
  final entries = ref.watch(monthEntriesProvider(month)).asData?.value;
  if (lines == null || entries == null) return null;
  return summarize(
    lines: lines,
    thisMonth: entries,
    categories: ref.watch(categoryMapProvider),
    display: ref.watch(displayCurrencyProvider),
    zigPerUsd: ref.watch(currentRateProvider),
  );
});
