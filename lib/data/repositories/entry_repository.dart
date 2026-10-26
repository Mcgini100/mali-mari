import 'package:drift/drift.dart';

import '../../core/money/money.dart';
import '../../core/util/dates.dart';
import '../../domain/models.dart';
import '../db/database.dart';

/// Read/write access to transactions. The UI only ever sees [Entry]; the
/// Drift row type stays inside the data layer so a sync backend can be added
/// behind this interface later without touching screens.
abstract class EntryRepository {
  Stream<List<Entry>> watchMonth(MonthRange month);
  Stream<List<Entry>> watchConfirmed({DateTime? from, DateTime? to});
  Stream<List<Entry>> watchPending();
  Future<List<Entry>> allConfirmed();
  Future<Entry?> byId(String id);
  Future<void> save(Entry entry);
  Future<void> delete(String id);
  Future<void> confirm(Entry entry);

  /// True when a record with the same reference or message fingerprint was
  /// made within [window] of [around].
  Future<bool> hasRecentRef(String ref, DateTime around, {Duration window = const Duration(days: 3)});
}

class DriftEntryRepository implements EntryRepository {
  DriftEntryRepository(this._db);

  final MariDatabase _db;

  static Entry toDomain(EntryRow r) => Entry(
        id: r.id,
        amountMinor: r.amountMinor,
        currency: Currency.fromName(r.currency),
        usdMinor: r.usdMinor,
        zigMinor: r.zigMinor,
        rateUsed: r.rateUsed,
        direction: Direction.fromDb(r.direction),
        categoryId: r.categoryId,
        note: r.note,
        counterparty: r.counterparty,
        occurredAt: r.occurredAt,
        source: EntrySource.fromDb(r.source),
        rawSourceText: r.rawSourceText,
        status: EntryStatus.fromDb(r.status),
        sourceRef: r.sourceRef,
        createdAt: r.createdAt,
      );

  static EntriesCompanion toCompanion(Entry e) => EntriesCompanion.insert(
        id: e.id,
        amountMinor: e.amountMinor,
        currency: e.currency.name,
        usdMinor: e.usdMinor,
        zigMinor: e.zigMinor,
        rateUsed: e.rateUsed,
        direction: e.direction.dbName,
        categoryId: Value(e.categoryId),
        note: Value(e.note),
        counterparty: Value(e.counterparty),
        occurredAt: e.occurredAt,
        source: e.source.name,
        rawSourceText: Value(e.rawSourceText),
        status: e.status.name,
        sourceRef: Value(e.sourceRef),
        createdAt: e.createdAt,
      );

  @override
  Stream<List<Entry>> watchMonth(MonthRange month) => watchConfirmed(from: month.start, to: month.end);

  @override
  Stream<List<Entry>> watchConfirmed({DateTime? from, DateTime? to}) {
    final q = _db.select(_db.entries)
      ..where((t) {
        Expression<bool> cond = t.status.equals(EntryStatus.confirmed.name);
        if (from != null) cond = cond & t.occurredAt.isBiggerOrEqualValue(from);
        if (to != null) cond = cond & t.occurredAt.isSmallerThanValue(to);
        return cond;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt), (t) => OrderingTerm.desc(t.createdAt)]);
    return q.watch().map((rows) => rows.map(toDomain).toList());
  }

  @override
  Stream<List<Entry>> watchPending() {
    final q = _db.select(_db.entries)
      ..where((t) => t.status.equals(EntryStatus.pendingReview.name))
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
    return q.watch().map((rows) => rows.map(toDomain).toList());
  }

  @override
  Future<List<Entry>> allConfirmed() async {
    final q = _db.select(_db.entries)
      ..where((t) => t.status.equals(EntryStatus.confirmed.name))
      ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]);
    final rows = await q.get();
    return rows.map(toDomain).toList();
  }

  @override
  Future<Entry?> byId(String id) async {
    final row = await (_db.select(_db.entries)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : toDomain(row);
  }

  @override
  Future<void> save(Entry entry) => _db.into(_db.entries).insertOnConflictUpdate(toCompanion(entry));

  @override
  Future<void> delete(String id) => (_db.delete(_db.entries)..where((t) => t.id.equals(id))).go();

  @override
  Future<void> confirm(Entry entry) => save(entry.copyWith(status: EntryStatus.confirmed));

  @override
  Future<bool> hasRecentRef(String ref, DateTime around, {Duration window = const Duration(days: 3)}) async {
    final q = _db.select(_db.entries)
      ..where((t) =>
          t.sourceRef.equals(ref) &
          t.occurredAt.isBiggerOrEqualValue(around.subtract(window)) &
          t.occurredAt.isSmallerOrEqualValue(around.add(window)))
      ..limit(1);
    return (await q.get()).isNotEmpty;
  }
}
