import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/l10n/strings.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/category_icons.dart';
import '../core/theme/tokens.dart';
import '../domain/models.dart';
import 'money.dart';
import 'primitives.dart';

IconData sourceIcon(EntrySource s) => switch (s) {
      EntrySource.manual => Icons.edit_rounded,
      EntrySource.pasted => Icons.content_paste_rounded,
      EntrySource.captured => Icons.notifications_rounded,
    };

String sourceLabel(Strings s, EntrySource src) => switch (src) {
      EntrySource.manual => s[K.sourceManual],
      EntrySource.pasted => s[K.sourcePasted],
      EntrySource.captured => s[K.sourceCaptured],
    };

/// One transaction: icon, who, where it came from, amount as it happened and
/// its equivalent in the other currency.
class EntryTile extends ConsumerWidget {
  const EntryTile({super.key, required this.entry, this.onTap});

  final Entry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    final cat = ref.watch(categoryMapProvider)[entry.categoryId];
    final lang = ref.watch(settingsProvider.select((x) => x.language));
    final isIn = entry.direction == Direction.moneyIn;
    final catName = cat?.name(lang) ?? s[K.uncategorised];
    final title = entry.counterparty.isNotEmpty ? entry.counterparty : (entry.note.isNotEmpty ? entry.note : catName);

    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 11),
        child: Row(children: [
          IconTile(icon: categoryIcon(cat?.icon), tint: categoryTint(entry.categoryId ?? 'other')),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: MariType.subhead.copyWith(color: c.textPrimary)),
              const SizedBox(height: 1),
              Row(children: [
                Icon(sourceIcon(entry.source), size: 13, color: c.textSecondary),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    '${sourceLabel(s, entry.source)} · $catName · ${s.time(entry.occurredAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MariType.footnote.copyWith(color: c.textSecondary),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: Space.xs),
          AmountWithEquivalent(
            minor: entry.amountMinor,
            currency: entry.currency,
            equivalentMinor: entry.amountIn(entry.currency.other),
            isIncome: isIn,
          ),
        ]),
      ),
    );
  }
}
