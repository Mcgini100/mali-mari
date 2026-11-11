import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mari/app/providers.dart';
import 'package:mari/core/util/dates.dart';

void main() {
  test('today and the current month follow the injected clock', () {
    var now = DateTime(2026, 10, 31, 23, 30);
    final container = ProviderContainer(overrides: [clockProvider.overrideWithValue(() => now)]);
    addTearDown(container.dispose);

    expect(container.read(todayProvider), DateTime(2026, 10, 31));
    expect(container.read(currentMonthProvider), const MonthRange(2026, 10));

    // Midnight passes while the app is in the background; resuming refreshes.
    now = DateTime(2026, 11, 1, 0, 5);
    container.read(todayProvider.notifier).refresh();
    expect(container.read(todayProvider), DateTime(2026, 11, 1));
    expect(container.read(currentMonthProvider), const MonthRange(2026, 11));
  });

  test('refreshing on the same day changes nothing', () {
    final container = ProviderContainer(overrides: [clockProvider.overrideWithValue(() => DateTime(2026, 10, 9, 8))]);
    addTearDown(container.dispose);
    var notified = 0;
    container.listen(todayProvider, (previous, next) => notified++);
    container.read(todayProvider.notifier).refresh();
    expect(notified, 0);
  });
}
