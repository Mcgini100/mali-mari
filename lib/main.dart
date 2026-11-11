import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/settings.dart';
import 'capture/capture_service.dart';
import 'capture/message_parser.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';
import 'data/db/database.dart';
import 'data/repositories/catalog_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _start();
}

/// Everything the first frame needs is local: open the database, read
/// settings, load the parser templates. No network on the startup path.
/// If any of it fails, say so instead of leaving a blank screen.
Future<void> _start() async {
  try {
    final db = MariDatabase();
    final settings = AppSettings.fromStore(await SettingsStore(db).readAll());
    final parser = MessageParser.fromJsonString(await rootBundle.loadString('assets/parser/templates.json'));

    runApp(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialSettingsProvider.overrideWithValue(settings),
        messageParserProvider.overrideWithValue(parser),
      ],
      child: const MariApp(),
    ));
  } catch (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'mari startup'));
    runApp(const StartupFailure(onRetry: _start));
  }
}

/// Shown when Mari cannot open its own data. English only: the language
/// setting lives in the database that failed to open.
class StartupFailure extends StatelessWidget {
  const StartupFailure({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildMariTheme(Brightness.light),
      darkTheme: buildMariTheme(Brightness.dark),
      home: Builder(builder: (context) {
        final c = context.colors;
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Mari could not open your records', style: MariType.title2.copyWith(color: c.textPrimary)),
                const SizedBox(height: Space.xs),
                Text(
                  'Nothing has been deleted. Your phone may be low on storage, or the app was closed while saving. Free some space, then try again.',
                  style: MariType.body.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: Space.lg),
                FilledButton(onPressed: onRetry, child: const Text('Try again')),
              ]),
            ),
          ),
        );
      }),
    );
  }
}
