import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mari/app/providers.dart';
import 'package:mari/app/settings.dart';
import 'package:mari/capture/capture_service.dart';
import 'package:mari/capture/message_parser.dart';
import 'package:mari/core/money/money.dart';
import 'package:mari/data/db/database.dart';
import 'package:mari/data/rates/rate_fetcher.dart';
import 'package:mari/data/repositories/catalog_repository.dart';
import 'package:mari/data/repositories/entry_repository.dart';
import 'package:mari/domain/models.dart';

/// The month the design prototype shows: October 2026 as seen at 18:40 on
/// the 27th, with a salary, a remittance, EcoCash and cash spending in both
/// currencies, and nine limits. Screens rendered from it can be compared
/// with design/prototype.html side by side.
const double sampleRate = 26.66;
final DateTime sampleNow = DateTime(2026, 10, 27, 18, 40);

class OfflineRates implements RateFetcher {
  @override
  Future<double?> fetchZigPerUsd() async => null;

  @override
  String get label => 'offline';
}

var _n = 0;

Entry _tx(int day, int h, int m, Direction dir, Currency cur, double amount, String cat, String who, {int month = 10}) {
  final minor = (amount * 100).round();
  final eq = Money.equivalents(minor, cur, sampleRate);
  final at = DateTime(2026, month, day, h, m);
  return Entry(
    id: 's${_n++}',
    amountMinor: minor,
    currency: cur,
    usdMinor: eq.usd,
    zigMinor: eq.zig,
    rateUsed: sampleRate,
    direction: dir,
    categoryId: cat,
    note: '',
    counterparty: who,
    occurredAt: at,
    source: cur == Currency.zig ? EntrySource.captured : EntrySource.manual,
    rawSourceText: null,
    status: EntryStatus.confirmed,
    sourceRef: null,
    createdAt: at,
  );
}

const _out = Direction.moneyOut;
const _in = Direction.moneyIn;
const _usd = Currency.usd;
const _zig = Currency.zig;

