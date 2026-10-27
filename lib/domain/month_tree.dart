import 'dart:math' as math;

/// The month tree: one msasa-shaped tree per month, its shape fixed by the
/// year and month alone. A line-for-line port of tool/month_tree.js, held to
/// the same output by test/month_tree_test.dart and its fixture.

const int kTreeMaxDays = 31;
const double kTreeYaw = 0.4;
const double kTreeTilt = 0.18;

/// How a day went, as a leaf colour. Every tone is a real msasa colour.
enum DayTone {
  /// Nothing logged that day.
  bud,

  /// More money came in than went out.
  gold,

  /// Spent at most half the daily pace.
  light,

  /// Up to the daily pace.
  steady,

  /// Up to 1.6 × pace.
  full,

  /// More than that.
  heavy,
}

DayTone dayTone({required int spend, required int income, required int pace, required bool hasEntries}) {
  if (!hasEntries) return DayTone.bud;
  if (income > 0 && income > spend) return DayTone.gold;
  if (spend <= 0) return DayTone.light;
  if (pace <= 0) return DayTone.steady;
  final ratio = spend / pace;
  if (ratio <= 0.5) return DayTone.light;
  if (ratio <= 1.0) return DayTone.steady;
  if (ratio <= 1.6) return DayTone.full;
  return DayTone.heavy;
}

class Vec3 {
  const Vec3(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 scale(double k) => Vec3(x * k, y * k, z * k);
  Vec3 cross(Vec3 b) => Vec3(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x);
  Vec3 normalized() {
    final l = math.sqrt(x * x + y * y + z * z);
    return Vec3(x / l, y / l, z / l);
  }
}

class TreeSegment {
  const TreeSegment(this.a, this.b, this.width, this.depth);
  final Vec3 a;
  final Vec3 b;
  final double width;
  final int depth;
}

class TreeLeaf {
  TreeLeaf(this.pos, this.size, this.rot, this.phase);
  final Vec3 pos;
  final double size;
  final double rot;
  final double phase;
  int day = 0;
}

class MonthTree {
  const MonthTree(this.segments, this.leaves, this.tips);
  final List<TreeSegment> segments;
  final List<TreeLeaf> leaves;
  final List<Vec3> tips;

  static final Map<int, MonthTree> _cache = {};

  /// Generated once per month and kept: the shape never changes.
  static MonthTree of(int year, int month) => _cache.putIfAbsent(year * 100 + month, () => generate(year, month));
}

/// Park–Miller minimal standard generator; identical sequences in JS and Dart.
double Function() treeRng(int seed) {
  var s = seed % 2147483647;
  if (s <= 0) s += 2147483646;
  return () {
    s = (s * 48271) % 2147483647;
    return (s - 1) / 2147483646;
  };
}

MonthTree generate(int year, int month) {
  const tau = math.pi * 2;
  final r = treeRng((year * 100 + month) * 7919);
  final segments = <TreeSegment>[];
  final tips = <Vec3>[];

  void grow(Vec3 start, Vec3 dir, double len, double w, int depth) {
    final end = start + dir.scale(len);
    segments.add(TreeSegment(start, end, w, depth));
    if (depth == 3) {
      tips.add(end);
      return;
    }
    final n = depth == 0 ? 3 : 2;
    final ref = dir.y.abs() < 0.9 ? const Vec3(0, 1, 0) : const Vec3(1, 0, 0);
    final u = dir.cross(ref).normalized();
    final v = dir.cross(u);
    final az0 = r() * tau;
    for (var i = 0; i < n; i++) {
      final az = az0 + (i * tau) / n + (r() - 0.5) * 0.6;
      final tilt = (depth == 0 ? 0.88 : 0.62) + (r() - 0.5) * 0.25;
      final side = u.scale(math.cos(az)) + v.scale(math.sin(az));
      var child = (dir.scale(math.cos(tilt)) + side.scale(math.sin(tilt))).normalized();
      // Msasa crowns spread wide and flat: damp upward growth near the top.
      if (depth >= 1) child = Vec3(child.x, child.y * 0.6, child.z).normalized();
      grow(end, child, len * (0.74 + r() * 0.1), w * 0.64, depth + 1);
    }
  }

  final trunkDir = Vec3((r() - 0.5) * 0.25, 1, (r() - 0.5) * 0.25).normalized();
  grow(const Vec3(0, 0, 0), trunkDir, 1.25, 0.24, 0);

  final leaves = <TreeLeaf>[];
  for (var i = 0; i < kTreeMaxDays; i++) {
    final tip = tips[i % tips.length];
    final offset = Vec3((r() - 0.5) * 0.8, (r() - 0.3) * 0.45, (r() - 0.5) * 0.8);
    final size = 0.2 + r() * 0.07;
    final rot = r() * math.pi;
    final phase = r() * tau;
    leaves.add(TreeLeaf(tip + offset, size, rot, phase));
  }
  // Days take slots in a shuffled order so the crown fills evenly.
  final order = List<int>.generate(kTreeMaxDays, (k) => k);
  for (var j = kTreeMaxDays - 1; j > 0; j--) {
    final x = (r() * (j + 1)).floor();
    final tmp = order[j];
    order[j] = order[x];
    order[x] = tmp;
  }
  for (var d = 0; d < kTreeMaxDays; d++) {
    leaves[order[d]].day = d + 1;
  }
  return MonthTree(segments, leaves, tips);
}

/// Orthographic view: turn by [yaw] around the trunk, tip toward the viewer by
/// [tilt], drop z. Returns (x, y up, depth — larger is nearer).
(double, double, double) projectPoint(Vec3 p, double yaw, double tilt) {
  final cy = math.cos(yaw), sy = math.sin(yaw);
  final x = p.x * cy + p.z * sy;
  final z = -p.x * sy + p.z * cy;
  final ct = math.cos(tilt), st = math.sin(tilt);
  final y = p.y * ct - z * st;
  final depth = p.y * st + z * ct;
  return (x, y, depth);
}

/// Bounds of the tree as drawn at the resting yaw, with room for leaves and haze.
({double minX, double maxX, double minY, double maxY}) treeBounds(MonthTree tree) {
  var minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity;
  void take(Vec3 p, double rad) {
    final (x, y, _) = projectPoint(p, kTreeYaw, kTreeTilt);
    minX = math.min(minX, x - rad);
    maxX = math.max(maxX, x + rad);
    minY = math.min(minY, y - rad);
    maxY = math.max(maxY, y + rad);
  }

  for (final s in tree.segments) {
    take(s.a, s.width);
    take(s.b, s.width);
  }
  for (final l in tree.leaves) {
    take(l.pos, l.size);
  }
  for (final t in tree.tips) {
    take(t, 0.55);
  }
  minY = math.min(minY, -0.2);
  return (minX: minX, maxX: maxX, minY: minY, maxY: maxY);
}
