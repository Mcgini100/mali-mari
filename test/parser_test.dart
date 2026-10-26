import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mari/capture/message_parser.dart';
import 'package:mari/core/money/money.dart';
import 'package:mari/domain/models.dart';

/// Runs every case in test/fixtures/messages.json — the same fixtures
/// tool/test_parser.js runs against the JavaScript reference parser.
void main() {
  final parser = MessageParser.fromJsonString(File('assets/parser/templates.json').readAsStringSync());
  final fixtures = jsonDecode(File('test/fixtures/messages.json').readAsStringSync()) as Map<String, dynamic>;

  String fmt(int minor) => Money.plain(minor);
  String? dir(Direction? d) => d == null ? null : (d == Direction.moneyIn ? 'in' : 'out');

  for (final raw in fixtures['cases'] as List<dynamic>) {
    final kase = raw as Map<String, dynamic>;
    test(kase['name'] as String, () {
      final r = parser.parse(kase['text'] as String);
      final expect_ = kase['expect'] as Map<String, dynamic>?;
      if (expect_ == null) {
        expect(r, isNull);
        return;
      }
      expect(r, isNotNull);
      if (expect_.containsKey('amount')) expect(fmt(r!.amountMinor), expect_['amount']);
      if (expect_.containsKey('currency')) expect(r!.currency.name, expect_['currency']);
      if (expect_.containsKey('direction')) expect(dir(r!.direction), expect_['direction']);
      if (expect_.containsKey('counterparty')) expect(r!.counterparty, expect_['counterparty']);
      if (expect_.containsKey('category')) expect(r!.categoryId, expect_['category']);
      if (expect_.containsKey('reference')) expect(r!.reference, expect_['reference']);
      if (expect_.containsKey('confidence')) expect(r!.confidence.name, expect_['confidence']);
      if (expect_.containsKey('fee')) expect(fmt(r!.feeMinor), expect_['fee']);
    });
  }

  test('empty and whitespace input is not a transaction', () {
    expect(parser.parse(''), isNull);
    expect(parser.parse('   \n '), isNull);
    expect(parser.parse(null), isNull);
  });

  test('toMinor handles grouping and short decimals', () {
    expect(MessageParser.toMinor('1,250.40'), 125040);
    expect(MessageParser.toMinor('45'), 4500);
    expect(MessageParser.toMinor('7.5'), 750);
  });
}
