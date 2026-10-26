import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../seed/default_categories.dart';

part 'database.g.dart';

// Run `dart run build_runner build --delete-conflicting-outputs` to generate
// database.g.dart after changing anything in this file.

@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get nameEn => text()();
  TextColumn get nameSn => text()();
  TextColumn get nameNd => text()();
  TextColumn get icon => text()();
  TextColumn get kind => text()(); // income | expense | transfer
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('EntryRow')
class Entries extends Table {
  TextColumn get id => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text()(); // usd | zig
  IntColumn get usdMinor => integer()();
  IntColumn get zigMinor => integer()();
  RealColumn get rateUsed => real()();
  TextColumn get direction => text()(); // in | out
  TextColumn get categoryId => text().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get counterparty => text().withDefault(const Constant(''))();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get source => text()(); // manual | pasted | captured
  TextColumn get rawSourceText => text().nullable()();
  TextColumn get status => text()(); // confirmed | pendingReview
  TextColumn get sourceRef => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('BudgetRow')
class Budgets extends Table {
  TextColumn get categoryId => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text()();
  BoolColumn get rollover => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {categoryId};
}

@DataClassName('RateRow')
class Rates extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get zigPerUsd => real()();
  TextColumn get source => text()(); // official | manual
  DateTimeColumn get at => dateTime()();
}

@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get settingKey => text()();
  TextColumn get settingValue => text()();

  @override
  Set<Column> get primaryKey => {settingKey};
}

@DriftDatabase(tables: [Categories, Entries, Budgets, Rates, Settings])
class MariDatabase extends _$MariDatabase {
  /// Pass an executor in tests (e.g. `NativeDatabase.memory()`); the app uses
  /// an on-device SQLite file named mari.sqlite.
  MariDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'mari'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        beforeOpen: (details) async {
          if (details.wasCreated) {
            await seedCategories();
          }
        },
      );

  Future<void> seedCategories() async {
    await batch((b) {
      b.insertAll(
        categories,
        [
          for (final c in defaultCategories)
            CategoriesCompanion.insert(
              id: c.id,
              nameEn: c.nameEn,
              nameSn: c.nameSn,
              nameNd: c.nameNd,
              icon: c.icon,
              kind: c.kind.name,
              sortOrder: Value(c.sortOrder),
            ),
        ],
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  /// "Delete all my data": everything goes, then the default categories return.
  Future<void> wipeEverything() async {
    await transaction(() async {
      await delete(entries).go();
      await delete(budgets).go();
      await delete(rates).go();
      await delete(settings).go();
      await delete(categories).go();
    });
    await seedCategories();
  }
}
