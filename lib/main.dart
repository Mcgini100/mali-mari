import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/settings.dart';
import 'capture/capture_service.dart';
import 'capture/message_parser.dart';
import 'data/db/database.dart';
import 'data/repositories/catalog_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Everything the first frame needs is local: open the database, read
  // settings, load the parser templates. No network on the startup path.
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
}
