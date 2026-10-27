import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';

/// Pressed state is shown by a small scale-down instead of an ink ripple.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.semanticLabel, this.haptic = false});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down ? Motion.pressScale : 1,
          duration: Motion.press,
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// A surface that sets one element apart. Light mode gets a soft shadow;
/// dark mode relies on the lifted surface colour alone.
class MariCard extends StatelessWidget {
  const MariCard({super.key, required this.child, this.padding = EdgeInsets.zero, this.color, this.outlined = false});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: Radii.cardAll,
        border: outlined ? Border.all(color: c.separator) : null,
        boxShadow: dark || outlined || color != null
            ? null
            : const [
                BoxShadow(color: Color(0x0D17161A), blurRadius: 2, offset: Offset(0, 1)),
                BoxShadow(color: Color(0x0D17161A), blurRadius: 20, offset: Offset(0, 6)),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Rows inside a card, divided by hairlines.
class SeparatedColumn extends StatelessWidget {
  const SeparatedColumn({super.key, required this.children, this.indent = 0});

  final List<Widget> children;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        out.add(Padding(
          padding: EdgeInsets.only(left: indent),
          child: Container(height: 0.5, color: c.separator),
        ));
      }
      out.add(children[i]);
    }
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: out);
  }
}

enum ButtonVariant { primary, secondary, destructive, ghost }

class MariButton extends StatelessWidget {
  const MariButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.small = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final IconData? icon;
  final bool small;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color bg, Color fg) = switch (variant) {
      ButtonVariant.primary => (c.accent, c.onAccent),
      ButtonVariant.secondary => (c.surfaceSunken, c.textPrimary),
      ButtonVariant.destructive => (c.spendSoft, c.spend),
      ButtonVariant.ghost => (Colors.transparent, c.accent),
    };
    final style = (small ? MariType.subhead.copyWith(fontWeight: FontWeight.w600) : MariType.button).copyWith(color: fg);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: small ? 18 : 20, color: fg), const SizedBox(width: Space.xs)],
        Flexible(child: Text(label, style: style, overflow: TextOverflow.ellipsis)),
      ],
    );
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: Pressable(
        onTap: onPressed,
        haptic: true,
        child: Container(
          height: small ? 40 : 52,
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: small ? Space.md : Space.lg),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(small ? 12 : 16)),
          child: content,
        ),
      ),
    );
  }
}

/// A pill segmented control with a sliding thumb.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
    this.expand = false,
    this.large = false,
  });

  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool expand;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final index = values.indexOf(selected).clamp(0, values.length - 1);
    final textStyle = (large ? MariType.subhead : MariType.footnote).copyWith(fontWeight: FontWeight.w600);
    final segmentHeight = large ? 40.0 : 32.0;

    Widget segment(T v) => Expanded(
          child: Semantics(
            selected: v == selected,
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (v != selected) {
                  HapticFeedback.selectionClick();
                  onChanged(v);
                }
              },
              child: SizedBox(
                height: segmentHeight,
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: textStyle.copyWith(color: v == selected ? c.textPrimary : c.textSecondary),
                    child: Text(labelOf(v), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
            ),
          ),
        );

    final control = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              duration: Motion.currencySwap,
              curve: Motion.currencySwapCurve,
              alignment: Alignment(values.length == 1 ? 0 : -1 + 2 * index / (values.length - 1), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / values.length,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.surfaceRaised,
                    borderRadius: BorderRadius.circular(Radii.pill),
                    boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 3, offset: Offset(0, 1))],
                  ),
                ),
              ),
            ),
          ),
          Row(children: values.map(segment).toList()),
        ],
      ),
    );

    if (expand) return control;
    return IntrinsicWidth(
      child: ConstrainedBox(constraints: BoxConstraints(minWidth: values.length * (large ? 96.0 : 56.0)), child: control),
    );
  }
}

class MariSwitch extends StatelessWidget {
  const MariSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: context.colors.income);
  }
}

