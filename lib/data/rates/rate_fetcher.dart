import 'dart:convert';

import 'package:http/http.dart' as http;

/// Where the official ZiG/USD rate comes from. Swap the implementation (for
/// example a Reserve Bank of Zimbabwe feed, or your own endpoint) without
/// touching the rest of the app.
abstract class RateFetcher {
  /// ZiG for 1 US$, or null when unavailable (offline, bad response, missing currency).
  Future<double?> fetchZigPerUsd();

  String get label;
}

/// Free open-access feed from ExchangeRate-API (no key). ZiG's ISO code is ZWG.
/// Rates update once a day, which is right for a budgeting app.
class OpenExchangeRateFetcher implements RateFetcher {
  OpenExchangeRateFetcher({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final Uri _url = Uri.parse('https://open.er-api.com/v6/latest/USD');

  @override
  String get label => 'open.er-api.com';

  @override
  Future<double?> fetchZigPerUsd() async {
    try {
      final res = await _client.get(_url).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic>) return null;
      final rates = body['rates'];
      if (rates is! Map<String, dynamic>) return null;
      final zwg = rates['ZWG'] ?? rates['ZIG'];
      if (zwg is num && zwg > 0) return zwg.toDouble();
      return null;
    } catch (_) {
      return null;
    }
  }
}
