import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mari/app/app.dart';
import 'package:mari/app/providers.dart';
import 'package:mari/app/settings.dart';
import 'package:mari/capture/capture_service.dart';
import 'package:mari/capture/message_parser.dart';
import 'package:mari/data/db/database.dart';
import 'package:mari/data/rates/rate_fetcher.dart';
import 'package:mari/features/tree/month_tree_view.dart';

class _OfflineRates implements RateFetcher {
  @override
  Future<double?> fetchZigPerUsd() async => null;

  @override
  String get label => 'offline';
}

/// The whole app on a phone-sized screen: the tab bar must sit at the bottom
/// and Home must show its tree. (A tab bar that grew to full height once hid
/// every screen on a real phone while every unit test still passed.)
void main() {
  testWidgets('home shows the tree and the tab bar sits at the bottom', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    final db = MariDatabase(NativeDatabase.memory());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialSettingsProvider.overrideWithValue(const AppSettings(onboarded: true)),
        messageParserProvider.overrideWithValue(
          MessageParser.fromJsonString(File('assets/parser/templates.json').readAsStringSync()),
        ),
        rateFetcherProvider.overrideWithValue(_OfflineRates()),
      ],
      child: const MariApp(),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final historyLabel = tester.getRect(find.text('History').last);
    expect(historyLabel.top, greaterThan(screen.height - 120), reason: 'tab bar must sit at the bottom of the screen');

    expect(find.byType(MonthTreeView), findsOneWidget);
    expect(find.textContaining('LEFT TO SPEND').evaluate().isNotEmpty || find.textContaining('SPENT').evaluate().isNotEmpty, isTrue);

    // Switching tabs keeps the bar in place and shows the screen.
    await tester.tap(find.text('Budgets').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getRect(find.text('Budgets').last).top, greaterThan(screen.height - 120));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
    await db.close();
  });
}
