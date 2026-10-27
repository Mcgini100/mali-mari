import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/money/money.dart';
import '../domain/models.dart';
import 'message_parser.dart';

/// Overridden in main() with the parser built from assets/parser/templates.json.
final messageParserProvider = Provider<MessageParser>((ref) => throw UnimplementedError('messageParserProvider must be overridden'));

final captureServiceProvider = Provider<CaptureService>((ref) {
  final service = CaptureService(ref);
  ref.onDispose(service.dispose);
  return service;
});

enum IngestOutcome { added, duplicate, notTransaction }

class IngestResult {
  const IngestResult(this.outcome, {this.entryId});
  final IngestOutcome outcome;
  final String? entryId;
}

String newId() {
  final rand = Random().nextInt(1 << 31).toRadixString(36);
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}$rand';
}

/// 32-bit FNV-1a, stable across runs and platforms (String.hashCode is not).
String fingerprint(String text) {
  final norm = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  var hash = 0x811c9dc5;
  for (final unit in norm.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// Every route a message can take into Mari ends in [ingest]:
///  * typed or pasted in the app (all platforms)
///  * shared from another app (Android share sheet)
///  * mari://capture?text=… deep link (iOS Shortcuts automation, Android automation apps)
///  * Android notification access, opt-in, filtered natively before anything is kept
/// Each becomes a *pending* entry that the person confirms in Review.
class CaptureService {
  CaptureService(this._ref);

  final Ref _ref;
  static const MethodChannel _channel = MethodChannel('zw.mari/capture');

  final _reviewRequests = StreamController<String>.broadcast();
  StreamSubscription<Uri>? _linkSub;
  bool _started = false;

  /// Entry ids the UI should open in Review (user-initiated captures only).
  Stream<String> get reviewRequests => _reviewRequests.stream;

  bool get supportsNotificationCapture => Platform.isAndroid;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShared' && call.arguments is String) {
        await _ingestUserInitiated(call.arguments as String);
      }
      return null;
    });

    try {
      _linkSub = AppLinks().uriLinkStream.listen(_onUri, onError: (Object _) {});
    } catch (_) {
      // Deep links unavailable (e.g. in tests); capture still works by paste.
    }

    if (Platform.isAndroid) {
      final shared = await _invoke<String>('takeInitialShare');
      if (shared != null && shared.trim().isNotEmpty) await _ingestUserInitiated(shared);
      await syncFilters();
      await drainNotificationQueue();
    }
  }

  void dispose() {
    _linkSub?.cancel();
    _reviewRequests.close();
  }

  Future<T?> _invoke<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> _onUri(Uri uri) async {
    if (uri.scheme != 'mari' || uri.host != 'capture') return;
    final text = uri.queryParameters['text'] ?? uri.queryParameters['t'];
    if (text == null || text.trim().isEmpty) return;
    await _ingestUserInitiated(text);
  }

  Future<void> _ingestUserInitiated(String text) async {
    final r = await ingest(text, source: EntrySource.pasted);
    if (r.entryId != null) _reviewRequests.add(r.entryId!);
  }

  /// Parses [text] and stores it as a pending entry. Low-confidence results
  /// from notifications are dropped (promotions mention amounts too); from a
  /// person's own paste they are kept so they can fix the direction.
  Future<IngestResult> ingest(String text, {required EntrySource source, DateTime? at}) async {
    final parsed = _ref.read(messageParserProvider).parse(text);
    if (parsed == null) return const IngestResult(IngestOutcome.notTransaction);
    if (source == EntrySource.captured && parsed.confidence == ParseConfidence.low) {
      return const IngestResult(IngestOutcome.notTransaction);
    }

    final when = at ?? DateTime.now();
    final repo = _ref.read(entryRepositoryProvider);
    final hasUsableRef = parsed.reference != null && RegExp(r'\d').hasMatch(parsed.reference!);
    final sourceRef = hasUsableRef ? 'ref:${parsed.reference}' : 'h:${fingerprint(text)}';

    if (await repo.hasRecentRef(sourceRef, when)) {
      return const IngestResult(IngestOutcome.duplicate);
    }

    final rate = _ref.read(currentRateProvider);
    final eq = Money.equivalents(parsed.amountMinor, parsed.currency, rate);
    final direction = parsed.direction ?? Direction.moneyOut;
    final categoryId = parsed.categoryId ?? (direction == Direction.moneyIn ? 'income_other' : null);

    final entry = Entry(
      id: newId(),
      amountMinor: parsed.amountMinor,
      currency: parsed.currency,
      usdMinor: eq.usd,
      zigMinor: eq.zig,
      rateUsed: rate,
      direction: direction,
      categoryId: categoryId,
      note: '',
      counterparty: parsed.counterparty ?? '',
      occurredAt: when,
      source: source,
      rawSourceText: text.trim(),
      status: EntryStatus.pendingReview,
      sourceRef: sourceRef,
      createdAt: DateTime.now(),
    );
    await repo.save(entry);
    return IngestResult(IngestOutcome.added, entryId: entry.id);
  }

  // ------------------------------------------------------------ Android notification access

  Future<bool> isListenerEnabled() async => (await _invoke<bool>('isListenerEnabled')) ?? false;

  /// False in the sideload test build, whose manifest leaves the listener out
  /// so Play Protect lets it install.
  Future<bool> isListenerAvailable() async => (await _invoke<bool>('isListenerAvailable')) ?? false;

  Future<void> openListenerSettings() => _invoke<void>('openListenerSettings');

  /// Pushes the person's choices to the native listener, which filters
  /// notifications before anything is stored.
  Future<void> syncFilters() async {
    if (!Platform.isAndroid) return;
    final s = _ref.read(settingsProvider);
    await _invoke<void>('setFilters', {
      'enabled': s.captureEnabled,
      'packages': s.capturePackages,
      'senders': s.captureSenders,
    });
  }

  /// Moves notifications the native listener queued into pending entries.
  Future<int> drainNotificationQueue() async {
    if (!Platform.isAndroid) return 0;
    final items = await _invoke<List<Object?>>('drainQueue');
    if (items == null) return 0;
    var added = 0;
    for (final item in items) {
      if (item is! Map) continue;
      final text = item['text'];
      if (text is! String) continue;
      final postedAt = item['postedAt'];
      final at = postedAt is int ? DateTime.fromMillisecondsSinceEpoch(postedAt) : null;
      final r = await ingest(text, source: EntrySource.captured, at: at);
      if (r.outcome == IngestOutcome.added) added++;
    }
    return added;
  }

  /// Confirms a reviewed entry and, if asked, logs its fees as their own line.
  Future<void> confirm(Entry edited, {int feeMinor = 0}) async {
    final repo = _ref.read(entryRepositoryProvider);
    await repo.save(edited.copyWith(status: EntryStatus.confirmed));
    if (feeMinor > 0) {
      final eq = Money.equivalents(feeMinor, edited.currency, edited.rateUsed);
      await repo.save(Entry(
        id: newId(),
        amountMinor: feeMinor,
        currency: edited.currency,
        usdMinor: eq.usd,
        zigMinor: eq.zig,
        rateUsed: edited.rateUsed,
        direction: Direction.moneyOut,
        categoryId: 'fees',
        note: '',
        counterparty: edited.counterparty,
        occurredAt: edited.occurredAt,
        source: edited.source,
        rawSourceText: null,
        status: EntryStatus.confirmed,
        sourceRef: edited.sourceRef == null ? null : '${edited.sourceRef}:fee',
        createdAt: DateTime.now(),
      ));
    }
  }
}
