import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../domain/month_tree.dart';

Color toneColor(DayTone tone, MariPalette p) => switch (tone) {
      DayTone.bud => p.bud,
      DayTone.gold => LeafColors.gold,
      DayTone.light => LeafColors.light,
      DayTone.steady => LeafColors.steady,
      DayTone.full => LeafColors.full,
      DayTone.heavy => LeafColors.heavy,
    };

/// The month tree, drawn the way the three.js prototype renders it: an
/// orthographic view of the same generated tree, turning gently in the wind,
/// each leaf fluttering on its own phase. A day whose leaf appears or changes
/// colour grows in with a small overshoot.
class MonthTreeView extends StatefulWidget {
  const MonthTreeView({
    super.key,
    required this.year,
    required this.month,
    required this.tones,
    this.onDayTap,
    this.reveal = false,
    this.animate = true,
    this.semanticLabel,
  });

  final int year;
  final int month;

  /// Days that have a leaf or bud. Days missing from the map are still to come.
  final Map<int, DayTone> tones;
  final ValueChanged<int>? onDayTap;

  /// Grow every leaf in, one after another, when first shown.
  final bool reveal;

  /// False for still thumbnails (Seasons shelf).
  final bool animate;
  final String? semanticLabel;

  @override
  State<MonthTreeView> createState() => _MonthTreeViewState();
}

