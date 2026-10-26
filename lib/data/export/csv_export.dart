import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/money/money.dart';
import '../../domain/models.dart';

String _cell(String v) {
  if (v.contains(',') || v.contains('"') || v.contains('\n')) return '"${v.replaceAll('"', '""')}"';
  return v;
}

String _two(int n) => n.toString().padLeft(2, '0');

String _stamp(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

/// Every confirmed transaction as CSV, one row each, amounts as they happened
/// plus both frozen equivalents and the rate used.
String entriesToCsv(List<Entry> entries, Map<String, Category> categories) {
  final b = StringBuffer()
    ..writeln('date,direction,amount,currency,usd_equivalent,zig_equivalent,zig_per_usd,category,counterparty,note,source');
  for (final e in entries) {
    b.writeln([
      _stamp(e.occurredAt),
      e.direction == Direction.moneyIn ? 'in' : 'out',
      Money.plain(e.amountMinor),
      e.currency.code,
      Money.plain(e.usdMinor),
      Money.plain(e.zigMinor),
      e.rateUsed.toStringAsFixed(4),
      _cell(categories[e.categoryId]?.nameEn ?? ''),
      _cell(e.counterparty),
      _cell(e.note),
      e.source.name,
    ].join(','));
  }
  return b.toString();
}

/// Writes the CSV to a temporary file and opens the system share sheet.
Future<void> shareCsv(List<Entry> entries, Map<String, Category> categories) async {
  final dir = await getTemporaryDirectory();
  final now = DateTime.now();
  final file = File('${dir.path}/mari-${now.year}-${_two(now.month)}-${_two(now.day)}.csv');
  await file.writeAsString(entriesToCsv(entries, categories));
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'text/csv')], subject: 'Mari export'));
}
