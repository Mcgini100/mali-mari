/// The two currencies Zimbabweans actually live in. Amounts are always stored
/// as integer minor units (cents) — never floating point.
enum Currency {
  usd,
  zig;

  String get symbol => this == Currency.usd ? 'US\$' : 'ZiG';
  String get code => this == Currency.usd ? 'USD' : 'ZWG';
  Currency get other => this == Currency.usd ? Currency.zig : Currency.usd;

  static Currency fromName(String? name) => name == 'zig' ? Currency.zig : Currency.usd;
}

class Money {
  Money._();

  static const String _thin = ' ';

  /// Parses user or message input such as "1,234.5" or "45" into minor units.
  /// Returns null for anything that is not a positive amount with at most two decimals.
  static int? parseToMinor(String input) {
    final clean = input.replaceAll(',', '').replaceAll(' ', '').trim();
    if (clean.isEmpty) return null;
    final match = RegExp(r'^(\d+)(?:\.(\d{0,2}))?$').firstMatch(clean);
    if (match == null) return null;
    final whole = int.parse(match.group(1)!);
    final fracRaw = match.group(2) ?? '';
    final frac = int.parse(fracRaw.padRight(2, '0'));
    return whole * 100 + frac;
  }

  static String _group(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  /// "US$ 1,204.55" / "ZiG 340.00". [signed] prefixes + for positive values.
  static String format(int minor, Currency currency, {bool cents = true, bool signed = false, bool symbol = true}) {
    final negative = minor < 0;
    final abs = minor.abs();
    final String body;
    if (cents) {
      body = '${_group(abs ~/ 100)}.${(abs % 100).toString().padLeft(2, '0')}';
    } else {
      body = _group((abs / 100).round());
    }
    final sign = negative ? '−' : (signed && minor > 0 ? '+' : '');
    return symbol ? '$sign${currency.symbol}$_thin$body' : '$sign$body';
  }

  /// Plain "1234.50" for CSV export and editable fields.
  static String plain(int minor) {
    final abs = minor.abs();
    return '${minor < 0 ? '-' : ''}${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
  }

  /// Converts with [zigPerUsd] (ZiG for 1 US$), rounding half away from zero.
  static int convert(int minor, Currency from, Currency to, double zigPerUsd) {
    if (from == to) return minor;
    if (zigPerUsd <= 0) return 0;
    final value = from == Currency.usd ? minor * zigPerUsd : minor / zigPerUsd;
    return value.round();
  }

  /// Both equivalents for a new record, frozen at [zigPerUsd].
  static ({int usd, int zig}) equivalents(int minor, Currency currency, double zigPerUsd) => (
        usd: convert(minor, currency, Currency.usd, zigPerUsd),
        zig: convert(minor, currency, Currency.zig, zigPerUsd),
      );

  static String formatRate(double zigPerUsd) {
    final s = zigPerUsd.toStringAsFixed(4);
    // Trim to at most 4 decimals but keep at least 2: 26.6600 → 26.66, 26.6640 → 26.664
    var trimmed = s.replaceFirst(RegExp(r'0+$'), '');
    if (trimmed.endsWith('.')) trimmed = trimmed.substring(0, trimmed.length - 1);
    final dot = trimmed.indexOf('.');
    if (dot == -1) return '$trimmed.00';
    if (trimmed.length - dot - 1 < 2) return trimmed.padRight(dot + 3, '0');
    return trimmed;
  }
}
