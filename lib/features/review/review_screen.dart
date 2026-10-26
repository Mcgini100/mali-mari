import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../capture/capture_service.dart';
import '../../capture/message_parser.dart';
import '../../core/l10n/strings.dart';
import '../../core/money/money.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../domain/models.dart';
import '../../widgets/entry_tile.dart';
import '../../widgets/primitives.dart';
import '../entry/category_picker.dart';
import '../entry/entry_sheet.dart';

/// Captured and pasted messages wait here. Nothing counts until confirmed.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, this.focusEntryId});

  /// Show this pending entry first (e.g. the one just shared to Mari).
  final String? focusEntryId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  String? _focusId;
  final _feeOff = <String>{};
  final _paste = TextEditingController();
  bool _notTransaction = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _focusId = widget.focusEntryId;
  }

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) {
      setState(() {
        _paste.text = text;
        _notTransaction = false;
      });
    }
  }

  Future<void> _read() async {
    final text = _paste.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    final s = ref.read(stringsProvider);
    final result = await ref.read(captureServiceProvider).ingest(text, source: EntrySource.pasted);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _notTransaction = result.outcome == IngestOutcome.notTransaction;
      if (result.outcome == IngestOutcome.added) {
        _focusId = result.entryId;
        _paste.clear();
      }
    });
    if (result.outcome == IngestOutcome.duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s[K.alreadyInMari])));
    }
  }

  Future<void> _confirm(Entry e, int feeMinor) async {
    HapticFeedback.lightImpact();
    await ref.read(captureServiceProvider).confirm(e, feeMinor: _feeOff.contains(e.id) ? 0 : feeMinor);
    if (!mounted) return;
    final s = ref.read(stringsProvider);
    setState(() => _focusId = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s[K.addedToMonth])));
  }

  Future<void> _discard(Entry e) async {
    final repo = ref.read(entryRepositoryProvider);
    await repo.delete(e.id);
    if (!mounted) return;
    final s = ref.read(stringsProvider);
    setState(() => _focusId = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(s[K.discarded]),
      action: SnackBarAction(label: s[K.undo], onPressed: () => repo.save(e)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    final pending = ref.watch(pendingEntriesProvider).asData?.value ?? const <Entry>[];
    final focusIndex = pending.indexWhere((e) => e.id == _focusId);
    final current = pending.isEmpty ? null : pending[focusIndex >= 0 ? focusIndex : 0];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: c.accent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
        children: [
          Text(s[K.review], style: MariType.title1.copyWith(color: c.textPrimary)),
          const SizedBox(height: Space.xxs),
          Text(s[K.reviewIntro], style: MariType.callout.copyWith(color: c.textSecondary)),
          const SizedBox(height: 18),
          if (current == null)
            MariCard(child: EmptyState(icon: Icons.task_alt_rounded, title: s[K.allCaughtUp], body: s[K.allCaughtUpBody]))
          else ...[
            _ReviewCard(
              key: ValueKey(current.id),
              entry: current,
              feeOn: !_feeOff.contains(current.id),
              onFeeChanged: (on) => setState(() => on ? _feeOff.remove(current.id) : _feeOff.add(current.id)),
              onConfirm: (fee) => _confirm(current, fee),
              onDiscard: () => _discard(current),
            ),
            if (pending.length > 1) ...[
              const SizedBox(height: 14),
              _Pager(count: pending.length, index: pending.indexOf(current), onSelect: (i) => setState(() => _focusId = pending[i].id)),
            ],
          ],
          const SizedBox(height: Space.xl),
          SectionHeader(title: s[K.pasteAMessage]),
          Text(s[K.pasteIntro], style: MariType.footnote.copyWith(color: c.textSecondary)),
          const SizedBox(height: 10),
          MariTextField(
            controller: _paste,
            hint: s[K.pasteHint],
            maxLines: 5,
            minLines: 3,
            keyboardType: TextInputType.multiline,
            style: MariType.callout.copyWith(color: c.textPrimary),
            onChanged: (_) {
              if (_notTransaction) setState(() => _notTransaction = false);
            },
          ),
          const SizedBox(height: 10),
          Row(children: [
            MariButton(
              label: s[K.pasteFromClipboard],
              icon: Icons.content_paste_rounded,
              variant: ButtonVariant.secondary,
              small: true,
              expand: false,
              onPressed: _pasteFromClipboard,
            ),
            const Spacer(),
            MariButton(label: s[K.readMessage], small: true, expand: false, onPressed: _busy ? null : _read),
          ]),
          if (_notTransaction) ...[
            const SizedBox(height: 14),
            MariCard(
              padding: const EdgeInsets.all(Space.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Badge(confidence: null, s: s),
                const SizedBox(height: 10),
                Text(s[K.notATransactionBody], style: MariType.callout.copyWith(color: c.textPrimary)),
                const SizedBox(height: Space.sm),
                MariButton(
                  label: s[K.enterManually],
                  variant: ButtonVariant.secondary,
                  small: true,
                  expand: false,
                  onPressed: () => showEntrySheet(context, prefillNote: _paste.text.trim()),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({
    super.key,
    required this.entry,
    required this.feeOn,
    required this.onFeeChanged,
    required this.onConfirm,
    required this.onDiscard,
  });

  final Entry entry;
  final bool feeOn;
  final ValueChanged<bool> onFeeChanged;
  final ValueChanged<int> onConfirm;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(settingsProvider.select((x) => x.language));
    final cats = ref.watch(categoryMapProvider);
    final repo = ref.read(entryRepositoryProvider);
    final parsed = ref.watch(messageParserProvider).parse(entry.rawSourceText);
    final isIn = entry.direction == Direction.moneyIn;
    final fee = parsed?.feeMinor ?? 0;
    final directionUnclear = parsed?.direction == null && parsed != null;

    Widget kv(String k, Widget v, {VoidCallback? onTap}) {
      final row = Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
        child: Row(children: [
          Text(k, style: MariType.callout.copyWith(color: c.textSecondary)),
          const SizedBox(width: Space.sm),
          Expanded(child: Align(alignment: Alignment.centerRight, child: v)),
        ]),
      );
      return onTap == null ? row : Pressable(onTap: onTap, child: row);
    }

    TextStyle valueStyle([Color? color]) => MariType.subhead.copyWith(color: color ?? c.textPrimary);

    return MariCard(
      padding: const EdgeInsets.all(Space.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // The original message, amount highlighted, so the reading can be checked at a glance.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Space.sm),
          decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(sourceIcon(entry.source), size: 15, color: c.textSecondary),
              const SizedBox(width: 6),
              Text('${sourceLabel(s, entry.source)} · ${s.time(entry.occurredAt)}',
                  style: MariType.footnote.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: c.textSecondary)),
            ]),
            const SizedBox(height: 6),
            _Highlighted(text: entry.rawSourceText ?? '', amountMinor: entry.amountMinor),
          ]),
        ),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerLeft, child: _Badge(confidence: parsed?.confidence ?? ParseConfidence.high, s: s)),
        const SizedBox(height: 14),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(Money.format(entry.amountMinor, entry.currency, signed: isIn),
                style: MariType.display.copyWith(color: isIn ? c.income : c.textPrimary)),
          ),
        ),
        Center(
          child: Text(
            s.f(K.equivalentAtRate, {
              'amount': Money.format(entry.amountIn(entry.currency.other), entry.currency.other),
              'rate': Money.formatRate(entry.rateUsed),
            }),
            style: MariType.footnote.copyWith(color: c.textTertiary),
          ),
        ),
        const SizedBox(height: Space.md),
        MariCard(
          outlined: true,
          child: SeparatedColumn(children: [
            kv(
              s[K.type],
              // When the message didn't say, the person checks it here: one tap flips it.
              Text(
                directionUnclear
                    ? '${isIn ? s[K.moneyIn] : s[K.moneyOut]} · ${s[K.chooseInOrOut].toLowerCase()}'
                    : (isIn ? s[K.moneyIn] : s[K.moneyOut]),
                style: valueStyle(directionUnclear ? c.spend : c.accent),
              ),
              onTap: () => repo.save(entry.copyWith(direction: isIn ? Direction.moneyOut : Direction.moneyIn, clearCategory: true)),
            ),
            kv(isIn ? s[K.from] : s[K.to],
                Text(entry.counterparty.isEmpty ? '—' : entry.counterparty,
                    textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis, style: valueStyle())),
            kv(
              s[K.category],
              Text(cats[entry.categoryId]?.name(lang) ?? s[K.choose], style: valueStyle(c.accent)),
              onTap: () async {
                final id = await pickCategory(context, direction: entry.direction, selected: entry.categoryId);
                if (id != null) await repo.save(entry.copyWith(categoryId: id));
              },
            ),
            if (parsed?.reference != null)
              kv(s[K.reference],
                  Text(parsed!.reference!, maxLines: 1, overflow: TextOverflow.ellipsis, style: MariType.footnote.copyWith(color: c.textPrimary))),
            if (fee > 0)
              kv(
                s.f(K.logFeesSeparately, {'amount': Money.format(fee, entry.currency)}),
                MariSwitch(value: feeOn, onChanged: onFeeChanged),
              ),
          ]),
        ),
        const SizedBox(height: Space.xs),
        Center(
          child: Pressable(
            onTap: () async {
              final edited = await showEntrySheet(context, entry: entry, mode: EntrySheetMode.review);
              if (edited != null) await repo.save(edited);
            },
            child: Padding(
              padding: const EdgeInsets.all(Space.xs),
              child: Text(s[K.editDetails], style: MariType.callout.copyWith(color: c.accent)),
            ),
          ),
        ),
        const SizedBox(height: Space.xs),
        Row(children: [
          Expanded(child: MariButton(label: s[K.discard], variant: ButtonVariant.secondary, onPressed: onDiscard)),
          const SizedBox(width: Space.xs),
          Expanded(
            flex: 2,
            child: MariButton(label: s[K.confirm], onPressed: () => onConfirm(fee)),
          ),
        ]),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.confidence, required this.s});
  final ParseConfidence? confidence;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (IconData icon, String label, Color fg, Color bg) = switch (confidence) {
      ParseConfidence.high => (Icons.verified_rounded, s[K.confidenceHigh], c.income, c.incomeSoft),
      ParseConfidence.medium => (Icons.help_rounded, s[K.confidenceMedium], c.warning, c.warningSoft),
      ParseConfidence.low => (Icons.warning_rounded, s[K.confidenceLow], c.spend, c.spendSoft),
      null => (Icons.help_outline_rounded, s[K.notATransaction], c.spend, c.spendSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 4),
        Text(label, style: MariType.footnote.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
      ]),
    );
  }
}

