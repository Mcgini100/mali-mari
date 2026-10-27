import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/money/money.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/dates.dart';
import '../../domain/models.dart';
import '../../widgets/entry_tile.dart';
import '../../widgets/primitives.dart';
import '../budgets/budgets_screen.dart';
import '../entry/category_picker.dart';
import '../entry/entry_sheet.dart';
import '../tree/month_tree_view.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _search = TextEditingController();
  Currency? _currency;
  EntrySource? _source;
  String? _categoryId;
  DateTimeRange? _range;
  final _hidden = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _anyFilter => _currency != null || _source != null || _categoryId != null || _range != null;

  void _clear() => setState(() {
        _currency = null;
        _source = null;
        _categoryId = null;
        _range = null;
      });

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _range ?? DateTimeRange(start: MonthRange.of(now).start, end: now),
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _pickCategory() async {
    final id = await pickCategory(context, direction: Direction.moneyOut, selected: _categoryId);
    if (id != null) setState(() => _categoryId = id == _categoryId ? null : id);
  }

  void _delete(Entry e) {
    final repo = ref.read(entryRepositoryProvider);
    final s = ref.read(stringsProvider);
    // Hide at once: a dismissed row must leave the tree before the database stream catches up.
    setState(() => _hidden.add(e.id));
    repo.delete(e.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(s[K.deleted]),
      action: SnackBarAction(
        label: s[K.undo],
        onPressed: () async {
          await repo.save(e);
          if (mounted) setState(() => _hidden.remove(e.id));
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(settingsProvider.select((x) => x.language));
    final display = ref.watch(displayCurrencyProvider);
    final cats = ref.watch(categoryMapProvider);
    final all = ref.watch(allEntriesProvider).asData?.value;
    final q = _search.text.trim().toLowerCase();

    final filtered = (all ?? const <Entry>[]).where((e) {
      if (_hidden.contains(e.id)) return false;
      if (_currency != null && e.currency != _currency) return false;
      if (_source != null && e.source != _source) return false;
      if (_categoryId != null && e.categoryId != _categoryId) return false;
      if (_range != null) {
        final d = dateOnly(e.occurredAt);
        if (d.isBefore(dateOnly(_range!.start)) || d.isAfter(dateOnly(_range!.end))) return false;
      }
      if (q.isNotEmpty) {
        final hay = '${e.counterparty} ${e.note} ${cats[e.categoryId]?.name(lang) ?? ''} ${cats[e.categoryId]?.nameEn ?? ''}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    // Group by calendar day, newest first (the stream is already sorted).
    final groups = <DateTime, List<Entry>>{};
    for (final e in filtered) {
      groups.putIfAbsent(dateOnly(e.occurredAt), () => []).add(e);
    }
    final now = DateTime.now();

    final children = <Widget>[
      ScreenTitle(title: s[K.history], trailing: const CurrencySwitch()),
      MariTextField(
        controller: _search,
        hint: s[K.searchHint],
        prefixIcon: Icons.search_rounded,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
      ),
      const SizedBox(height: Space.sm),
      SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Pill(label: s[K.all], selected: !_anyFilter, onTap: _clear),
            const SizedBox(width: Space.xs),
            for (final cur in Currency.values) ...[
              Pill(label: cur.symbol, selected: _currency == cur, onTap: () => setState(() => _currency = _currency == cur ? null : cur)),
              const SizedBox(width: Space.xs),
            ],
            for (final src in EntrySource.values) ...[
              Pill(
                label: sourceLabel(s, src),
                icon: sourceIcon(src),
                selected: _source == src,
                onTap: () => setState(() => _source = _source == src ? null : src),
              ),
              const SizedBox(width: Space.xs),
            ],
            Pill(
              label: _categoryId == null ? s[K.category] : (cats[_categoryId]?.name(lang) ?? s[K.category]),
              icon: Icons.category_rounded,
              selected: _categoryId != null,
              onTap: _pickCategory,
            ),
            const SizedBox(width: Space.xs),
            Pill(
              label: _range == null
                  ? s[K.dates]
                  : '${_range!.start.day} ${s.monthShort(_range!.start.month)} – ${_range!.end.day} ${s.monthShort(_range!.end.month)}',
              icon: Icons.date_range_rounded,
              selected: _range != null,
              onTap: _pickRange,
            ),
          ],
        ),
      ),
      const SizedBox(height: Space.lg),
    ];

    if (all != null && filtered.isEmpty) {
      children.add(EmptyState(
        icon: all.isEmpty ? Icons.receipt_long_rounded : Icons.search_off_rounded,
        title: all.isEmpty ? s[K.noEntriesTitle] : s[K.nothingMatches],
        body: all.isEmpty ? s[K.noEntriesBody] : s[K.nothingMatchesBody],
      ));
    }

    for (final day in groups.keys) {
      final items = groups[day]!;
      var dayOut = 0;
      for (final e in items) {
        final kind = cats[e.categoryId]?.kind ?? CategoryKind.expense;
        if (e.direction == Direction.moneyOut && kind == CategoryKind.expense) dayOut += e.amountIn(display);
      }
      final tone = ref.watch(monthTonesProvider(MonthRange.of(day)))?[day.day];
      children.add(SectionHeader(
        title: s.dayLabel(day, now),
        caption: true,
        // The day's leaf colour, so scrolling back reads like the tree unrolled.
        leading: tone == null
            ? null
            : Container(
                width: 9,
                height: 7,
                decoration: BoxDecoration(color: toneColor(tone, c), borderRadius: BorderRadius.circular(9)),
              ),
        trailing: dayOut > 0
            ? Text('−${Money.format(dayOut, display)}', style: MariType.footnote.copyWith(color: c.textSecondary))
            : null,
      ));
      children.add(MariCard(
        child: SeparatedColumn(children: [
          for (final e in items)
            Dismissible(
              key: ValueKey(e.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: c.spend,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: Space.lg),
                child: const Icon(Icons.delete_rounded, color: Colors.white),
              ),
              onDismissed: (_) => _delete(e),
              child: EntryTile(entry: e, onTap: () => showEntrySheet(context, entry: e, mode: EntrySheetMode.edit)),
            ),
        ]),
      ));
      children.add(const SizedBox(height: Space.lg));
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
      children: children,
    );
  }
}