class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, this.icon, this.selected = false, this.onTap, this.color, this.iconColor});

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.background : (color ?? c.textPrimary);
    return Pressable(
      onTap: onTap,
      haptic: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.textPrimary : c.surface,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: selected ? c.textPrimary : c.separator),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 17, color: selected ? c.background : (iconColor ?? c.textSecondary)), const SizedBox(width: 6)],
          Text(label, style: MariType.subhead.copyWith(fontSize: 14, color: fg)),
        ]),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action, this.onAction, this.caption = false, this.trailing, this.leading});

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final bool caption;
  final Widget? trailing;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: caption ? CrossAxisAlignment.center : CrossAxisAlignment.end,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Expanded(
            child: Text(
              caption ? title.toUpperCase() : title,
              style: caption ? MariType.caption.copyWith(color: c.textSecondary) : MariType.title2.copyWith(color: c.textPrimary),
            ),
          ),
          if (trailing != null) trailing!,
          if (action != null)
            Pressable(onTap: onAction, child: Text(action!, style: MariType.callout.copyWith(color: c.accent))),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xl),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 40, color: c.textTertiary),
        const SizedBox(height: Space.sm),
        Text(title, textAlign: TextAlign.center, style: MariType.headline.copyWith(color: c.textPrimary)),
        const SizedBox(height: Space.xxs),
        Text(body, textAlign: TextAlign.center, style: MariType.callout.copyWith(color: c.textSecondary)),
        if (action != null) ...[const SizedBox(height: Space.md), action!],
      ]),
    );
  }
}

class MariTextField extends StatelessWidget {
  const MariTextField({
    super.key,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.prefixIcon,
    this.onChanged,
    this.autofocus = false,
    this.textInputAction,
    this.style,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? minLines;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final TextStyle? style;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: Radii.controlAll,
          borderSide: BorderSide(color: color, width: width),
        );
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      autofocus: autofocus,
      onChanged: onChanged,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      style: style ?? MariType.body.copyWith(color: c.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: MariType.body.copyWith(color: c.textTertiary),
        filled: true,
        fillColor: c.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, color: c.textTertiary, size: 20),
        enabledBorder: border(c.separator, 1),
        focusedBorder: border(c.accent, 2),
        border: border(c.separator, 1),
      ),
    );
  }
}

/// Grouped settings-style list.
class MariList extends StatelessWidget {
  const MariList({super.key, required this.children, this.label, this.footer});

  final List<Widget> children;
  final String? label;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xs),
            child: Text(label!.toUpperCase(), style: MariType.caption.copyWith(color: c.textSecondary)),
          ),
        MariCard(child: SeparatedColumn(indent: Space.md, children: children)),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, 0),
            child: Text(footer!, style: MariType.footnote.copyWith(color: c.textTertiary)),
          ),
      ]),
    );
  }
}

class MariListTile extends StatelessWidget {
  const MariListTile({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.chevron = true,
  });

  final String title;
  final IconData? icon;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
        child: Row(children: [
          if (icon != null) ...[Icon(icon, size: 20, color: destructive ? c.spend : c.textSecondary), const SizedBox(width: Space.sm)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: MariType.callout.copyWith(color: destructive ? c.spend : c.textPrimary)),
              if (subtitle != null) Text(subtitle!, style: MariType.footnote.copyWith(color: c.textSecondary)),
            ]),
          ),
          if (value != null) ...[
            const SizedBox(width: Space.xs),
            Flexible(child: Text(value!, textAlign: TextAlign.right, style: MariType.callout.copyWith(color: c.textSecondary))),
          ],
          if (trailing != null) ...[const SizedBox(width: Space.xs), trailing!],
          if (trailing == null && onTap != null && chevron && !destructive) ...[
            const SizedBox(width: Space.xxs),
            Icon(Icons.chevron_right_rounded, size: 20, color: c.textTertiary),
          ],
        ]),
      ),
    );
    return onTap == null ? row : Pressable(onTap: onTap, child: row);
  }
}

/// Circular icon button used in screen headers.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({super.key, required this.icon, required this.onTap, required this.label});
  final IconData icon;
  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: c.surface,
          shape: BoxShape.circle,
          boxShadow: Theme.of(context).brightness == Brightness.dark
              ? null
              : const [BoxShadow(color: Color(0x1417161A), blurRadius: 12, offset: Offset(0, 3))],
        ),
        child: Icon(icon, size: 21, color: onTap == null ? c.textTertiary : c.textSecondary),
      ),
    );
  }
}

/// Large screen title with optional trailing control, used at the top of each tab.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs, bottom: Space.md),
      child: Row(children: [
        Expanded(child: Text(title, style: MariType.title1.copyWith(color: context.colors.textPrimary))),
        if (trailing != null) trailing!,
      ]),
    );
  }
}
