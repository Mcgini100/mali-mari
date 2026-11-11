import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/l10n/strings.dart';
import '../core/money/money.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/category_icons.dart';
import '../core/theme/tokens.dart';
import '../domain/budget_math.dart';
import 'money.dart';
import 'primitives.dart';

/// Thin progress bar. Accent while on track, amber from 85%, terracotta over.
/// Reads correctly at 0% (empty track) and past 100% (full, in the over colour).
class BudgetBar extends StatelessWidget {
  const BudgetBar({super.key, required this.progress, this.height = 6, this.color, this.trackColor});
  final double progress;
  final double height;

  /// Overrides for a bar that sits on a tinted ground or follows its own rule.
  final Color? color;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = this.color ?? (progress > 1 ? c.spend : (progress >= 0.85 ? c.warning : c.accent));
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.pill),
      child: Container(
        height: height,
        color: trackColor ?? c.surfaceSunken,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
          duration: Motion.balanceRoll,
          curve: Motion.balanceRollCurve,
          builder: (context, v, _) => FractionallySizedBox(
            widthFactor: v,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radii.pill)),
            ),
          ),
        ),
      ),
    );
  }
}

/// The budget used so far as a bar, with a tick where the calendar is. Bar
/// short of the tick: spending is behind the month. Past it: ahead.
class PaceTrack extends StatelessWidget {
  const PaceTrack({super.key, required this.used, required this.elapsed, required this.pace, this.semanticLabel});

  final double used;
  final double elapsed;
  final Pace pace;
  final String? semanticLabel;

  static const double _height = 16;
  static const double _bar = 6;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fill = switch (pace) {
      Pace.over => c.spend,
      Pace.ahead => c.warning,
      Pace.onTrack || Pace.none => c.accent,
    };
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height: _height,
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            final tick = (elapsed.clamp(0.0, 1.0) * w).clamp(1.0, w - 1.0);
            return Stack(children: [
              Positioned(
                left: 0,
                right: 0,
                top: (_height - _bar) / 2,
                child: BudgetBar(
                  progress: used,
                  height: _bar,
                  color: fill,
                  trackColor: c.textPrimary.withValues(alpha: 0.10),
                ),
              ),
              Positioned(
                left: tick - 1,
                top: 0,
                child: Container(
                  width: 2,
                  height: _height,
                  decoration: BoxDecoration(color: c.textPrimary, borderRadius: BorderRadius.circular(1)),
                ),
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

/// A budget line shown in the person's display currency (limits convert at
/// today's rate; spending uses each payment's frozen equivalent).
class BudgetLineTile extends ConsumerWidget {
  const BudgetLineTile({super.key, required this.line, this.onTap});

  final BudgetLine line;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(settingsProvider.select((x) => x.language));
    final display = ref.watch(displayCurrencyProvider);
    final rate = ref.watch(currentRateProvider);

    int inDisplay(int minor) => Money.convert(minor, line.budget.currency, display, rate);
    final spent = inDisplay(line.spent);
    final limit = inDisplay(line.limit);

    String? stateText;
    Color? stateColor;
    if (line.isOver) {
      stateText = s.f(K.budgetOver, {'amount': Money.format(spent - limit, display, cents: false)});
      stateColor = c.spend;
    } else if (line.isNearLimit) {
      stateText = s.f(K.budgetPercentUsed, {'percent': '${(line.progress * 100).round()}'});
      stateColor = c.warningInk;
    }

    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconTile(icon: categoryIcon(line.category.icon), tint: categoryTint(line.category.id), size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(line.category.name(lang),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: MariType.subhead.copyWith(color: c.textPrimary)),
          ),
          Text(
            '${Money.format(spent, display, cents: false)} ${s[K.of]} ${Money.format(limit, display, cents: false)}',
            style: MariType.footnote.copyWith(color: c.textSecondary),
          ),
        ]),
        const SizedBox(height: 7),
        BudgetBar(progress: line.progress),
        if (stateText != null) ...[
          const SizedBox(height: 6),
          Text(stateText, style: MariType.footnote.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: stateColor)),
        ],
      ]),
    );
    return onTap == null ? body : Pressable(onTap: onTap, child: body);
  }
}
