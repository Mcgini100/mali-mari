import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/clock.dart';
import '../../core/util/dates.dart';

/// The one source of "now". Override it to pin time in tests.
final clockProvider = Provider<Clock>((ref) => systemClock);

/// Today's date (midnight). It rolls over on its own while the app stays
/// open, and [TodayController.refresh] is called when the app resumes, so
/// every month-bound number follows the calendar without a restart.
class TodayController extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    ref.onDispose(() => _timer?.cancel());
    final now = ref.watch(clockProvider)();
    _scheduleRollover(now);
    return dateOnly(now);
  }

  void _scheduleRollover(DateTime now) {
    _timer?.cancel();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _timer = Timer(midnight.difference(now) + const Duration(seconds: 1), refresh);
  }

  void refresh() {
    final now = ref.read(clockProvider)();
    final today = dateOnly(now);
    if (today != state) state = today;
    _scheduleRollover(now);
  }
}

final todayProvider = NotifierProvider<TodayController, DateTime>(TodayController.new);

/// The calendar month today belongs to.
final currentMonthProvider = Provider<MonthRange>((ref) => MonthRange.of(ref.watch(todayProvider)));
