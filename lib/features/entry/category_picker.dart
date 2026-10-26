import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/category_icons.dart';
import '../../core/theme/tokens.dart';
import '../../domain/models.dart';
import '../../widgets/money.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sheet.dart';

/// Lets the person pick a category that fits the direction. Returns its id.
Future<String?> pickCategory(BuildContext context, {required Direction direction, String? selected}) {
  return showMariSheet<String>(context, builder: (_) => _CategoryPicker(direction: direction, selected: selected));
}

class _CategoryPicker extends ConsumerWidget {
  const _CategoryPicker({required this.direction, this.selected});
  final Direction direction;
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(settingsProvider.select((x) => x.language));
    final cats = (ref.watch(categoriesProvider).asData?.value ?? const <Category>[])
        .where((cat) => direction == Direction.moneyIn ? cat.kind == CategoryKind.income : cat.kind != CategoryKind.income)
        .toList();

    return Column(mainAxisSize: MainAxisSize.min, children: [
      SheetHeader(title: s[K.category], leading: s[K.cancel]),
      Flexible(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
          children: [
            MariCard(
              child: SeparatedColumn(indent: 62, children: [
                for (final cat in cats)
                  Pressable(
                    onTap: () => Navigator.of(context).pop(cat.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 10),
                      child: Row(children: [
                        IconTile(icon: categoryIcon(cat.icon), income: cat.kind == CategoryKind.income, size: 34),
                        const SizedBox(width: Space.sm),
                        Expanded(child: Text(cat.name(lang), style: MariType.callout.copyWith(color: c.textPrimary))),
                        if (cat.id == selected) Icon(Icons.check_rounded, color: c.accent, size: 20),
                      ]),
                    ),
                  ),
              ]),
            ),
          ],
        ),
      ),
    ]);
  }
}
