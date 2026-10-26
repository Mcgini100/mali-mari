import 'dart:convert';

import '../core/money/money.dart';
import '../domain/models.dart';

/// How sure the parser is.
/// high: a known template matched. medium: amount, currency and direction
/// found by the generic reading. low: an amount was found but not whether
/// money came in or went out.
enum ParseConfidence { high, medium, low }

class ParsedMessage {
  const ParsedMessage({
    required this.amountMinor,
    required this.currency,
    required this.direction,
    required this.counterparty,
    required this.categoryId,
    required this.feeMinor,
    required this.reference,
    required this.confidence,
    required this.templateId,
  });

  final int amountMinor;
  final Currency currency;
  final Direction? direction;
  final String? counterparty;
  final String? categoryId;
  final int feeMinor;
  final String? reference;
  final ParseConfidence confidence;
  final String? templateId;
}

class _Template {
  _Template(this.id, this.direction, this.category, this.re);
  final String id;
  final Direction direction;
  final String? category;
  final RegExp re;
}

/// Turns a wallet or bank alert into a [ParsedMessage]. One engine for every
/// capture path (typed paste, share sheet, Shortcut deep link, Android
/// notification). The templates are data (assets/parser/templates.json).
///
/// This is a line-for-line port of tool/parser_reference.js, which runs the
/// same fixtures in Node; keep the two in step.
class MessageParser {
  MessageParser._({
    required List<_Template> templates,
    required List<RegExp> balance,
    required List<RegExp> fee,
    required RegExp reference,
    required RegExp prefixAmount,
    required RegExp suffixAmount,
    required RegExp heuristicCounterparty,
    required Map<String, List<String>> directionKeywords,
    required List<MapEntry<String, List<String>>> categoryKeywords,
  })  : _templates = templates,
        _balance = balance,
        _fee = fee,
        _reference = reference,
        _prefixAmount = prefixAmount,
        _suffixAmount = suffixAmount,
        _heuristicCp = heuristicCounterparty,
        _directionKeywords = directionKeywords,
        _categoryKeywords = categoryKeywords;

  static const String _cur = r'(?<cur>ZiG|ZWG|USD|US\$|\$)';
  static const String _amt = r'(?<amt>\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)';

  final List<_Template> _templates;
  final List<RegExp> _balance;
  final List<RegExp> _fee;
  final RegExp _reference;
  final RegExp _prefixAmount;
  final RegExp _suffixAmount;
  final RegExp _heuristicCp;
  final Map<String, List<String>> _directionKeywords;
  final List<MapEntry<String, List<String>>> _categoryKeywords;

  static String _expand(String p) => p.replaceAll('{CUR}', _cur).replaceAll('{AMT}', _amt);

  static RegExp _ci(String p) => RegExp(_expand(p), caseSensitive: false);

  factory MessageParser.fromJsonString(String json) =>
      MessageParser.fromConfig(jsonDecode(json) as Map<String, dynamic>);

  factory MessageParser.fromConfig(Map<String, dynamic> cfg) {
    List<String> strings(Object? v) => (v as List<dynamic>).map((e) => e as String).toList();

    final templates = <_Template>[
      for (final raw in cfg['templates'] as List<dynamic>)
        () {
          final t = raw as Map<String, dynamic>;
          return _Template(
            t['id'] as String,
            Direction.fromDb(t['direction'] as String),
            t['category'] as String?,
            _ci(t['pattern'] as String),
          );
        }(),
    ];

    final dirKw = cfg['directionKeywords'] as Map<String, dynamic>;
    final catKw = cfg['categoryKeywords'] as Map<String, dynamic>;

    return MessageParser._(
      templates: templates,
      balance: strings(cfg['balancePatterns']).map(_ci).toList(),
      fee: strings(cfg['feePatterns']).map(_ci).toList(),
      reference: RegExp(cfg['referencePattern'] as String, caseSensitive: false),
      prefixAmount: RegExp('$_cur\\s?$_amt', caseSensitive: false),
      suffixAmount: _ci(cfg['suffixAmountPattern'] as String),
      heuristicCounterparty: RegExp(cfg['heuristicCounterpartyPattern'] as String), // case-sensitive on purpose
      directionKeywords: {for (final e in dirKw.entries) e.key: strings(e.value)},
      categoryKeywords: [for (final e in catKw.entries) MapEntry(e.key, strings(e.value))],
    );
  }

