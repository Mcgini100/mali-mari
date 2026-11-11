import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/money/money.dart';
import '../settings.dart';
import 'data_providers.dart';

/// Overridden in main() with settings read before the first frame.
final initialSettingsProvider = Provider<AppSettings>((ref) => const AppSettings());

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  /// Applies [change] at once, then saves only the keys that moved, in one
  /// batch. (Rewriting every key on every toggle cost eleven writes a tap.)
  Future<void> edit(AppSettings Function(AppSettings s) change) async {
    final before = state.toStore();
    final next = change(state);
    state = next;
    final after = next.toStore();
    final changed = {
      for (final e in after.entries)
        if (before[e.key] != e.value) e.key: e.value,
    };
    if (changed.isEmpty) return;
    await ref.read(settingsStoreProvider).writeAll(changed);
  }

  /// After "delete all my data": back to defaults, onboarding shows again.
  void resetInMemory() => state = const AppSettings();
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

final stringsProvider = Provider<Strings>((ref) => Strings(ref.watch(settingsProvider.select((s) => s.language))));

final displayCurrencyProvider = Provider<Currency>((ref) => ref.watch(settingsProvider.select((s) => s.displayCurrency)));
