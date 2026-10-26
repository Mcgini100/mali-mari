import 'package:flutter_test/flutter_test.dart';
import 'package:mari/core/money/money.dart';

void main() {
  group('parseToMinor', () {
    test('accepts whole, decimal and grouped input', () {
      expect(Money.parseToMinor('45'), 4500);
      expect(Money.parseToMinor('45.5'), 4550);
      expect(Money.parseToMinor('45.'), 4500);
      expect(Money.parseToMinor('1,204.55'), 120455);
      expect(Money.parseToMinor(' 0.07 '), 7);
    });

    test('rejects anything that is not an amount', () {
      expect(Money.parseToMinor(''), isNull);
      expect(Money.parseToMinor('abc'), isNull);
      expect(Money.parseToMinor('1.234'), isNull);
      expect(Money.parseToMinor('-5'), isNull);
    });
  });

  group('format', () {
    test('uses the currency symbol, a thin space and grouping', () {
      expect(Money.format(120455, Currency.usd), 'US\$ 1,204.55');
      expect(Money.format(34000, Currency.zig), 'ZiG 340.00');
    });

    test('can drop cents, sign and symbol', () {
      expect(Money.format(120455, Currency.usd, cents: false), 'US\$ 1,205');
      expect(Money.format(1000, Currency.zig, signed: true), '+ZiG 10.00');
      expect(Money.format(-1000, Currency.zig), '−ZiG 10.00');
      expect(Money.format(123456789, Currency.usd, symbol: false), '1,234,567.89');
    });
  });

  group('convert', () {
    test('goes both ways at the given rate and rounds', () {
      expect(Money.convert(4500, Currency.usd, Currency.zig, 26.66), 119970);
      expect(Money.convert(119970, Currency.zig, Currency.usd, 26.66), 4500);
      expect(Money.convert(100, Currency.usd, Currency.usd, 26.66), 100);
    });

    test('a zero rate never divides by zero', () {
      expect(Money.convert(100, Currency.zig, Currency.usd, 0), 0);
    });
  });

  test('formatRate keeps two to four decimals', () {
    expect(Money.formatRate(26.66), '26.66');
    expect(Money.formatRate(26.664), '26.664');
    expect(Money.formatRate(26), '26.00');
    expect(Money.formatRate(26.5), '26.50');
  });
}
