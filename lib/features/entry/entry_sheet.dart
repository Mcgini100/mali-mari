import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../capture/capture_service.dart';
import '../../core/l10n/strings.dart';
import '../../core/money/money.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/category_icons.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/dates.dart';
import '../../domain/models.dart';
import '../../domain/month_tree.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sheet.dart';

enum EntrySheetMode {
  /// New manual record, saved on Save.
  create,

  /// Existing confirmed record, saved on Save, deletable.
  edit,

  /// Editing a captured record during review: returns the edited entry, saves nothing.
  review,
}

/// Opens the add/edit sheet. Returns the saved (or, in review mode, edited) entry.
Future<Entry?> showEntrySheet(
  BuildContext context, {
  Entry? entry,
  EntrySheetMode mode = EntrySheetMode.create,
  String? prefillNote,
  DateTime? initialDate,
}) {
  return showMariSheet<Entry>(
    context,
    builder: (_) => EntrySheet(entry: entry, mode: mode, prefillNote: prefillNote, initialDate: initialDate),
  );
}

class EntrySheet extends ConsumerStatefulWidget {
  const EntrySheet({super.key, this.entry, this.mode = EntrySheetMode.create, this.prefillNote, this.initialDate});

  final Entry? entry;
  final EntrySheetMode mode;
  final String? prefillNote;

  /// For a new record on a past day (from a leaf's day sheet).
  final DateTime? initialDate;

  @override
  ConsumerState<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<EntrySheet> {
  late Direction _direction;
  late Currency _currency;
  late String _digits;
  String? _categoryId;
  late DateTime _when;
  late final TextEditingController _who;
  late final TextEditingController _note;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    final settings = ref.read(settingsProvider);
    _direction = e?.direction ?? Direction.moneyOut;
    _currency = e?.currency ?? settings.displayCurrency;
    _digits = e == null ? '' : _minorToDigits(e.amountMinor);
    _categoryId = e?.categoryId;
    _when = e?.occurredAt ?? _startOf(widget.initialDate) ?? DateTime.now();
    _who = TextEditingController(text: e?.counterparty ?? '');
    _note = TextEditingController(text: e?.note.isNotEmpty == true ? e!.note : (widget.prefillNote ?? ''));
  }

  @override
  void dispose() {
    _who.dispose();
    _note.dispose();
    super.dispose();
  }

  static String _minorToDigits(int minor) {
    final whole = minor ~/ 100;
    final frac = minor % 100;
    if (frac == 0) return '$whole';
    if (frac % 10 == 0) return '$whole.${frac ~/ 10}';
    return '$whole.${frac.toString().padLeft(2, '0')}';
  }

  int get _minor => Money.parseToMinor(_digits) ?? 0;