/// The source message with the parsed amount marked.
class _Highlighted extends StatelessWidget {
  const _Highlighted({required this.text, required this.amountMinor});
  final String text;
  final int amountMinor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = MariType.callout.copyWith(fontSize: 14, height: 20 / 14, color: c.textPrimary);
    final whole = (amountMinor ~/ 100).toString();
    final buf = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',?');
      buf.write(whole[i]);
    }
    final re = RegExp('(?:ZiG|ZWG|USD|US\\\$|\\\$)\\s?$buf(?:\\.\\d{1,2})?(?!\\d)', caseSensitive: false);
    final m = re.firstMatch(text);
    if (m == null) return Text(text, style: base);
    return Text.rich(TextSpan(style: base, children: [
      TextSpan(text: text.substring(0, m.start)),
      TextSpan(
        text: text.substring(m.start, m.end),
        style: TextStyle(backgroundColor: c.accent.withValues(alpha: 0.22), fontWeight: FontWeight.w600),
      ),
      TextSpan(text: text.substring(m.end)),
    ]));
  }
}

class _Pager extends StatelessWidget {
  const _Pager({required this.count, required this.index, required this.onSelect});
  final int count;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (var i = 0; i < count; i++)
        GestureDetector(
          onTap: () => onSelect(i),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: i == index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(color: i == index ? c.textPrimary : c.separator, borderRadius: BorderRadius.circular(9)),
            ),
          ),
        ),
    ]);
  }
}
