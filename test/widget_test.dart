import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mari/core/money/money.dart';
import 'package:mari/core/theme/app_theme.dart';
import 'package:mari/domain/month_tree.dart';
import 'package:mari/features/tree/month_tree_view.dart';
import 'package:mari/widgets/budget_widgets.dart';
import 'package:mari/widgets/money.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) => MaterialApp(
      theme: buildMariTheme(brightness),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('AnimatedMoney rolls to the new value with tabular figures', (tester) async {
    await tester.pumpWidget(_host(const AnimatedMoney(minor: 10000, currency: Currency.usd, style: MariType.display)));
    expect(find.text(Money.format(10000, Currency.usd)), findsOneWidget);

    await tester.pumpWidget(_host(const AnimatedMoney(minor: 25430, currency: Currency.usd, style: MariType.display)));
    await tester.pumpAndSettle();
    expect(find.text(Money.format(25430, Currency.usd)), findsOneWidget);
  });

  testWidgets('switching currency swaps the figure', (tester) async {
    await tester.pumpWidget(_host(const AnimatedMoney(minor: 4500, currency: Currency.usd, style: MariType.display)));
    await tester.pumpWidget(_host(const AnimatedMoney(minor: 119970, currency: Currency.zig, style: MariType.display)));
    await tester.pumpAndSettle();
    expect(find.text(Money.format(119970, Currency.zig)), findsOneWidget);
    expect(find.text(Money.format(4500, Currency.usd)), findsNothing);
  });

  testWidgets('budget bar renders at 0%, in range and over 100% in both themes', (tester) async {
    for (final b in Brightness.values) {
      for (final p in [0.0, 0.5, 1.4]) {
        await tester.pumpWidget(_host(SizedBox(width: 200, child: BudgetBar(progress: p)), brightness: b));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('the month tree draws, sways, and a tap on a leaf opens its day', (tester) async {
    int? tapped;
    final tones = {for (var d = 1; d <= 27; d++) d: d % 7 == 0 ? DayTone.bud : DayTone.steady};
    await tester.pumpWidget(_host(SizedBox(
      width: 340,
      height: 236,
      child: MonthTreeView(year: 2026, month: 10, tones: tones, reveal: true, onDayTap: (d) => tapped = d),
    )));
    await tester.pump(const Duration(seconds: 3)); // reveal finishes, wind keeps going
    expect(tester.takeException(), isNull);

    // Tap where day 12's leaf rests (same fit the painter uses).
    final tree = MonthTree.of(2026, 10);
    final leaf = tree.leaves.firstWhere((l) => l.day == 12);
    final b = treeBounds(tree);
    final bw = (b.maxX - b.minX) * 1.24, bh = (b.maxY - b.minY) * 1.24;
    final k = (340 / bw) < (236 / bh) ? 340 / bw : 236 / bh;
    final (x, y, _) = projectPoint(leaf.pos, kTreeYaw, kTreeTilt);
    final topLeft = tester.getTopLeft(find.byType(MonthTreeView));
    final top = (236 - (b.maxY - b.minY) * k) / 2;
    await tester.tapAt(topLeft + Offset(170 + (x - (b.minX + b.maxX) / 2) * k, top + (b.maxY - y) * k));
    expect(tapped, isNotNull);

    // A day changing colour grows its leaf in again without errors.
    await tester.pumpWidget(_host(SizedBox(
      width: 340,
      height: 236,
      child: MonthTreeView(year: 2026, month: 10, tones: {...tones, 7: DayTone.full}, onDayTap: (d) {}),
    )));
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
  });

  testWidgets('still thumbnails render in both themes', (tester) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(_host(
        SizedBox(width: 160, height: 108, child: MonthTreeView(year: 2026, month: 9, tones: const {1: DayTone.light, 2: DayTone.gold}, animate: false)),
        brightness: b,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
