import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../capture/capture_service.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/primitives.dart';

/// Shown before Android's own permission screen. Says exactly what Mari reads
/// and what it never does, and lets the person choose apps and senders.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _SourceOption {
  const _SourceOption(this.key, this.packages, this.icon);
  final K key;
  final List<String> packages;
  final IconData icon;
}

const _sources = [
  _SourceOption(K.sourceEcocashApp, CaptureDefaults.ecocashPackages, Icons.smartphone_rounded),
  _SourceOption(K.sourceGoogleMessages, [CaptureDefaults.googleMessages], Icons.sms_rounded),
  _SourceOption(K.sourceSamsungMessages, [CaptureDefaults.samsungMessages], Icons.sms_rounded),
];

class _ConsentScreenState extends ConsumerState<ConsentScreen> with WidgetsBindingObserver {
  late Set<String> _packages;
  late List<String> _senders;
  bool _granted = false;
  bool _waitingForSettings = false;

  @override
  void initState() {
    super.initState();
    final st = ref.read(settingsProvider);
    _packages = st.capturePackages.toSet();
    _senders = [...st.captureSenders];
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(closeIfGranted: _waitingForSettings);
  }

  Future<void> _check({bool closeIfGranted = false}) async {
    final on = await ref.read(captureServiceProvider).isListenerEnabled();
    if (!mounted) return;
    setState(() => _granted = on);
    if (on && closeIfGranted) {
      final s = ref.read(stringsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s[K.captureTurnedOn])));
      Navigator.of(context).pop();
    }
  }

  bool _sourceOn(_SourceOption o) => o.packages.any(_packages.contains);

  void _toggleSource(_SourceOption o, bool on) => setState(() {
        if (on) {
          _packages.addAll(o.packages);
        } else {
          _packages.removeAll(o.packages);
        }
      });

  Future<void> _addSender() async {
    final s = ref.read(stringsProvider);
    final c = context.colors;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(s[K.addSender], style: MariType.headline.copyWith(color: c.textPrimary)),
        content: MariTextField(controller: controller, hint: s[K.addSenderHint], autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(s[K.cancel], style: TextStyle(color: c.accent))),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(s[K.add], style: TextStyle(color: c.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty && !_senders.any((x) => x.toLowerCase() == name.toLowerCase())) {
      setState(() => _senders.add(name));
    }
  }

  Future<void> _continue() async {
    await ref.read(settingsProvider.notifier).edit((st) => st.copyWith(
          captureEnabled: true,
          capturePackages: _packages.toList(),
          captureSenders: _senders,
        ));
    final svc = ref.read(captureServiceProvider);
    await svc.syncFilters();
    if (_granted) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _waitingForSettings = true;
    await svc.openListenerSettings();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = ref.watch(stringsProvider);

    Widget promise(IconData icon, Color color, String text) => Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: Space.sm),
            Expanded(child: Text(text, style: MariType.callout.copyWith(color: c.textPrimary))),
          ]),
        );

    return Scaffold(
      appBar: AppBar(backgroundColor: c.background, surfaceTintColor: Colors.transparent, scrolledUnderElevation: 0, foregroundColor: c.accent),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
        children: [
          Text(s[K.consentTitle], style: MariType.title1.copyWith(color: c.textPrimary)),
          const SizedBox(height: Space.xs),
          Text(s[K.consentIntro], style: MariType.callout.copyWith(color: c.textSecondary)),
          const SizedBox(height: Space.lg),
          MariCard(
            padding: const EdgeInsets.all(Space.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s[K.consentReads].toUpperCase(), style: MariType.caption.copyWith(color: c.income)),
              promise(Icons.check_circle_rounded, c.income, s[K.consentReads1]),
              promise(Icons.check_circle_rounded, c.income, s[K.consentReads2]),
            ]),
          ),
          const SizedBox(height: Space.sm),
          MariCard(
            padding: const EdgeInsets.all(Space.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s[K.consentNever].toUpperCase(), style: MariType.caption.copyWith(color: c.spend)),
              promise(Icons.block_rounded, c.spend, s[K.consentNever1]),
              promise(Icons.block_rounded, c.spend, s[K.consentNever2]),
              promise(Icons.block_rounded, c.spend, s[K.consentNever3]),
            ]),
          ),
          const SizedBox(height: Space.lg),
          SectionHeader(title: s[K.readAlertsFrom], caption: true),
          MariCard(
            child: SeparatedColumn(children: [
              for (final o in _sources)
                MariListTile(
                  icon: o.icon,
                  title: s[o.key],
                  trailing: MariSwitch(value: _sourceOn(o), onChanged: (v) => _toggleSource(o, v)),
                ),
            ]),
          ),
          const SizedBox(height: Space.lg),
          SectionHeader(title: s[K.textsFromSenders], caption: true),
          Text(s[K.textsFromSendersBody], style: MariType.footnote.copyWith(color: c.textSecondary)),
          const SizedBox(height: 10),
          Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
            for (final name in _senders)
              Pill(
                label: name,
                icon: Icons.close_rounded,
                onTap: () => setState(() => _senders.remove(name)),
              ),
            Pill(label: s[K.add], icon: Icons.add_rounded, color: c.accent, onTap: _addSender),
          ]),
          const SizedBox(height: Space.xl),
          if (_granted)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Row(children: [
                Icon(Icons.verified_rounded, size: 18, color: c.income),
                const SizedBox(width: 6),
                Expanded(child: Text(s[K.permissionGranted], style: MariType.footnote.copyWith(color: c.income))),
              ]),
            ),
          MariButton(
            label: _granted ? s[K.saveChoices] : s[K.continueToSettings],
            onPressed: _packages.isEmpty ? null : _continue,
          ),
          const SizedBox(height: 6),
          MariButton(label: s[K.notNow], variant: ButtonVariant.ghost, onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}
