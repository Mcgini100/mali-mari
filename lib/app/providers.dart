import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/strings.dart';
import '../core/money/money.dart';
import '../core/util/dates.dart';
import '../data/db/database.dart';
import '../data/rates/rate_fetcher.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/repositories/entry_repository.dart';
import '../data/seed/default_categories.dart';
import '../domain/budget_math.dart';
import '../domain/models.dart';
import '../domain/month_tree.dart';
import '../domain/tree_tones.dart';
import 'settings.dart';

// ---------------------------------------------------------------- data layer

/// Overridden in main() with the opened database.
final databaseProvider = Provider<MariDatabase>((ref) => throw UnimplementedError('databaseProvider must be overridden'));

/// Overridden in main() with settings read before the first frame.
final initialSettingsProvider = Provider<AppSettings>((ref) => const AppSettings());

final entryRepositoryProvider = Provider<EntryRepository>((ref) => DriftEntryRepository(ref.watch(databaseProvider)));
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) => DriftCategoryRepository(ref.watch(databaseProvider)));
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) => DriftBudgetRepository(ref.watch(databaseProvider)));
final rateRepositoryProvider = Provider<RateRepository>((ref) => DriftRateRepository(ref.watch(databaseProvider)));
final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore(ref.watch(databaseProvider)));
final rateFetcherProvider = Provider<RateFetcher>((ref) => OpenExchangeRateFetcher());

// ---------------------------------------------------------------- settings

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  Future<void> edit(AppSettings Function(AppSettings s) change) async {
    final next = change(state);
    state = next;
    final store = ref.read(settingsStoreProvider);
    for (final e in next.toStore().entries) {
      await store.write(e.key, e.value);
    }
  }

  /// After "delete all my data": back to defaults, onboarding shows again.
  void resetInMemory() => state = const AppSettings();
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

final stringsProvider = Provider<Strings>((ref) => Strings(ref.watch(settingsProvider.select((s) => s.language))));

final displayCurrencyProvider = Provider<Currency>((ref) => ref.watch(settingsProvider.select((s) => s.displayCurrency)));

// ---------------------------------------------------------------- rates

final latestOfficialRateProvider = StreamProvider<RateSnapshot?>((ref) => ref.watch(rateRepositoryProvider).watchLatest());

/// The rate used for new records and for converting budgets: the person's own
/// rate when they chose one, otherwise the latest official rate.
final currentRateProvider = Provider<double>((ref) {
  final s = ref.watch(settingsProvider);
  if (s.useManualRate && s.manualRate > 0) return s.manualRate;
  return ref.watch(latestOfficialRateProvider).asData?.value?.zigPerUsd ?? kFallbackZigPerUsd;
});

class RateController {
  RateController(this.ref);
  final Ref ref;

  /// Fetches the official rate. Returns the rate, or null when offline.
  Future<double?> refresh() async {
    final rate = await ref.read(rateFetcherProvider).fetchZigPerUsd();
    if (rate == null) return null;
    final now = DateTime.now();
    await ref.read(rateRepositoryProvider).record(RateSnapshot(zigPerUsd: rate, source: RateSource.official, at: now));
    await ref.read(settingsProvider.notifier).edit((s) => s.copyWith(lastRateFetch: now));
    return rate;
  }

  /// Fetch at most every six hours, so the app costs almost no data.
  Future<void> refreshIfStale() async {
    final last = ref.read(settingsProvider).lastRateFetch;
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 6)) return;
    await refresh();
  }
}

final rateControllerProvider = Provider<RateController>((ref) => RateController(ref));

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

final allEntriesProvider = StreamProvider<List<Entry>>((ref) => ref.watch(entryRepositoryProvider).watchConfirmed());

final pendingEntriesProvider = StreamProvider<List<Entry>>((ref) => ref.watch(entryRepositoryProvider).watchPending());

/// The calendar month "now" belongs to. Re-evaluated whenever the app rebuilds it.
final currentMonthProvider = Provider<MonthRange>((ref) => MonthRange.of(DateTime.now()));

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

// ---------------------------------------------------------------- the month tree

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
    lastDay: lastLeafDay(month, DateTime.now()),
  );
});

/// The Seasons shelf: up to 12 months, newest first, the current month always included.
final seasonsProvider = Provider<List<Season>?>((ref) {
  final all = ref.watch(allEntriesProvider).asData?.value;
  if (all == null) return null;
  return buildSeasons(
    allConfirmed: all,
    cats: ref.watch(categoryMapProvider),
    budgetUsd: ref.watch(budgetTotalUsdProvider),
    now: DateTime.now(),
  );
});
