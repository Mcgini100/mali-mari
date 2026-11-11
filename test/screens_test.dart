import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mari/app/app.dart';
import 'package:mari/app/settings.dart';
import 'package:mari/core/l10n/language.dart';
import 'package:mari/core/money/money.dart';
import 'package:mari/features/home/home_screen.dart';
import 'package:mari/features/tree/month_tree_view.dart';

import 'support/sample_month.dart';

/// Runs the whole app on the sample month and walks the main screens in both
/// themes. Two jobs:
///
///  1. Any layout overflow or exception on a real phone size fails the test.
///  2. Each screen is saved to build/screens/*.png (CI uploads them), so a
///     change to the UI can be looked at without installing a build.
const _phone = Size(390, 844);
const _smallPhone = Size(360, 640);
const _pixelRatio = 2.0;

final _shot = GlobalKey();

/// Real glyphs instead of the test font's boxes, when the Flutter SDK's own
/// copies of Roboto and Material Icons can be found. Without them the test
/// still checks layout; only the pictures are less useful.
Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;

  Future<ByteData> bytes(File f) async => ByteData.view(Uint8List.fromList(f.readAsBytesSync()).buffer);

  final roboto = FontLoader('Roboto');
  var any = false;
  for (final name in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    final f = File('${dir.path}/$name');
    if (f.existsSync()) {
      roboto.addFont(bytes(f));
      any = true;
    }
  }
  if (any) await roboto.load();

  final iconFile = File('${dir.path}/MaterialIcons-Regular.otf');
  if (iconFile.existsSync()) {
    final icons = FontLoader('MaterialIcons')..addFont(bytes(iconFile));
    await icons.load();
  }
}

Future<void> _save(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary = _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: _pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('build/screens/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester tester, [int ms = 2400]) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _run(
  WidgetTester tester, {
  required Size size,
  required AppSettings settings,
  required Future<void> Function() body,
  bool withData = true,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size * _pixelRatio;
  tester.view.devicePixelRatio = _pixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  final db = (await tester.runAsync(() => openSampleDatabase(withData: withData)))!;
  await tester.pumpWidget(RepaintBoundary(
    key: _shot,
    child: ProviderScope(overrides: sampleOverrides(db, settings: settings), child: const MariApp()),
  ));
  await _settle(tester);
  expect(tester.takeException(), isNull);

  await body();
  expect(tester.takeException(), isNull);

  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
  await db.close();
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('light: home, its sheets and every tab', (tester) async {
    await _run(
      tester,
      size: _phone,
      settings: const AppSettings(onboarded: true, themeMode: ThemeMode.light),
      body: () async {
        // The number comes before the tree, and both are on the first screen.
        final hero = tester.getRect(find.text(Money.format(14882, Currency.usd)));
        final tree = tester.getRect(find.byType(MonthTreeView));
        expect(hero.bottom, lessThan(tree.top));
        expect(tree.bottom, lessThan(_phone.height - 80), reason: 'the tree must be visible without scrolling');
        expect(find.byType(PaceTrack), findsOneWidget);
        await _save(tester, 'home-light');

        await tester.tap(find.byIcon(Icons.info_outline_rounded));
        await _settle(tester, 800);
        expect(find.text('What the colours mean'), findsOneWidget);
        await _save(tester, 'leaf-key-light');
        await tester.tap(find.text('Done'));
        await _settle(tester, 800);

        await tester.tap(find.textContaining('Today:'));
        await _settle(tester, 800);
        await _save(tester, 'day-light');
        await tester.tap(find.text('Done'));
        await _settle(tester, 800);

        await tester.drag(find.byType(ListView).first, const Offset(0, -520));
        await _settle(tester, 600);
        await _save(tester, 'home-lists-light');

        for (final tab in ['History', 'Budgets', 'Insights']) {
          await tester.tap(find.text(tab).last);
          await _settle(tester, 600);
          expect(tester.takeException(), isNull, reason: '$tab tab');
          await _save(tester, '${tab.toLowerCase()}-light');
        }
      },
    );
  });

  testWidgets('dark: home and budgets', (tester) async {
    await _run(
      tester,
      size: _phone,
      settings: const AppSettings(onboarded: true, themeMode: ThemeMode.dark, displayCurrency: Currency.zig),
      body: () async {
        await _save(tester, 'home-dark-zig');
        await tester.tap(find.text('Budgets').last);
        await _settle(tester, 600);
        await _save(tester, 'budgets-dark-zig');
      },
    );
  });

  testWidgets('a first day with nothing logged', (tester) async {
    await _run(
      tester,
      size: _phone,
      withData: false,
      settings: const AppSettings(onboarded: true, themeMode: ThemeMode.light),
      body: () async {
        expect(find.byType(MonthTreeView), findsOneWidget);
        expect(find.byType(PaceTrack), findsNothing, reason: 'no budget, so nothing to pace against');
        await _save(tester, 'home-empty-light');
      },
    );
  });

  for (final lang in AppLanguage.values) {
    testWidgets('small phone, largest text, ${lang.name}: nothing overflows', (tester) async {
      await _run(
        tester,
        size: _smallPhone,
        textScale: 2, // the app clamps this to kMaxTextScale
        settings: AppSettings(onboarded: true, themeMode: ThemeMode.light, language: lang, displayCurrency: Currency.zig),
        body: () async {
          await _save(tester, 'home-small-large-text-${lang.name}');
          await tester.drag(find.byType(ListView).first, const Offset(0, -600));
          await _settle(tester, 400);
          expect(tester.takeException(), isNull, reason: 'home lists');
          for (final icon in [Icons.receipt_long_outlined, Icons.pie_chart_outline_rounded, Icons.insights_outlined]) {
            await tester.tap(find.byIcon(icon).last);
            await _settle(tester, 600);
            expect(tester.takeException(), isNull, reason: 'tab $icon');
          }
        },
      );
    });
  }
}
