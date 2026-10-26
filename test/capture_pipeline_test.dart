import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mari/app/providers.dart';
import 'package:mari/capture/capture_service.dart';
import 'package:mari/capture/message_parser.dart';
import 'package:mari/core/util/dates.dart';
import 'package:mari/data/db/database.dart';
import 'package:mari/domain/models.dart';

/// End to end through the real database (in memory): message → pending entry
/// → confirm with fees → counted in the month. Needs the system SQLite library
/// (libsqlite3) on the machine running the tests.
void main() {
  late MariDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = MariDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      messageParserProvider.overrideWithValue(
        MessageParser.fromJsonString(File('assets/parser/templates.json').readAsStringSync()),
      ),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  const transfer = 'Transfer Confirmation. ZiG500.00 sent to RUDO CHIKWANHA 0773987654. '
      'Txn ID: PP241009.1500.C11111. Fee: ZiG5.00 IMTT Tax: ZiG10.00. New wallet balance: ZiG735.40';

  test('default categories are seeded on first open', () async {
    final cats = await container.read(categoryRepositoryProvider).watchAll().first;
    expect(cats.map((c) => c.id), containsAll(['groceries', 'electricity', 'cash_out', 'salary']));
  });

  test('a message becomes one pending entry; the same message again is a duplicate', () async {
    final capture = container.read(captureServiceProvider);
    final at = DateTime(2026, 10, 9, 15);

    final first = await capture.ingest(transfer, source: EntrySource.captured, at: at);
    expect(first.outcome, IngestOutcome.added);

    final again = await capture.ingest(transfer, source: EntrySource.pasted, at: at.add(const Duration(minutes: 1)));
    expect(again.outcome, IngestOutcome.duplicate);

    final pending = await container.read(entryRepositoryProvider).watchPending().first;
    expect(pending, hasLength(1));
    expect(pending.single.amountMinor, 50000);
    expect(pending.single.counterparty, 'RUDO CHIKWANHA');
    expect(pending.single.status, EntryStatus.pendingReview);
  });

  test('confirming moves it into the month and logs fees as their own line', () async {
    final capture = container.read(captureServiceProvider);
    final repo = container.read(entryRepositoryProvider);
    final at = DateTime(2026, 10, 9, 15);

    final r = await capture.ingest(transfer, source: EntrySource.captured, at: at);
    final pending = await repo.byId(r.entryId!);
    await capture.confirm(pending!.copyWith(categoryId: 'family'), feeMinor: 1500);

    final month = await repo.watchMonth(MonthRange.of(at)).first;
    expect(month, hasLength(2));
    expect(month.map((e) => e.categoryId), containsAll(['family', 'fees']));
    expect(await repo.watchPending().first, isEmpty);
  });

  test('promotions are not captured from notifications', () async {
    final r = await container
        .read(captureServiceProvider)
        .ingest('Win USD1000 in the Mega Bonanza! Dial *151# to enter today.', source: EntrySource.captured);
    expect(r.outcome, IngestOutcome.notTransaction);
  });

  test('delete all my data empties everything and restores categories', () async {
    final capture = container.read(captureServiceProvider);
    await capture.ingest(transfer, source: EntrySource.captured);
    await db.wipeEverything();
    expect(await container.read(entryRepositoryProvider).watchPending().first, isEmpty);
    final cats = await container.read(categoryRepositoryProvider).watchAll().first;
    expect(cats, isNotEmpty);
  });
}