List<Entry> sampleEntries() => [
      _tx(1, 9, 0, _in, _usd, 850, 'salary', 'Salary, October'),
      _tx(1, 17, 20, _out, _usd, 38, 'groceries', 'OK Mart Avondale'),
      _tx(2, 16, 0, _out, _usd, 22, 'transport', 'Fuel, Zuva Chisipite'),
      _tx(2, 19, 5, _out, _zig, 30, 'airtime', 'Econet bundle'),
      _tx(3, 8, 0, _out, _usd, 120, 'school', 'Term 3 fees, Tafara'),
      _tx(4, 12, 10, _out, _zig, 260, 'groceries', 'Spar Kensington'),
      _tx(4, 12, 10, _out, _zig, 6, 'fees', 'EcoCash fee + IMTT'),
      _tx(5, 10, 0, _out, _usd, 40, 'church', 'ZAOGA tithe'),
      _tx(6, 13, 30, _out, _usd, 9, 'eating_out', 'Chicken Inn Sam Levy'),
      _tx(8, 7, 15, _out, _usd, 2, 'transport', 'Kombi to town'),
      _tx(8, 18, 0, _out, _usd, 12, 'groceries', 'TM Pick n Pay'),
      _tx(9, 9, 0, _in, _usd, 100, 'remittance', 'Mukuru, from Chipo'),
      _tx(9, 17, 0, _out, _zig, 500, 'family', 'Rudo Chikwanha'),
      _tx(9, 17, 0, _out, _zig, 15, 'fees', 'EcoCash fee + IMTT'),
      _tx(10, 18, 30, _out, _zig, 200, 'electricity', 'ZESA Prepaid'),
      _tx(11, 9, 40, _out, _usd, 6, 'groceries', 'Mbare market veg'),
      _tx(12, 19, 10, _out, _usd, 14, 'eating_out', 'Pizza Inn'),
      _tx(13, 7, 15, _out, _usd, 2, 'transport', 'Kombi to town'),
      _tx(13, 20, 0, _out, _zig, 30, 'airtime', 'Econet bundle'),
      _tx(14, 11, 0, _out, _usd, 41, 'groceries', 'OK Zimbabwe Samora'),
      _tx(16, 15, 0, _out, _usd, 20, 'family', 'Mum, Gweru'),
      _tx(17, 7, 20, _out, _usd, 3, 'transport', 'Kombi'),
      _tx(18, 12, 0, _out, _zig, 180, 'groceries', 'Bon Marché Borrowdale'),
      _tx(19, 13, 0, _out, _usd, 7, 'eating_out', 'Chicken Slice'),
      _tx(20, 16, 0, _in, _zig, 900, 'side_hustle', 'Braiding, Nyasha'),
      _tx(21, 10, 0, _out, _usd, 18, 'groceries', 'Spar Avondale'),
      _tx(23, 18, 0, _out, _zig, 120, 'electricity', 'ZESA Prepaid'),
      _tx(24, 9, 30, _out, _usd, 10, 'church', 'Offering'),
      _tx(24, 7, 15, _out, _usd, 2, 'transport', 'Kombi'),
      _tx(25, 10, 0, _out, _usd, 9, 'groceries', 'Vegetables, Avondale'),
      _tx(26, 19, 0, _out, _zig, 30, 'airtime', 'Econet bundle'),
      _tx(26, 13, 0, _out, _usd, 6, 'eating_out', 'Mambos Chicken'),
      _tx(27, 8, 42, _out, _zig, 340, 'groceries', 'OK Zimbabwe Samora'),
      _tx(27, 7, 15, _out, _usd, 1, 'transport', 'Kombi to town'),
      // September, so the Seasons shelf and "compared with last month" have something to show.
      _tx(1, 9, 0, _in, _usd, 850, 'salary', 'Salary, September', month: 9),
      _tx(3, 10, 0, _out, _usd, 150, 'groceries', 'OK Mart Avondale', month: 9),
      _tx(8, 10, 0, _out, _usd, 60, 'transport', 'Fuel', month: 9),
      _tx(14, 10, 0, _out, _usd, 95, 'groceries', 'Spar Kensington', month: 9),
      _tx(19, 10, 0, _out, _usd, 48, 'family', 'Mum, Gweru', month: 9),
      _tx(22, 10, 0, _out, _usd, 30, 'electricity', 'ZESA Prepaid', month: 9),
      _tx(26, 10, 0, _out, _usd, 120, 'school', 'Uniforms', month: 9),
    ];

const Map<String, int> sampleBudgetsUsd = {
  'groceries': 18000,
  'transport': 6000,
  'airtime': 2500,
  'electricity': 3000,
  'eating_out': 4000,
  'church': 5000,
  'family': 8000,
  'school': 12000,
  'fees': 1000,
};

/// An in-memory database holding the sample month.
Future<MariDatabase> openSampleDatabase({bool withData = true}) async {
  final db = MariDatabase(NativeDatabase.memory());
  if (withData) {
    final entries = DriftEntryRepository(db);
    for (final e in sampleEntries()) {
      await entries.save(e);
    }
    final budgets = DriftBudgetRepository(db);
    for (final b in sampleBudgetsUsd.entries) {
      await budgets.upsert(Budget(categoryId: b.key, amountMinor: b.value, currency: Currency.usd));
    }
  }
  return db;
}

/// Overrides that run the whole app offline, at a pinned moment, on [db].
List<Override> sampleOverrides(MariDatabase db, {AppSettings settings = const AppSettings(onboarded: true), DateTime? now}) => [
      databaseProvider.overrideWithValue(db),
      initialSettingsProvider.overrideWithValue(settings),
      clockProvider.overrideWithValue(() => now ?? sampleNow),
      messageParserProvider.overrideWithValue(
        MessageParser.fromJsonString(File('assets/parser/templates.json').readAsStringSync()),
      ),
      rateFetcherProvider.overrideWithValue(OfflineRates()),
    ];
