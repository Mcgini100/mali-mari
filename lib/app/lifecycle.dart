import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../capture/capture_service.dart';
import 'providers.dart';

/// The work Mari does around the screens: starting capture, picking up alerts
/// that arrive while the app is open, keeping the exchange rate fresh and
/// noticing that a new day has started. It lives here, not in a screen, so
/// navigation widgets only navigate.
class AppLifecycle extends ConsumerStatefulWidget {
  const AppLifecycle({super.key, required this.child, this.onReviewRequest});

  final Widget child;

  /// Called with an entry id when the person hands Mari a message (share
  /// sheet, deep link) and it should open in Review.
  final ValueChanged<String>? onReviewRequest;

  /// While Mari is open, alerts that arrive are picked up within this long.
  static const Duration drainInterval = Duration(seconds: 5);

  @override
  ConsumerState<AppLifecycle> createState() => _AppLifecycleState();
}

class _AppLifecycleState extends ConsumerState<AppLifecycle> with WidgetsBindingObserver {
  StreamSubscription<String>? _reviewSub;
  Timer? _drainTimer;

  CaptureService get _capture => ref.read(captureServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reviewSub = _capture.reviewRequests.listen((id) {
      if (mounted) widget.onReviewRequest?.call(id);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _capture.start();
      if (!mounted) return;
      unawaited(ref.read(rateControllerProvider).refreshIfStale());
      _syncDrainTimer();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reviewSub?.cancel();
    _drainTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(todayProvider.notifier).refresh();
      unawaited(_capture.drainNotificationQueue());
      unawaited(ref.read(rateControllerProvider).refreshIfStale());
      _syncDrainTimer();
    } else if (state == AppLifecycleState.paused) {
      _drainTimer?.cancel();
      _drainTimer = null;
    }
  }

  void _syncDrainTimer() {
    _drainTimer?.cancel();
    _drainTimer = null;
    final capture = _capture;
    if (!capture.supportsNotificationCapture || !ref.read(settingsProvider).captureEnabled) return;
    _drainTimer = Timer.periodic(AppLifecycle.drainInterval, (_) => capture.drainNotificationQueue());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider.select((s) => s.captureEnabled), (previous, next) => _syncDrainTimer());
    return widget.child;
  }
}
