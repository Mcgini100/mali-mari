import '../core/l10n/language.dart';
import '../core/money/money.dart';

enum Direction {
  moneyIn('in'),
  moneyOut('out');

  const Direction(this.dbName);
  final String dbName;

  static Direction fromDb(String v) => v == 'in' ? Direction.moneyIn : Direction.moneyOut;
}

/// Where a record came from. Shared texts and Shortcut deep links count as
/// [pasted]: the person chose to hand the message to Mari.
enum EntrySource {
  manual,
  pasted,
  captured;

  static EntrySource fromDb(String v) =>
      EntrySource.values.firstWhere((s) => s.name == v, orElse: () => EntrySource.manual);
}

enum EntryStatus {
  confirmed,
  pendingReview;

  static EntryStatus fromDb(String v) => v == 'pendingReview' ? EntryStatus.pendingReview : EntryStatus.confirmed;
}

/// [transfer] covers moves between your own money (EcoCash cash-out): never
/// counted as spending or income.
enum CategoryKind {
  income,
  expense,
  transfer;

  static CategoryKind fromDb(String v) =>
      CategoryKind.values.firstWhere((k) => k.name == v, orElse: () => CategoryKind.expense);
}

enum RateSource {
  official,
  manual;

  static RateSource fromDb(String v) => v == 'manual' ? RateSource.manual : RateSource.official;
}

class Category {
  const Category({
    required this.id,
    required this.nameEn,
    required this.nameSn,
    required this.nameNd,
    required this.icon,
    required this.kind,
    this.sortOrder = 0,
  });

  final String id;
  final String nameEn;
  final String nameSn;
  final String nameNd;
  final String icon;
  final CategoryKind kind;
  final int sortOrder;

  String name(AppLanguage lang) => switch (lang) {
        AppLanguage.en => nameEn,
        AppLanguage.sn => nameSn,
        AppLanguage.nd => nameNd,
      };
}

class Entry {
  const Entry({
    required this.id,
    required this.amountMinor,
    required this.currency,
    required this.usdMinor,
    required this.zigMinor,
    required this.rateUsed,
    required this.direction,
    required this.categoryId,
    required this.note,
    required this.counterparty,
    required this.occurredAt,
    required this.source,
    required this.rawSourceText,
    required this.status,
    required this.sourceRef,
    required this.createdAt,
  });

  final String id;

  /// The amount exactly as it happened, in [currency].
  final int amountMinor;
  final Currency currency;

  /// Equivalents frozen at [rateUsed] when the record was made. Never recalculated.
  final int usdMinor;
  final int zigMinor;
  final double rateUsed;

  final Direction direction;
  final String? categoryId;
  final String note;
  final String counterparty;
  final DateTime occurredAt;
  final EntrySource source;

  /// The message text a pasted or captured record was read from, so it can always be checked.
  final String? rawSourceText;
  final EntryStatus status;

  /// Transaction reference or message fingerprint, used to avoid duplicates.
  final String? sourceRef;
  final DateTime createdAt;

  int amountIn(Currency c) => c == Currency.usd ? usdMinor : zigMinor;

  bool get isPending => status == EntryStatus.pendingReview;

  Entry copyWith({
    int? amountMinor,
    Currency? currency,
    int? usdMinor,
    int? zigMinor,
    double? rateUsed,
    Direction? direction,
    String? categoryId,
    bool clearCategory = false,
    String? note,
    String? counterparty,
    DateTime? occurredAt,
    EntryStatus? status,
  }) {
    return Entry(
      id: id,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      usdMinor: usdMinor ?? this.usdMinor,
      zigMinor: zigMinor ?? this.zigMinor,
      rateUsed: rateUsed ?? this.rateUsed,
      direction: direction ?? this.direction,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      note: note ?? this.note,
      counterparty: counterparty ?? this.counterparty,
      occurredAt: occurredAt ?? this.occurredAt,
      source: source,
      rawSourceText: rawSourceText,
      status: status ?? this.status,
      sourceRef: sourceRef,
      createdAt: createdAt,
    );
  }
}

class Budget {
  const Budget({required this.categoryId, required this.amountMinor, required this.currency, this.rollover = false});

  final String categoryId;
  final int amountMinor;
  final Currency currency;
  final bool rollover;
}

class RateSnapshot {
  const RateSnapshot({required this.zigPerUsd, required this.source, required this.at});

  final double zigPerUsd;
  final RateSource source;
  final DateTime at;
}
