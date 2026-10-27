import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../capture/capture_service.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sheet.dart';
import '../budgets/budgets_screen.dart';
import '../entry/entry_sheet.dart';
import '../history/history_screen.dart';
import '../home/home_screen.dart';
import '../insights/insights_screen.dart';
import '../review/review_screen.dart';

/// Four tabs and a central add button. Also the place where background
/// work hooks into the app lifecycle: draining captured alerts and keeping
/// the exchange rate fresh.
class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});

  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> with WidgetsBindingObserver {
  int _tab = 0;
  StreamSubscription<String>? _reviewSub;
  Timer? _drainTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final capture = ref.read(captureServiceProvider);
    _reviewSub = capture.reviewRequests.listen(_openReview);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await capture.start();
      unawaited(ref.read(rateControllerProvider).refreshIfStale());
      _startDrainTimer();
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
      // A new day may have started; month-bound providers re-read "now".
      ref.invalidate(currentMonthProvider);
      ref.read(captureServiceProvider).drainNotificationQueue();
      ref.read(rateControllerProvider).refreshIfStale();
      _startDrainTimer();
    } else if (state == AppLifecycleState.paused) {
      _drainTimer?.cancel();
    }
  }

  /// While Mari is open, alerts that arrive are picked up within a few seconds.
  void _startDrainTimer() {
    _drainTimer?.cancel();
    final capture = ref.read(captureServiceProvider);
    if (!capture.supportsNotificationCapture || !ref.read(settingsProvider).captureEnabled) return;
    _drainTimer = Timer.periodic(const Duration(seconds: 5), (_) => capture.drainNotificationQueue());
  }

  void _openReview(String entryId) {
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReviewScreen(focusEntryId: entryId)));
  }

  void _select(int i) {
    if (i == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);
    ref.listen(settingsProvider.select((x) => x.captureEnabled), (previous, next) => _startDrainTimer());

    final pages = [
      HomeScreen(onOpenTab: _select),
      const HistoryScreen(),
      const BudgetsScreen(),
      const InsightsScreen(),
    ];

    Widget tab(int i, IconData icon, IconData activeIcon, String label) {
      final active = _tab == i;
      return Expanded(
        child: Semantics(
          selected: active,
          button: true,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _select(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(active ? activeIcon : icon, size: 24, color: active ? c.accent : c.textTertiary),
                const SizedBox(height: 2),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MariType.caption.copyWith(
                      fontSize: 10,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w500,
                      color: active ? c.accent : c.textTertiary,
                    )),
              ]),
            ),
          ),
        ),
      );
    }

    final addButton = Expanded(
      child: Center(
        child: Semantics(
          button: true,
          label: s[K.newTransaction],
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              showEntrySheet(context);
            },
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: c.accent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Icon(Icons.add_rounded, size: 28, color: c.onAccent),
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: DepthScaler(
        child: Scaffold(
          backgroundColor: c.background,
          extendBody: false,
          // Only the visible tab animates: the tree stops swaying when you're elsewhere.
          body: SafeArea(
            bottom: false,
            child: IndexedStack(index: _tab, children: [
              for (var i = 0; i < pages.length; i++) TickerMode(enabled: i == _tab, child: pages[i]),
            ]),
          ),
          bottomNavigationBar: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: c.background.withValues(alpha: 0.88),
                  border: Border(top: BorderSide(color: c.separator, width: 0.5)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                    child: Row(children: [
                      tab(0, Icons.park_outlined, Icons.park_rounded, s[K.home]),
                      tab(1, Icons.receipt_long_outlined, Icons.receipt_long_rounded, s[K.history]),
                      addButton,
                      tab(2, Icons.pie_chart_outline_rounded, Icons.pie_chart_rounded, s[K.budgets]),
                      tab(3, Icons.insights_outlined, Icons.insights_rounded, s[K.insights]),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
