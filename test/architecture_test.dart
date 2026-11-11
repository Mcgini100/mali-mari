import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The layering in docs/ARCHITECTURE.md, enforced. Each rule fails with the
/// file and the import that broke it, so the fix is obvious.
///
///   core      knows nothing about the app
///   domain    pure Dart on top of core
///   data      Drift and the network; the only place that knows either
///   capture   message parsing and ingestion
///   app       wiring (providers, lifecycle, the MaterialApp)
///   widgets   shared building blocks
///   features  screens
void main() {
  final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart')).toList();

  String layerOf(String path) => path.replaceAll('\\', '/').split('/')[1];

  /// Every import in [file] as a path from the repo root ("lib/domain/models.dart")
  /// or, for packages, the URI itself ("package:drift/drift.dart").
  List<String> importsOf(File file) {
    final out = <String>[];
    final dir = file.parent.uri;
    for (final line in file.readAsLinesSync()) {
      final m = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''').firstMatch(line);
      if (m == null) continue;
      final uri = m.group(1)!;
      if (uri.startsWith('dart:') || uri.startsWith('package:')) {
        out.add(uri.startsWith('package:mari/') ? 'lib/${uri.substring('package:mari/'.length)}' : uri);
      } else {
        final resolved = dir.resolve(uri).path;
        out.add(resolved.substring(resolved.indexOf('lib/')));
      }
    }
    return out;
  }

  void forbid(String layer, bool Function(String import) bad, String why) {
    final problems = <String>[];
    for (final f in files) {
      final path = f.path.replaceAll('\\', '/');
      if (layerOf(path) != layer) continue;
      for (final i in importsOf(f)) {
        if (bad(i)) problems.add('$path imports $i');
      }
    }
    expect(problems, isEmpty, reason: '$why\n${problems.join('\n')}');
  }

  bool inLayers(String import, List<String> layers) => layers.any((l) => import.startsWith('lib/$l/'));

  test('core depends on nothing else in the app', () {
    forbid('core', (i) => inLayers(i, ['app', 'capture', 'data', 'domain', 'features', 'widgets']), 'lib/core must stand alone.');
    forbid('core', (i) => i.startsWith('package:flutter_riverpod') || i.startsWith('package:drift'), 'lib/core has no state or storage.');
  });

  test('domain is pure Dart on top of core', () {
    forbid('domain', (i) => inLayers(i, ['app', 'capture', 'data', 'features', 'widgets']), 'lib/domain may only import lib/core and itself.');
    forbid('domain', (i) => i.startsWith('package:'), 'lib/domain must not need Flutter or any package.');
  });

  test('data does not know about screens or wiring', () {
    forbid('data', (i) => inLayers(i, ['app', 'capture', 'features', 'widgets']), 'lib/data sits below the app.');
    forbid('data', (i) => i.startsWith('package:flutter/') || i.startsWith('package:flutter_riverpod'), 'lib/data has no widgets and no providers.');
  });

  test('only data talks to Drift', () {
    // lib/app is the composition root: it opens the database and hands out repositories.
    for (final layer in ['capture', 'core', 'domain', 'features', 'widgets']) {
      forbid(layer, (i) => i.startsWith('package:drift') || i.startsWith('lib/data/db/'),
          'Drift types stay inside lib/data; everything else goes through a repository provider.');
    }
  });

  test('shared widgets do not depend on screens', () {
    forbid('widgets', (i) => inLayers(i, ['features', 'data']), 'lib/widgets is below lib/features.');
  });

  test('capture does not depend on screens', () {
    forbid('capture', (i) => inLayers(i, ['features', 'widgets']), 'lib/capture has no UI.');
  });

  test('nothing reads the wall clock directly', () {
    final problems = <String>[];
    for (final f in files) {
      final path = f.path.replaceAll('\\', '/');
      if (path == 'lib/core/util/clock.dart') continue;
      final lines = f.readAsLinesSync();
      for (var n = 0; n < lines.length; n++) {
        if (!lines[n].contains('DateTime.now()')) continue;
        if (lines[n].trimLeft().startsWith('//')) continue;
        if (n > 0 && lines[n - 1].contains('clock-ok')) continue;
        problems.add('$path:${n + 1}');
      }
    }
    expect(problems, isEmpty, reason: 'Read time from clockProvider or todayProvider so it can be pinned in tests.\n${problems.join('\n')}');
  });
}
