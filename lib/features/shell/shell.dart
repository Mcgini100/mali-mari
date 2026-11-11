import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/lifecycle.dart';
import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/sheet.dart';
import '../budgets/budgets_screen.dart';
import '../entry/entry_sheet.dart';
import '../history/history_screen.dart';
import '../home/home_screen.dart';
import '../insights/insights_screen.dart';
import '../review/review_screen.dart';

/// Four tabs and a central add button. Navigation only: the background work
/// (capture, rate refresh, day rollover) lives in [AppLifecycle].
class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});

  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> {
  int _tab = 0;

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

    final pages = [
      HomeScreen(onOpenTab: _select),
      const HistoryScreen(),
      const BudgetsScreen(),
      const InsightsScreen(),
    ];

    return AppLifecycle(
      onReviewRequest: _openReview,
      child: Scaffold(
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
            bottomNavigationBar: MariTabBar(
              index: _tab,
              onSelect: _select,
              onAdd: () {
                HapticFeedback.mediumImpact();
                showEntrySheet(context);
              },
              addLabel: s[K.newTransaction],
              tabs: [
                MariTab(Icons.park_outlined, Icons.park_rounded, s[K.home]),
                MariTab(Icons.receipt_long_outlined, Icons.receipt_long_rounded, s[K.history]),
                MariTab(Icons.pie_chart_outline_rounded, Icons.pie_chart_rounded, s[K.budgets]),
                MariTab(Icons.insights_outlined, Icons.insights_rounded, s[K.insights]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MariTab {
  const MariTab(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// The bottom bar: two tabs, the add button, two tabs. Every tab is at least
/// [Space.tapTarget] tall, and the resting colour is the secondary ink, which
/// stays readable on the blurred bar in both themes.
class MariTabBar extends StatelessWidget {
  const MariTabBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onSelect,
    required this.onAdd,
    required this.addLabel,
  }) : assert(tabs.length == 4);

  final List<MariTab> tabs;
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget tab(int i) {
      final t = tabs[i];
      final active = index == i;
      final color = active ? c.accent : c.textSecondary;
      return Expanded(
        child: Semantics(
          selected: active,
          button: true,
          label: t.label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(i),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Space.tapTarget),
              child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(active ? t.activeIcon : t.icon, size: 24, color: color),
                const SizedBox(height: 2),
                ExcludeSemantics(
                  child: Text(
                    t.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MariType.tab.copyWith(color: color, fontWeight: active ? FontWeight.w600 : FontWeight.w500),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    final add = Expanded(
      // heightFactor: 1 keeps the bar as tall as its content; a plain Center
      // grows to all the height offered and pushes the bar over the page.
      child: Center(
        heightFactor: 1,
        child: Semantics(
          button: true,
          label: addLabel,
          child: GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: c.accent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Icon(Icons.add_rounded, size: 28, color: c.onAccent),
            ),
          ),
        ),
      ),
    );

    return ClipRect(
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
              child: Row(children: [tab(0), tab(1), add, tab(2), tab(3)]),
            ),
          ),
        ),
      ),
    );
  }
}
