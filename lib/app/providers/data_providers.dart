import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/rates/rate_fetcher.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../data/repositories/entry_repository.dart';

/// Overridden in main() with the opened database.
final databaseProvider = Provider<MariDatabase>((ref) => throw UnimplementedError('databaseProvider must be overridden'));

final entryRepositoryProvider = Provider<EntryRepository>((ref) => DriftEntryRepository(ref.watch(databaseProvider)));
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) => DriftCategoryRepository(ref.watch(databaseProvider)));
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) => DriftBudgetRepository(ref.watch(databaseProvider)));
final rateRepositoryProvider = Provider<RateRepository>((ref) => DriftRateRepository(ref.watch(databaseProvider)));
final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore(ref.watch(databaseProvider)));
final rateFetcherProvider = Provider<RateFetcher>((ref) => OpenExchangeRateFetcher());
