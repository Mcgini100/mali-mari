import 'package:drift/drift.dart';

import '../../core/money/money.dart';
import '../../domain/models.dart';
import '../db/database.dart';

abstract class CategoryRepository {
  Stream<List<Category>> watchAll();
}

class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this._db);
  final MariDatabase _db;

  @override
  Stream<List<Category>> watchAll() {
    final q = _db.select(_db.categories)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    return q.watch().map((rows) => rows
        .map((r) => Category(
              id: r.id,
              nameEn: r.nameEn,
              nameSn: r.nameSn,
              nameNd: r.nameNd,
              icon: r.icon,
              kind: CategoryKind.fromDb(r.kind),
              sortOrder: r.sortOrder,
            ))
        .toList());
  }
}

abstract class BudgetRepository {
  Stream<List<Budget>> watchAll();
  Future<void> upsert(Budget budget);
  Future<void> remove(String categoryId);
}

class DriftBudgetRepository implements BudgetRepository {
  DriftBudgetRepository(this._db);
  final MariDatabase _db;

  @override
  Stream<List<Budget>> watchAll() => _db.select(_db.budgets).watch().map((rows) => rows
      .map((r) => Budget(
            categoryId: r.categoryId,
            amountMinor: r.amountMinor,
            currency: Currency.fromName(r.currency),
            rollover: r.rollover,
          ))
      .toList());

  @override
  Future<void> upsert(Budget budget) => _db.into(_db.budgets).insertOnConflictUpdate(BudgetsCompanion.insert(
        categoryId: budget.categoryId,
        amountMinor: budget.amountMinor,
        currency: budget.currency.name,
        rollover: Value(budget.rollover),
      ));

  @override
  Future<void> remove(String categoryId) =>
      (_db.delete(_db.budgets)..where((t) => t.categoryId.equals(categoryId))).go();
}

abstract class RateRepository {
  Stream<RateSnapshot?> watchLatest();
  Future<RateSnapshot?> latest();
  Future<void> record(RateSnapshot snapshot);
}

class DriftRateRepository implements RateRepository {
  DriftRateRepository(this._db);
  final MariDatabase _db;

  SimpleSelectStatement<$RatesTable, RateRow> _latestQuery() => _db.select(_db.rates)
    ..orderBy([(t) => OrderingTerm.desc(t.at), (t) => OrderingTerm.desc(t.id)])
    ..limit(1);

  static RateSnapshot _map(RateRow r) =>
      RateSnapshot(zigPerUsd: r.zigPerUsd, source: RateSource.fromDb(r.source), at: r.at);

  @override
  Stream<RateSnapshot?> watchLatest() => _latestQuery().watchSingleOrNull().map((r) => r == null ? null : _map(r));

  @override
  Future<RateSnapshot?> latest() async {
    final r = await _latestQuery().getSingleOrNull();
    return r == null ? null : _map(r);
  }

  @override
  Future<void> record(RateSnapshot s) => _db.into(_db.rates).insert(RatesCompanion.insert(
        zigPerUsd: s.zigPerUsd,
        source: s.source.name,
        at: s.at,
      ));
}

/// Small key/value store for preferences, kept in the same SQLite file so
/// "delete all my data" really means all of it.
class SettingsStore {
  SettingsStore(this._db);
  final MariDatabase _db;

  Future<Map<String, String>> readAll() async {
    final rows = await _db.select(_db.settings).get();
    return {for (final r in rows) r.settingKey: r.settingValue};
  }

  Future<void> write(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(settingKey: key, settingValue: value));
}
