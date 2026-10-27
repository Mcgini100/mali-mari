import 'package:flutter/material.dart';

import '../core/money/money.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';

/// A money figure that counts from its old value to its new one. Digits are
/// tabular, so the width never jitters while it rolls. Changing [currency]
/// swaps the figure instead (old one rises out, new one rises in), because
/// rolling from a dollar figure to a ZiG figure would tell a false story.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney({
    super.key,
    required this.minor,
    required this.currency,
    required this.style,
    this.cents = true,
    this.signed = false,
  });

  final int minor;
  final Currency currency;
  final TextStyle style;
  final bool cents;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final roll = TweenAnimationBuilder<double>(
      key: ValueKey(currency),
      tween: Tween<double>(begin: minor.toDouble(), end: minor.toDouble()),
      duration: Motion.balanceRoll,
      curve: Motion.balanceRollCurve,
      builder: (context, value, _) => Text(
        Money.format(value.round(), currency, cents: cents, signed: signed),
        style: style,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
      ),
    );

    return ClipRect(
      child: AnimatedSwitcher(
        duration: Motion.currencySwap,
        switchInCurve: Motion.currencySwapCurve,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerLeft,
          children: [...previous, if (current != null) current],
        ),
        transitionBuilder: (child, animation) {
          final incoming = child.key == ValueKey(currency);
          final offset = Tween<Offset>(
            begin: incoming ? const Offset(0, 0.18) : const Offset(0, -0.18),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(opacity: animation, child: SlideTransition(position: offset, child: child));
        },
        child: roll,
      ),
    );
  }
}

/// Amount as it happened, with its converted equivalent underneath.
class AmountWithEquivalent extends StatelessWidget {
  const AmountWithEquivalent({
    super.key,
    required this.minor,
    required this.currency,
    required this.equivalentMinor,
    this.isIncome = false,
  });

  final int minor;
  final Currency currency;
  final int equivalentMinor;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
      Text(
        Money.format(minor, currency, signed: isIncome),
        style: MariType.subhead.copyWith(color: isIncome ? c.income : c.textPrimary),
      ),
      Text(
        '≈ ${Money.format(equivalentMinor, currency.other, cents: currency.other == Currency.usd)}',
        style: MariType.footnote.copyWith(fontSize: 12, height: 16 / 12, color: c.textTertiary),
      ),
    ]);
  }
}

/// The rounded tile that carries a category icon, in the category's soft tint.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, this.tint, this.income = false, this.size = 38});
  final IconData icon;
  final CategoryTint? tint;
  final bool income;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pair = tint != null ? c.tint(tint!) : (income ? TintPair(c.income, c.incomeSoft) : TintPair(c.textSecondary, c.surfaceSunken));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: pair.wash, borderRadius: BorderRadius.circular(size * 0.32)),
      child: Icon(icon, size: size * 0.53, color: pair.ink),
    );
  }
}
