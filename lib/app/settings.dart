import 'package:flutter/material.dart';

import '../core/l10n/language.dart';
import '../core/money/money.dart';

/// Default notification sources for Android capture. Package names are the
/// apps' Play Store ids; senders are matched against a messaging app's
/// notification title (the SMS sender name).
class CaptureDefaults {
  static const ecocashPackages = ['com.ecocash.superapp', 'com.ecocash'];
  static const googleMessages = 'com.google.android.apps.messaging';
  static const samsungMessages = 'com.samsung.android.messaging';
  static const messagingPackages = [googleMessages, samsungMessages];
  static const packages = [...ecocashPackages, googleMessages];
  static const senders = ['EcoCash', 'CBZ', 'Stanbic', 'Steward', 'FBC', 'NMB', 'InnBucks', 'OneMoney', 'ZB Bank', 'CABS'];
}

/// Fallback when no rate has ever been fetched or entered (official interbank,
/// late 2026). The app asks the person to confirm a rate during onboarding.
const double kFallbackZigPerUsd = 26.66;

@immutable
class AppSettings {
  const AppSettings({
    this.onboarded = false,
    this.language = AppLanguage.en,
    this.homeCurrency = Currency.usd,
    this.displayCurrency = Currency.usd,
    this.themeMode = ThemeMode.system,
    this.useManualRate = false,
    this.manualRate = kFallbackZigPerUsd,
    this.captureEnabled = false,
    this.capturePackages = CaptureDefaults.packages,
    this.captureSenders = CaptureDefaults.senders,
    this.lastRateFetch,
  });

  final bool onboarded;
  final AppLanguage language;
  final Currency homeCurrency;
  final Currency displayCurrency;
  final ThemeMode themeMode;
  final bool useManualRate;
  final double manualRate;
  final bool captureEnabled;
  final List<String> capturePackages;
  final List<String> captureSenders;
  final DateTime? lastRateFetch;

  AppSettings copyWith({
    bool? onboarded,
    AppLanguage? language,
    Currency? homeCurrency,
    Currency? displayCurrency,
    ThemeMode? themeMode,
    bool? useManualRate,
    double? manualRate,
    bool? captureEnabled,
    List<String>? capturePackages,
    List<String>? captureSenders,
    DateTime? lastRateFetch,
  }) {
    return AppSettings(
      onboarded: onboarded ?? this.onboarded,
      language: language ?? this.language,
      homeCurrency: homeCurrency ?? this.homeCurrency,
      displayCurrency: displayCurrency ?? this.displayCurrency,
      themeMode: themeMode ?? this.themeMode,
      useManualRate: useManualRate ?? this.useManualRate,
      manualRate: manualRate ?? this.manualRate,
      captureEnabled: captureEnabled ?? this.captureEnabled,
      capturePackages: capturePackages ?? this.capturePackages,
      captureSenders: captureSenders ?? this.captureSenders,
      lastRateFetch: lastRateFetch ?? this.lastRateFetch,
    );
  }

  Map<String, String> toStore() => {
        'onboarded': onboarded.toString(),
        'language': language.name,
        'homeCurrency': homeCurrency.name,
        'displayCurrency': displayCurrency.name,
        'themeMode': themeMode.name,
        'useManualRate': useManualRate.toString(),
        'manualRate': manualRate.toString(),
        'captureEnabled': captureEnabled.toString(),
        'capturePackages': capturePackages.join('\n'),
        'captureSenders': captureSenders.join('\n'),
        if (lastRateFetch != null) 'lastRateFetch': lastRateFetch!.toIso8601String(),
      };

  static AppSettings fromStore(Map<String, String> m) {
    List<String> list(String key, List<String> fallback) {
      final v = m[key];
      if (v == null) return fallback;
      return v.split('\n').where((s) => s.trim().isNotEmpty).toList();
    }

    return AppSettings(
      onboarded: m['onboarded'] == 'true',
      language: AppLanguage.fromName(m['language']),
      homeCurrency: Currency.fromName(m['homeCurrency']),
      displayCurrency: Currency.fromName(m['displayCurrency'] ?? m['homeCurrency']),
      themeMode: ThemeMode.values.firstWhere((t) => t.name == m['themeMode'], orElse: () => ThemeMode.system),
      useManualRate: m['useManualRate'] == 'true',
      manualRate: double.tryParse(m['manualRate'] ?? '') ?? kFallbackZigPerUsd,
      captureEnabled: m['captureEnabled'] == 'true',
      capturePackages: list('capturePackages', CaptureDefaults.packages),
      captureSenders: list('captureSenders', CaptureDefaults.senders),
      lastRateFetch: DateTime.tryParse(m['lastRateFetch'] ?? ''),
    );
  }
}