  static Currency _currencyOf(String token) {
    final t = token.toUpperCase();
    return (t == 'ZIG' || t == 'ZWG') ? Currency.zig : Currency.usd;
  }

  static int toMinor(String amount) {
    final clean = amount.replaceAll(',', '');
    final parts = clean.split('.');
    final whole = int.parse(parts[0]);
    final frac = parts.length > 1 ? '${parts[1]}00'.substring(0, 2) : '00';
    return whole * 100 + int.parse(frac);
  }

  static String? _cleanCounterparty(String? cp) {
    if (cp == null) return null;
    final c = cp
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s,.:;-]+|[\s,.:;-]+$'), '');
    return c.isEmpty ? null : c;
  }

  static int _keywordIndex(String text, String keyword) {
    final re = RegExp('(?:^|[^A-Za-z])${RegExp.escape(keyword)}(?![A-Za-z])', caseSensitive: false);
    final m = re.firstMatch(text);
    if (m == null) return -1;
    return m.start + (m.group(0)!.length - keyword.length);
  }

  Direction? _detectDirection(String text) {
    String? best;
    var bestAt = 1 << 30;
    for (final dir in const ['in', 'out']) {
      for (final k in _directionKeywords[dir] ?? const <String>[]) {
        final at = _keywordIndex(text, k);
        if (at >= 0 && at < bestAt) {
          bestAt = at;
          best = dir;
        }
      }
    }
    return best == null ? null : Direction.fromDb(best);
  }

  String? _categorize(String? counterparty) {
    if (counterparty == null) return null;
    final hay = ' ${counterparty.toLowerCase()} ';
    for (final e in _categoryKeywords) {
      for (final w in e.value) {
        if (hay.contains(w.toLowerCase())) return e.key;
      }
    }
    return null;
  }

  int _extractFee(String text) {
    var total = 0;
    for (final re in _fee) {
      for (final m in re.allMatches(text)) {
        total += toMinor(m.namedGroup('amt')!);
      }
    }
    return total;
  }

  String? _extractReference(String text) {
    final m = _reference.firstMatch(text);
    if (m == null) return null;
    return m.namedGroup('ref')!.replaceAll(RegExp(r'[.\-/]+$'), '');
  }

  static String? _group(RegExpMatch m, String name) {
    try {
      return m.namedGroup(name);
    } on ArgumentError {
      return null; // the template has no such group
    }
  }

  /// Returns null when [text] is not a transaction (OTPs, balance enquiries, chat).
  ParsedMessage? parse(String? text) {
    if (text == null) return null;
    final norm = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (norm.isEmpty) return null;

    final feeMinor = _extractFee(norm);
    final reference = _extractReference(norm);

    for (final t in _templates) {
      final m = t.re.firstMatch(norm);
      if (m != null) {
        final cp = _cleanCounterparty(_group(m, 'cp'));
        return ParsedMessage(
          amountMinor: toMinor(m.namedGroup('amt')!),
          currency: _currencyOf(m.namedGroup('cur')!),
          direction: t.direction,
          counterparty: cp,
          categoryId: t.category ?? _categorize(cp),
          feeMinor: feeMinor,
          reference: reference,
          confidence: ParseConfidence.high,
          templateId: t.id,
        );
      }
    }

    // Generic reading: drop balance and fee phrases first so their amounts
    // are never mistaken for the transaction amount.
    var stripped = norm;
    for (final re in [..._balance, ..._fee]) {
      stripped = stripped.replaceAll(re, ' ');
    }

    final a = _prefixAmount.firstMatch(stripped) ?? _suffixAmount.firstMatch(stripped);
    if (a == null) return null;

    final direction = _detectDirection(stripped);
    final cpMatch = _heuristicCp.firstMatch(stripped);
    final counterparty = cpMatch == null ? null : _cleanCounterparty(_group(cpMatch, 'cp'));

    return ParsedMessage(
      amountMinor: toMinor(a.namedGroup('amt')!),
      currency: _currencyOf(a.namedGroup('cur')!),
      direction: direction,
      counterparty: counterparty,
      categoryId: _categorize(counterparty),
      feeMinor: feeMinor,
      reference: reference,
      confidence: direction == null ? ParseConfidence.low : ParseConfidence.medium,
      templateId: null,
    );
  }
}
