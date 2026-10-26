import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import 'primitives.dart';

/// How many Mari sheets are open. The shell scales the screen behind while
/// this is above zero, so a sheet reads as a layer above the screen rather
/// than a replacement for it (depth).
final ValueNotifier<int> sheetDepth = ValueNotifier<int>(0);

Future<T?> showMariSheet<T>(BuildContext context, {required WidgetBuilder builder}) async {
  sheetDepth.value = sheetDepth.value + 1;
  try {
    return await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      barrierColor: Theme.of(context).brightness == Brightness.dark ? const Color(0x8C000000) : const Color(0x5217161A),
      builder: (ctx) => _SheetFrame(child: builder(ctx)),
    );
  } finally {
    sheetDepth.value = sheetDepth.value - 1;
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36,
          height: 5,
          margin: const EdgeInsets.only(top: Space.xs, bottom: Space.xxs),
          decoration: BoxDecoration(color: c.separator, borderRadius: BorderRadius.circular(99)),
        ),
        Flexible(child: child),
      ]),
    );
  }
}

/// Cancel · Title · Save, the iOS sheet convention people already know.
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    required this.leading,
    this.trailing,
    this.onTrailing,
    this.onLeading,
  });

  final String title;
  final String leading;
  final String? trailing;
  final VoidCallback? onLeading;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 6, Space.gutter, 10),
      child: Row(children: [
        Pressable(
          onTap: onLeading ?? () => Navigator.of(context).maybePop(),
          child: Text(leading, style: MariType.body.copyWith(color: c.accent)),
        ),
        Expanded(child: Text(title, textAlign: TextAlign.center, style: MariType.headline.copyWith(color: c.textPrimary))),
        if (trailing != null)
          Opacity(
            opacity: onTrailing == null ? 0.4 : 1,
            child: Pressable(
              onTap: onTrailing,
              child: Text(trailing!, style: MariType.body.copyWith(color: c.accent, fontWeight: FontWeight.w600)),
            ),
          )
        else
          SizedBox(width: (leading.length * 8).toDouble()),
      ]),
    );
  }
}

/// Scales its child back while a sheet is open.
class DepthScaler extends StatelessWidget {
  const DepthScaler({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: sheetDepth,
      child: child,
      builder: (context, depth, child) {
        final open = depth > 0;
        return AnimatedScale(
          scale: open ? 0.94 : 1,
          duration: Motion.sheetRise,
          curve: Motion.sheetCurve,
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: Motion.sheetRise,
            curve: Motion.sheetCurve,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(open ? Radii.sheet : 0)),
            child: child,
          ),
        );
      },
    );
  }
}
