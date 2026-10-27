import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mari/domain/month_tree.dart';

/// The Dart generator must draw exactly the tree the JavaScript reference
/// (tool/month_tree.js, used by the three.js prototype) draws.
/// Regenerate the fixture with: node tool/month_tree.js --fixture
void main() {
  const eps = 1e-9;
  final fixture = jsonDecode(File('test/fixtures/tree_2026_10.json').readAsStringSync()) as Map<String, dynamic>;
  final expected = fixture['tree'] as Map<String, dynamic>;
  final tree = generate(fixture['year'] as int, fixture['month'] as int);

  void closeVec(Vec3 v, List<dynamic> e) {
    expect(v.x, closeTo((e[0] as num).toDouble(), eps));
    expect(v.y, closeTo((e[1] as num).toDouble(), eps));
    expect(v.z, closeTo((e[2] as num).toDouble(), eps));
  }

  test('segments match the JavaScript reference', () {
    final segs = expected['segments'] as List<dynamic>;
    expect(tree.segments, hasLength(segs.length));
    for (var i = 0; i < segs.length; i++) {
      final e = segs[i] as Map<String, dynamic>;
      closeVec(tree.segments[i].a, e['a'] as List<dynamic>);
      closeVec(tree.segments[i].b, e['b'] as List<dynamic>);
      expect(tree.segments[i].width, closeTo((e['w'] as num).toDouble(), eps));
      expect(tree.segments[i].depth, e['depth']);
    }
  });

  test('leaves match the JavaScript reference, one per day', () {
    final leaves = expected['leaves'] as List<dynamic>;
    expect(tree.leaves, hasLength(kTreeMaxDays));
    for (var i = 0; i < leaves.length; i++) {
      final e = leaves[i] as Map<String, dynamic>;
      closeVec(tree.leaves[i].pos, e['pos'] as List<dynamic>);
      expect(tree.leaves[i].size, closeTo((e['size'] as num).toDouble(), eps));
      expect(tree.leaves[i].rot, closeTo((e['rot'] as num).toDouble(), eps));
      expect(tree.leaves[i].phase, closeTo((e['phase'] as num).toDouble(), eps));
      expect(tree.leaves[i].day, e['day']);
    }
    expect(tree.leaves.map((l) => l.day).toSet(), hasLength(kTreeMaxDays));
  });

  test('projection matches the JavaScript reference', () {
    final projected = fixture['projected'] as List<dynamic>;
    for (var i = 0; i < projected.length; i++) {
      final (x, y, d) = projectPoint(tree.leaves[i].pos, 0.4, 0.18);
      final e = projected[i] as List<dynamic>;
      expect(x, closeTo((e[0] as num).toDouble(), eps));
      expect(y, closeTo((e[1] as num).toDouble(), eps));
      expect(d, closeTo((e[2] as num).toDouble(), eps));
    }
  });

  test('each month has its own shape, and the same month always the same', () {
    final oct = generate(2026, 10);
    final nov = generate(2026, 11);
    expect(oct.leaves.first.pos.x, isNot(closeTo(nov.leaves.first.pos.x, 1e-6)));
    expect(MonthTree.of(2026, 10).leaves.first.pos.x, closeTo(oct.leaves.first.pos.x, eps));
  });

  group('dayTone', () {
    test('no records is a bud, more in than out is gold', () {
      expect(dayTone(spend: 0, income: 0, pace: 1000, hasEntries: false), DayTone.bud);
      expect(dayTone(spend: 500, income: 10000, pace: 1000, hasEntries: true), DayTone.gold);
    });

    test('spend against pace picks light, steady, full, heavy', () {
      expect(dayTone(spend: 500, income: 0, pace: 1000, hasEntries: true), DayTone.light);
      expect(dayTone(spend: 1000, income: 0, pace: 1000, hasEntries: true), DayTone.steady);
      expect(dayTone(spend: 1600, income: 0, pace: 1000, hasEntries: true), DayTone.full);
      expect(dayTone(spend: 1601, income: 0, pace: 1000, hasEntries: true), DayTone.heavy);
    });

    test('a logged day with no spending, or no pace yet, still gets a leaf', () {
      expect(dayTone(spend: 0, income: 0, pace: 1000, hasEntries: true), DayTone.light);
      expect(dayTone(spend: 800, income: 0, pace: 0, hasEntries: true), DayTone.steady);
    });
  });
}