  void _key(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      var v = _digits;
      if (k == 'del') {
        if (v.isNotEmpty) v = v.substring(0, v.length - 1);
      } else if (k == '.') {
        if (!v.contains('.')) v = '${v.isEmpty ? '0' : v}.';
      } else {
        final hasTwoDecimals = v.contains('.') && v.split('.')[1].length >= 2;
        final tooLong = v.replaceAll('.', '').length >= 9;
        if (!hasTwoDecimals && !tooLong) v = v == '0' ? k : v + k;
      }
      _digits = v;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _when.isAfter(now) ? now : _when,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _when = DateTime(picked.year, picked.month, picked.day, _when.hour, _when.minute));
    }
  }

  Future<void> _save() async {
    final minor = _minor;
    if (minor <= 0 || _saving) return;
    _saving = true;
    final existing = widget.entry;

    // A new amount or currency is converted at today's rate; an untouched
    // amount keeps the rate it was frozen at.
    final amountChanged = existing == null || existing.amountMinor != minor || existing.currency != _currency;
    final rate = amountChanged ? ref.read(currentRateProvider) : existing.rateUsed;
    final eq = Money.equivalents(minor, _currency, rate);
    final now = DateTime.now();

    final entry = Entry(
      id: existing?.id ?? newId(),
      amountMinor: minor,
      currency: _currency,
      usdMinor: amountChanged ? eq.usd : existing.usdMinor,
      zigMinor: amountChanged ? eq.zig : existing.zigMinor,
      rateUsed: rate,
      direction: _direction,
      categoryId: _categoryId,
      note: _note.text.trim(),
      counterparty: _who.text.trim(),
      occurredAt: _when,
      source: existing?.source ?? EntrySource.manual,
      rawSourceText: existing?.rawSourceText,
      status: existing?.status ?? EntryStatus.confirmed,
      sourceRef: existing?.sourceRef,
      createdAt: existing?.createdAt ?? now,
    );

    // A day that had no leaf yet gets one: say so, it's the small reward for logging.
    final month = MonthRange.of(_when);
    final toneBefore = ref.read(monthTonesProvider(month))?[_when.day];
    final firstForDay = widget.mode == EntrySheetMode.create && (toneBefore == null || toneBefore == DayTone.bud);

    if (widget.mode != EntrySheetMode.review) {
      await ref.read(entryRepositoryProvider).save(entry);
      HapticFeedback.lightImpact();
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final s = ref.read(stringsProvider);
    Navigator.of(context).pop(entry);
    if (firstForDay && !_when.isAfter(now)) {
      final isToday = daysBetween(_when, now) == 0;
      messenger?.showSnackBar(SnackBar(
        content: Text(isToday ? s[K.newLeafToday] : s.f(K.newLeafDay, {'day': s.dayLabel(_when, now)})),
      ));
    }
  }

  /// A past day starts at midday; today keeps the current time.
  static DateTime? _startOf(DateTime? day) {
    if (day == null) return null;
    final now = DateTime.now();
    if (daysBetween(day, now) == 0) return now;
    return DateTime(day.year, day.month, day.day, 12);
  }

  Future<void> _delete() async {
    final e = widget.entry;
    if (e == null) return;
    await ref.read(entryRepositoryProvider).delete(e.id);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final s = ref.read(stringsProvider);
    final repo = ref.read(entryRepositoryProvider);
    Navigator.of(context).pop();
    messenger?.showSnackBar(SnackBar(
      content: Text(s[K.deleted]),
      action: SnackBarAction(label: s[K.undo], onPressed: () => repo.save(e)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    final rate = ref.watch(currentRateProvider);
    final lang = ref.watch(settingsProvider.select((x) => x.language));
    final cats = ref.watch(categoriesProvider).asData?.value ?? const <Category>[];
    final visibleCats = cats
        .where((cat) => _direction == Direction.moneyIn ? cat.kind == CategoryKind.income : cat.kind != CategoryKind.income)
        .toList();

    final minor = _minor;
    final whole = _digits.isEmpty ? '0' : _digits.split('.')[0];
    final groupedWhole = Money.format((int.tryParse(whole.isEmpty ? '0' : whole) ?? 0) * 100, _currency, cents: false, symbol: false);
    final shown = _digits.contains('.') ? '$groupedWhole.${_digits.split('.')[1]}' : groupedWhole;
    final eq = minor > 0
        ? s.f(K.equivalentAtRate, {
            'amount': Money.format(Money.convert(minor, _currency, _currency.other, rate), _currency.other),
            'rate': Money.formatRate(rate),
          })
        : ' ';

    final title = switch (widget.mode) {
      EntrySheetMode.create => s[K.newTransaction],
      EntrySheetMode.edit => s[K.editTransaction],
      EntrySheetMode.review => s[K.editDetails],
    };

    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', 'del'];

    return Column(mainAxisSize: MainAxisSize.min, children: [
      SheetHeader(
        title: title,
        leading: s[K.cancel],
        trailing: widget.mode == EntrySheetMode.review ? s[K.done] : s[K.save],
        onTrailing: minor > 0 ? _save : null,
      ),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Segmented<Direction>(
              values: const [Direction.moneyOut, Direction.moneyIn],
              labelOf: (d) => d == Direction.moneyOut ? s[K.moneyOut] : s[K.moneyIn],
              selected: _direction,
              expand: true,
              large: true,
              onChanged: (d) => setState(() {
                _direction = d;
                final current = cats.where((x) => x.id == _categoryId).toList();
                final fits = current.isNotEmpty &&
                    (d == Direction.moneyIn ? current.first.kind == CategoryKind.income : current.first.kind != CategoryKind.income);
                if (!fits) _categoryId = null;
              }),
            ),
            const SizedBox(height: Space.md),
            Semantics(
              label: s[K.amount],
              value: Money.format(minor, _currency),
              child: Column(children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 10, right: 6),
                      child: Text(_currency.symbol, style: MariType.title2.copyWith(color: c.textSecondary)),
                    ),
                    Text(shown, style: MariType.amountEntry.copyWith(color: _direction == Direction.moneyIn ? c.income : c.textPrimary)),
                  ]),
                ),
                Text(eq, style: MariType.footnote.copyWith(color: c.textTertiary)),
              ]),
            ),
            const SizedBox(height: Space.sm),
            Center(
              child: Segmented<Currency>(
                values: const [Currency.usd, Currency.zig],
                labelOf: (x) => x.symbol,
                selected: _currency,
                onChanged: (x) => setState(() => _currency = x),
              ),
            ),
            const SizedBox(height: Space.md),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: visibleCats.length,
                separatorBuilder: (context, index) => const SizedBox(width: Space.xs),
                itemBuilder: (context, i) {
                  final cat = visibleCats[i];
                  return Pill(
                    label: cat.name(lang),
                    icon: categoryIcon(cat.icon),
                    iconColor: c.tint(categoryTint(cat.id)).ink,
                    selected: cat.id == _categoryId,
                    onTap: () => setState(() => _categoryId = cat.id == _categoryId ? null : cat.id),
                  );
                },
              ),
            ),
            const SizedBox(height: Space.sm),
            Row(children: [
              Expanded(
                child: MariTextField(
                  controller: _who,
                  hint: _direction == Direction.moneyIn ? s[K.fromHint] : s[K.toHint],
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: Space.xs),
              Pill(label: s.shortDay(_when, DateTime.now()), icon: Icons.calendar_today_rounded, onTap: _pickDate),
            ]),
            const SizedBox(height: Space.xs),
            MariTextField(controller: _note, hint: s[K.noteHint], textInputAction: TextInputAction.done),
            const SizedBox(height: Space.sm),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 2.4,
              children: [
                for (final k in keys)
                  Pressable(
                    onTap: () => _key(k),
                    semanticLabel: k == 'del' ? s[K.deleteDigit] : k,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14)),
                      child: k == 'del'
                          ? Icon(Icons.backspace_outlined, size: 22, color: c.textPrimary)
                          : Text(k, style: MariType.title2.copyWith(fontWeight: FontWeight.w500, color: c.textPrimary)),
                    ),
                  ),
              ],
            ),
            if (widget.entry?.rawSourceText != null) ...[
              const SizedBox(height: Space.md),
              Container(
                padding: const EdgeInsets.all(Space.sm),
                decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(14)),
                child: Text(widget.entry!.rawSourceText!, style: MariType.footnote.copyWith(color: c.textSecondary)),
              ),
            ],
            if (widget.mode == EntrySheetMode.edit) ...[
              const SizedBox(height: Space.lg),
              MariButton(label: s[K.deleteTransaction], variant: ButtonVariant.destructive, onPressed: _delete),
            ],
          ]),
        ),
      ),
    ]);
  }
}

/// Today / yesterday / "8 Oct" for the date pill.
extension _ShortDay on Strings {
  String shortDay(DateTime d, DateTime now) {
    final diff = daysBetween(d, now);
    if (diff == 0) return this[K.today];
    if (diff == 1) return this[K.yesterday];
    return '${d.day} ${monthShort(d.month)}';
  }
}
