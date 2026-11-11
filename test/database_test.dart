import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mari/app/providers.dart';
import 'package:mari/app/settings.dart';
import 'package:mari/core/money/money.dart';
import 'package:mari/data/db/database.dart';
import 'package:mari/data/repositories/catalog_repository.dart';

Future<Set<String>> _indexNames(MariDatabase db) async {
  final rows = await db.customSelect("SELECT name FROM sqlite_master WHERE type = 'index'").get();
  return {for (final r in rows) r.read<String>('name')};
}

/// The entries table exactly as schema v1 created it.
const _v1Entries = '''
CREATE TABLE entries (
  id TEXT NOT NULL PRIMARY KEY,
  amount_minor INTEGER NOT NULL,
  currency TEXT NOT NULL,
  usd_minor INTEGER NOT NULL,
  zig_minor INTEGER NOT NULL,
  rate_used REAL NOT NULL,
  direction TEXT NOT NULL,
  category_id TEXT NULL,
  note TEXT NOT NULL DEFAULT '',
  counterparty TEXT NOT NULL DEFAULT '',
  occurred_at INTEGER NOT NULL,
  source TEXT NOT NULL,
  raw_source_text TEXT NULL,
  status TEXT NOT NULL,
  source_ref TEXT NULL,
  created_at INTEGER NOT NULL
)''';

void main() {
  test('a new database has the indexes month screens and de-duplication rely on', () async {
    final db = MariDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await _indexNames(db), containsAll(['entries_status_occurred', 'entries_source_ref']));
  });

  test('a v1 database is upgraded in place: indexes added, records kept', () async {
    final db = MariDatabase(NativeDatabase.memory(setup: (raw) {
      raw.execute(_v1Entries);
      raw.execute('CREATE TABLE settings (setting_key TEXT NOT NULL PRIMARY KEY, setting_value TEXT NOT NULL)');
      raw.execute('INSERT INTO entries (id, amount_minor, currency, usd_minor, zig_minor, rate_used, direction, occurred_at, source, status, created_at) '
          "VALUES ('old1', 500, 'usd', 500, 13330, 26.66, 'out', 1791000000, 'manual', 'confirmed', 1791000000)");
      raw.execute("INSERT INTO settings VALUES ('onboarded', 'true')");
      raw.execute('PRAGMA user_version = 1');
    }));
    addTearDown(db.close);

    expect(await _indexNames(db), containsAll(['entries_status_occurred', 'entries_source_ref']));
    final kept = await db.customSelect('SELECT amount_minor FROM entries WHERE id = ?', variables: [Variable.withString('old1')]).getSingle();
    expect(kept.read<int>('amount_minor'), 500);
    expect((await SettingsStore(db).readAll())['onboarded'], 'true');
  });

  test('the month query uses the status and date index', () async {
    final db = MariDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final plan = await db
        .customSelect("EXPLAIN QUERY PLAN SELECT * FROM entries WHERE status = 'confirmed' AND occurred_at >= 0 AND occurred_at < 10")
        .get();
    expect(plan.map((r) => r.read<String>('detail')).join(' '), contains('entries_status_occurred'));
  });

  test('editing a setting saves only what changed and survives a restart', () async {
    final db = MariDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await container.read(settingsProvider.notifier).edit((s) => s.copyWith(displayCurrency: Currency.zig));
    final stored = await SettingsStore(db).readAll();
    expect(stored, {'displayCurrency': 'zig'});

    await container.read(settingsProvider.notifier).edit((s) => s.copyWith(onboarded: true, manualRate: 31.5));
    final reread = AppSettings.fromStore(await SettingsStore(db).readAll());
    expect(reread.displayCurrency, Currency.zig);
    expect(reread.onboarded, isTrue);
    expect(reread.manualRate, 31.5);
  });
}
