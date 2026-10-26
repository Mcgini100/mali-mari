import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/l10n/strings.dart';
import '../core/money/money.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/category_icons.dart';
import '../core/theme/tokens.dart';
import '../domain/budget_math.dart';
import 'primitives.dart';

/// Thin progress bar. Accent while on track, amber from 85%, terracotta over.
/// Reads correctly at 0% (empty track) and past 100% (full, in the over colour).
class BudgetBar extends StatelessWidget {
  const BudgetBar({super.key, required this.progress, this.height = 6});
  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = progress > 1 ? c.spend : (progress >= 0.85 ? c.warning : c.accent);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.pill),
      child: Container(
        height: height,
        color: c.surfaceSunken,
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
      stateColor = c.warning;
    }

    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(categoryIcon(line.category.icon), size: 18, color: c.textSecondary),
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
