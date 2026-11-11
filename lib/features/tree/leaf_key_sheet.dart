import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../domain/month_tree.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sheet.dart';
import 'month_tree_view.dart';

/// The leaf colours in the order a month usually shows them.
const List<DayTone> kLeafKeyOrder = [DayTone.light, DayTone.steady, DayTone.full, DayTone.heavy, DayTone.gold, DayTone.bud];

K _leafKeyBody(DayTone tone) => switch (tone) {
      DayTone.bud => K.leafKeyBud,
      DayTone.gold => K.leafKeyGold,
      DayTone.light => K.leafKeyLight,
      DayTone.steady => K.leafKeySteady,
      DayTone.full => K.leafKeyFull,
      DayTone.heavy => K.leafKeyHeavy,
    };

K _leafKeyName(DayTone tone) => switch (tone) {
      DayTone.bud => K.legendBud,
      DayTone.gold => K.legendGold,
      DayTone.light => K.legendLight,
      DayTone.steady => K.legendSteady,
      DayTone.full => K.legendFull,
      DayTone.heavy => K.legendHeavy,
    };

/// What each leaf colour means. Asked for once, then out of the way: Home
/// shows only the colours themselves.
Future<void> showLeafKeySheet(BuildContext context) {
  return showMariSheet<void>(context, builder: (_) => const _LeafKeySheet());
}

class _LeafKeySheet extends ConsumerWidget {
  const _LeafKeySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SheetHeader(title: s[K.leafKeyTitle], leading: s[K.done]),
      Flexible(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xxs, Space.gutter, Space.xl),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xxs, 0, Space.xxs, Space.md),
              child: Text(s[K.leafKeyIntro], style: MariType.callout.copyWith(color: c.textSecondary)),
            ),
            MariCard(
              child: SeparatedColumn(indent: 62, children: [
                for (final tone in kLeafKeyOrder)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
                    child: Row(children: [
                      LeafDot(tone: tone, width: 30, height: 23),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s[_leafKeyName(tone)], style: MariType.subhead.copyWith(fontWeight: FontWeight.w600, color: c.textPrimary)),
                          const SizedBox(height: 2),
                          Text(s[_leafKeyBody(tone)], style: MariType.footnote.copyWith(color: c.textSecondary)),
                        ]),
                      ),
                    ]),
                  ),
              ]),
            ),
          ],
        ),
      ),
    ]);
  }
}

/// A leaf-shaped swatch in a tone's colour.
class LeafDot extends StatelessWidget {
  const LeafDot({super.key, required this.tone, this.width = 11, this.height = 8.5});
  final DayTone tone;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: toneColor(tone, context.colors), borderRadius: BorderRadius.circular(width)),
    );
  }
}
