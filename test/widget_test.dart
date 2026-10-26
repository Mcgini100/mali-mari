import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mari/core/money/money.dart';
import 'package:mari/core/theme/app_theme.dart';
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
}
