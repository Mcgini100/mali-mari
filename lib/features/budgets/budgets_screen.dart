import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/money/money.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/category_icons.dart';
import '../../core/theme/tokens.dart';
import '../../domain/budget_math.dart';
import '../../domain/models.dart';
import '../../widgets/budget_widgets.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sheet.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(settingsProvider.select((x) => x.language));
    final month = ref.watch(currentMonthProvider);
    final lines = ref.watch(budgetLinesProvider(month));
    final summary = ref.watch(monthSummaryProvider(month));
    final display = ref.watch(displayCurrencyProvider);
    final cats = ref.watch(categoriesProvider).asData?.value ?? const <Category>[];
    final budgeted = {for (final l in lines ?? const <BudgetLine>[]) l.category.id};
    final unbudgeted = cats.where((x) => x.kind == CategoryKind.expense && !budgeted.contains(x.id)).toList();
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
      children: [
        ScreenTitle(title: s[K.budgets], trailing: const CurrencySwitch()),
        if (summary != null && summary.hasBudget) ...[
          MariCard(
            padding: const EdgeInsets.all(Space.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.f(K.spentInMonth, {'month': s.month(month.month)}).toUpperCase(),
                  style: MariType.caption.copyWith(color: c.textSecondary)),
              const SizedBox(height: 6),
              Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: Space.xs, children: [
                Text(Money.format(summary.spent, display), style: MariType.title1.copyWith(color: c.textPrimary)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${s[K.of]} ${Money.format(summary.budgeted, display, cents: false)}',
                      style: MariType.callout.copyWith(color: c.textSecondary)),
                ),
              ]),
              const SizedBox(height: Space.sm),
              BudgetBar(progress: summary.usedFraction, height: 8),
              const SizedBox(height: 10),
              Text(
                s.f(K.paceLine, {
                  'day': '${now.day}',
                  'days': '${month.days}',
                  'used': '${(summary.usedFraction * 100).round()}',
                  'elapsed': '${(now.day / month.days * 100).round()}',
                }),
                style: MariType.footnote.copyWith(color: c.textSecondary),
              ),
            ]),
          ),
          const SizedBox(height: Space.lg),
        ],
        if (lines != null && lines.isNotEmpty) ...[
          SectionHeader(title: s[K.monthlyLimits], caption: true),
          MariCard(
            child: SeparatedColumn(children: [
              for (final l in lines)
                BudgetLineTile(line: l, onTap: () => showBudgetSheet(context, l.category, existing: l.budget)),
            ]),
          ),
          const SizedBox(height: Space.lg),
        ],
        if (unbudgeted.isNotEmpty) ...[
          SectionHeader(title: lines == null || lines.isEmpty ? s[K.setYourFirstLimit] : s[K.noLimitYet], caption: true),
          MariCard(
            child: SeparatedColumn(indent: 48, children: [
              for (final cat in unbudgeted)
                MariListTile(
                  icon: categoryIcon(cat.icon),
                  title: cat.name(lang),
                  trailing: Text(s[K.setLimit], style: MariType.callout.copyWith(color: c.accent)),
                  onTap: () => showBudgetSheet(context, cat),
                ),
            ]),
          ),
        ],
      ],
    );
  }
}

/// The small US$ / ZiG switch used in screen headers; it changes the display currency everywhere.
class CurrencySwitch extends ConsumerWidget {
  const CurrencySwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayCurrencyProvider);
    return Segmented<Currency>(
      values: const [Currency.usd, Currency.zig],
      labelOf: (x) => x.symbol,
      selected: display,
      onChanged: (x) => ref.read(settingsProvider.notifier).edit((st) => st.copyWith(displayCurrency: x)),
    );
  }
}

Future<void> showBudgetSheet(BuildContext context, Category category, {Budget? existing}) {
  return showMariSheet<void>(context, builder: (_) => _BudgetSheet(category: category, existing: existing));
}

class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet({required this.category, this.existing});
  final Category category;
  final Budget? existing;

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  late final TextEditingController _amount;
  late Currency _currency;
  late bool _rollover;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _amount = TextEditingController(text: b == null ? '' : Money.plain(b.amountMinor));
    _currency = b?.currency ?? ref.read(settingsProvider).homeCurrency;
    _rollover = b?.rollover ?? false;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int? get _minor {
    final v = Money.parseToMinor(_amount.text);
    return v == null || v <= 0 ? null : v;
  }

  Future<void> _save() async {
    final minor = _minor;
    if (minor == null) return;
    await ref.read(budgetRepositoryProvider).upsert(
          Budget(categoryId: widget.category.id, amountMinor: minor, currency: _currency, rollover: _rollover),
        );
    HapticFeedback.lightImpact();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    await ref.read(budgetRepositoryProvider).remove(widget.category.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(settingsProvider.select((x) => x.language));
    final rate = ref.watch(currentRateProvider);
    final minor = _minor;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      SheetHeader(
        title: widget.category.name(lang),
        leading: s[K.cancel],
        trailing: s[K.save],
        onTrailing: minor == null ? null : _save,
      ),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(s[K.monthlyLimit], style: MariType.footnote.copyWith(color: c.textSecondary)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: MariTextField(
                  controller: _amount,
                  hint: '0.00',
                  autofocus: widget.existing == null,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: Space.xs),
              Segmented<Currency>(
                values: const [Currency.usd, Currency.zig],
                labelOf: (x) => x.symbol,
                selected: _currency,
                onChanged: (x) => setState(() => _currency = x),
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              minor == null
                  ? ' '
                  : s.f(K.equivalentAtRate, {
                      'amount': Money.format(Money.convert(minor, _currency, _currency.other, rate), _currency.other, cents: false),
                      'rate': Money.formatRate(rate),
                    }),
              style: MariType.footnote.copyWith(color: c.textTertiary),
            ),
            const SizedBox(height: Space.md),
            MariCard(
              child: MariListTile(
                title: s[K.carryOver],
                subtitle: s[K.carryOverBody],
                trailing: MariSwitch(value: _rollover, onChanged: (v) => setState(() => _rollover = v)),
              ),
            ),
            if (widget.existing != null) ...[
              const SizedBox(height: Space.lg),
              MariButton(label: s[K.removeLimit], variant: ButtonVariant.destructive, onPressed: _remove),
            ],
          ]),
        ),
      ),
    ]);
  }
}