class _MonthTreeViewState extends State<MonthTreeView> with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  final _clock = ValueNotifier<double>(0);

  /// Seconds (on [_clock]) at which each day's grow animation starts.
  final _growStart = <int, double>{};
  bool _still = false;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _ticker = createTicker((elapsed) => _clock.value = elapsed.inMicroseconds / 1e6);
      if (widget.reveal) {
        final days = widget.tones.keys.toList()..sort();
        for (final d in days) {
          _growStart[d] = 0.15 + (d - 1) * 0.045;
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncTicker();
  }

  @override
  void didUpdateWidget(MonthTreeView old) {
    super.didUpdateWidget(old);
    if (old.year != widget.year || old.month != widget.month) {
      _growStart.clear();
    } else if (widget.animate) {
      var changed = false;
      widget.tones.forEach((day, tone) {
        if (old.tones[day] != tone) {
          _growStart[day] = _clock.value;
          changed = true;
        }
      });
      if (changed) HapticFeedback.lightImpact();
    }
    _syncTicker();
  }

  /// With reduced motion the tree is drawn once, still and fully grown.
  void _syncTicker() {
    final t = _ticker;
    if (t == null) return;
    if (!_still && !t.isActive) t.start();
    if (_still && t.isActive) t.stop();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _tap(TapUpDetails d, Size size) {
    final cb = widget.onDayTap;
    if (cb == null) return;
    final tree = MonthTree.of(widget.year, widget.month);
    final fit = _Fit.of(tree, size);
    int? best;
    var bestDist = 0.4 * fit.k; // a finger's reach, in pixels
    for (final leaf in tree.leaves) {
      if (!widget.tones.containsKey(leaf.day)) continue;
      final (x, y, _) = projectPoint(leaf.pos, kTreeYaw, kTreeTilt);
      final dist = (Offset(fit.x(x), fit.y(y)) - d.localPosition).distance;
      if (dist < bestDist) {
        bestDist = dist;
        best = leaf.day;
      }
    }
    if (best != null) {
      HapticFeedback.selectionClick();
      cb(best);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: LayoutBuilder(builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: widget.onDayTap == null ? null : (d) => _tap(d, size),
          child: RepaintBoundary(
            child: CustomPaint(
              size: size,
              painter: _TreePainter(
                tree: MonthTree.of(widget.year, widget.month),
                tones: widget.tones,
                palette: palette,
                clock: _clock,
                growStart: _growStart,
                still: _still || !widget.animate,
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Maps tree space to pixels: the resting tree centred, with padding, ground at the bottom.
class _Fit {
  _Fit(this.k, this.ox, this.oy);
  final double k;
  final double ox;
  final double oy;

  double x(double tx) => ox + tx * k;
  double y(double ty) => oy - ty * k;

  static _Fit of(MonthTree tree, Size size) {
    final b = treeBounds(tree);
    const pad = 0.12;
    final bw = (b.maxX - b.minX) * (1 + pad * 2);
    final bh = (b.maxY - b.minY) * (1 + pad * 2);
    final k = math.min(size.width / bw, size.height / bh);
    final cx = (b.minX + b.maxX) / 2;
    final top = (size.height - (b.maxY - b.minY) * k) / 2;
    return _Fit(k, size.width / 2 - cx * k, top + b.maxY * k);
  }
}

class _TreePainter extends CustomPainter {
  _TreePainter({
    required this.tree,
    required this.tones,
    required this.palette,
    required this.clock,
    required this.growStart,
    required this.still,
  }) : super(repaint: clock);

  final MonthTree tree;
  final Map<int, DayTone> tones;
  final MariPalette palette;
  final ValueNotifier<double> clock;
  final Map<int, double> growStart;
  final bool still;

  static const _tau = math.pi * 2;

  /// tokens.json → motion.leafGrow: 0 → 1.25 at 0.35 s → 1 at 0.6 s.
  static double _growScale(double s) {
    if (s <= 0) return 0;
    if (s < 0.35) return 1.25 * (s / 0.35);
    if (s < 0.6) return 1.25 - 0.25 * ((s - 0.35) / 0.25);
    return 1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = clock.value;
    final fit = _Fit.of(tree, size);
    final yaw = kTreeYaw + (still ? 0 : Motion.treeSwayYaw * math.sin(t * _tau / Motion.treeSwayPeriodS));
    final k = fit.k;

    // Ground shadow.
    final ground = Offset(fit.x(0), fit.y(0));
    canvas.drawOval(
      Rect.fromCenter(center: ground, width: 2.8 * k, height: 0.32 * k),
      Paint()..color = const Color(0x0D000000),
    );

    // Canopy haze: where leaves will grow.
    final haze = Paint()..color = palette.haze.withValues(alpha: 0.12);
    for (final tip in tree.tips) {
      final (x, y, _) = projectPoint(tip, yaw, kTreeTilt);
      canvas.drawCircle(Offset(fit.x(x), fit.y(y - 0.05)), 0.55 * k, haze);
    }

    // Branches and leaves, far to near.
    final items = <(double, void Function())>[];
    final bark = Paint()
      ..color = palette.bark
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final s in tree.segments) {
      final (ax, ay, ad) = projectPoint(s.a, yaw, kTreeTilt);
      final (bx, by, bd) = projectPoint(s.b, yaw, kTreeTilt);
      items.add(((ad + bd) / 2, () {
        bark.strokeWidth = math.max(1, s.width * k);
        canvas.drawLine(Offset(fit.x(ax), fit.y(ay)), Offset(fit.x(bx), fit.y(by)), bark);
      }));
    }

    for (final leaf in tree.leaves) {
      final tone = tones[leaf.day];
      if (tone == null) continue;
      var (x, y, depth) = projectPoint(leaf.pos, yaw, kTreeTilt);
      if (!still) {
        final w = t * _tau / Motion.leafFlutterPeriodS + leaf.phase;
        x += Motion.leafFlutter * math.sin(w);
        y += Motion.leafFlutter * 0.6 * math.cos(w);
      }
      final start = growStart[leaf.day];
      final scale = (still || start == null) ? 1.0 : _growScale(t - start);
      if (scale <= 0) continue;
      final r = (tone == DayTone.bud ? leaf.size * 0.32 : leaf.size) * k * scale;
      final paint = Paint()..color = toneColor(tone, palette);
      final center = Offset(fit.x(x), fit.y(y));
      items.add((depth, () {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(-leaf.rot);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 1.44), paint);
        canvas.restore();
      }));
    }

    items.sort((a, b) => a.$1.compareTo(b.$1));
    for (final item in items) {
      item.$2();
    }

  }

  @override
  bool shouldRepaint(_TreePainter old) =>
      old.tree != tree || old.tones != tones || old.palette != palette || old.still != still;
}

/// Small dots explaining the leaf colours.
class TreeLegend extends StatelessWidget {
  const TreeLegend({super.key, required this.labels});

  /// Label per tone, in display order.
  final Map<DayTone, String> labels;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(spacing: 12, runSpacing: 4, children: [
      for (final e in labels.entries)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 9,
            height: 7,
            decoration: BoxDecoration(color: toneColor(e.key, c), borderRadius: BorderRadius.circular(9)),
          ),
          const SizedBox(width: 5),
          Text(e.value, style: MariType.footnote.copyWith(fontSize: 12, height: 16 / 12, color: c.textSecondary)),
        ]),
    ]);
  }
}
