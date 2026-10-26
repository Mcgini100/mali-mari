import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/primitives.dart';

/// iOS gives no app access to Messages. A personal Shortcuts automation can,
/// with the person's own setup, hand each EcoCash or bank text to Mari via
/// mari://capture?text=… — it still lands in Review, never straight in the books.
class ShortcutGuideScreen extends ConsumerWidget {
  const ShortcutGuideScreen({super.key});

  static const captureUrl = 'mari://capture?text=';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    final steps = [K.shortcutStep1, K.shortcutStep2, K.shortcutStep3, K.shortcutStep4, K.shortcutStep5, K.shortcutStep6];

    return Scaffold(
      appBar: AppBar(backgroundColor: c.background, surfaceTintColor: Colors.transparent, scrolledUnderElevation: 0, foregroundColor: c.accent),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
        children: [
          Text(s[K.shortcutTitle], style: MariType.title1.copyWith(color: c.textPrimary)),
          const SizedBox(height: Space.xs),
          Text(s[K.shortcutIntro], style: MariType.callout.copyWith(color: c.textSecondary)),
          const SizedBox(height: Space.lg),
          MariCard(
            child: SeparatedColumn(children: [
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
                      child: Text('${i + 1}', style: MariType.footnote.copyWith(color: c.accent, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(child: Text(s[steps[i]], style: MariType.callout.copyWith(color: c.textPrimary))),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: Space.md),
          Text(s[K.shortcutUrlLabel].toUpperCase(), style: MariType.caption.copyWith(color: c.textSecondary)),
          const SizedBox(height: Space.xs),
          MariCard(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            child: Row(children: [
              Expanded(child: SelectableText(captureUrl, style: MariType.callout.copyWith(color: c.textPrimary))),
              MariButton(
                label: s[K.copy],
                small: true,
                expand: false,
                variant: ButtonVariant.secondary,
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: captureUrl));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s[K.copied])));
                },
              ),
            ]),
          ),
          const SizedBox(height: Space.md),
          Text(s[K.shortcutFootnote], style: MariType.footnote.copyWith(color: c.textTertiary)),
        ],
      ),
    );
  }
}
