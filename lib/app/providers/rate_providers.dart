import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../settings.dart';
import 'data_providers.dart';
import 'settings_providers.dart';
import 'time_providers.dart';

final latestOfficialRateProvider = StreamProvider<RateSnapshot?>((ref) => ref.watch(rateRepositoryProvider).watchLatest());

/// The rate used for new records and for converting budgets: the person's own
/// rate when they chose one, otherwise the latest official rate.
final currentRateProvider = Provider<double>((ref) {
  final manual = ref.watch(settingsProvider.select((s) => s.useManualRate && s.manualRate > 0 ? s.manualRate : null));
  if (manual != null) return manual;
  return ref.watch(latestOfficialRateProvider).asData?.value?.zigPerUsd ?? kFallbackZigPerUsd;
});

class RateController {
  RateController(this.ref);
  final Ref ref;

  /// Fetches the official rate. Returns the rate, or null when offline.
  Future<double?> refresh() async {
    final rate = await ref.read(rateFetcherProvider).fetchZigPerUsd();
    if (rate == null) return null;
    final now = ref.read(clockProvider)();
    await ref.read(rateRepositoryProvider).record(RateSnapshot(zigPerUsd: rate, source: RateSource.official, at: now));
    await ref.read(settingsProvider.notifier).edit((s) => s.copyWith(lastRateFetch: now));
    return rate;
  }

  /// Fetch at most every six hours, so the app costs almost no data.
  Future<void> refreshIfStale() async {
    final last = ref.read(settingsProvider).lastRateFetch;
    if (last != null && ref.read(clockProvider)().difference(last) < const Duration(hours: 6)) return;
    await refresh();
  }
}

final rateControllerProvider = Provider<RateController>((ref) => RateController(ref));
