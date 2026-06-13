import 'dart:convert';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';

/// Country via **IP geolocation** over HTTPS — no permission, and reflects the
/// user's actual network location (unlike the device locale, which is just the
/// phone's Region setting and is wrong for e.g. an en-US phone used in India).
///
/// Returns an ISO-3166 alpha-2 code, or null on failure. Tries a couple of free
/// keyless providers and times out fast so it never blocks the UI. NOTE: the
/// free `ip-api.com` is HTTP-only, which Android (cleartext) and iOS (ATS) block
/// on real devices — so we use HTTPS providers instead.
Future<String?> countryByIp() async {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 4),
  ));
  const providers = <(String, String)>[
    ('https://ipapi.co/json/', 'country_code'),
    ('https://ipwho.is/', 'country_code'),
    ('https://get.geojs.io/v1/ip/country.json', 'country'),
  ];
  for (final (url, key) in providers) {
    try {
      final res = await dio.get<dynamic>(url);
      final body = res.data;
      final data = body is String ? jsonDecode(body) : body;
      final code = (data is Map ? data[key] : null)?.toString().trim();
      if (code != null && code.length == 2) return code.toUpperCase();
    } catch (_) {
      // Provider failed/blocked — fall through to the next one.
    }
  }
  return null;
}

/// Best-effort country detection that needs **no location permission**.
///
/// Reads the device's *region* setting (Settings › Language & Region) via the
/// platform locale — e.g. `en_IN` → `IN`. This reflects how the phone is
/// configured, not a GPS fix, so it's instant and permission-free but can be
/// wrong for travellers / VPNs. The backend (which sees the request IP) is the
/// authoritative source; this is the client-side hint + sort key.
String? deviceCountryCode() {
  final cc = ui.PlatformDispatcher.instance.locale.countryCode;
  if (cc == null || cc.isEmpty) return null;
  return cc.toUpperCase();
}

/// Flag emoji for an ISO-3166 alpha-2 code (`IN` → 🇮🇳) by mapping each letter
/// to its Regional Indicator Symbol. Avoids shipping flag assets. Returns an
/// empty string for anything that isn't a 2-letter code.
String countryFlagEmoji(String? code) {
  if (code == null || code.length != 2) return '';
  final upper = code.toUpperCase();
  final a = upper.codeUnitAt(0), b = upper.codeUnitAt(1);
  if (a < 0x41 || a > 0x5A || b < 0x41 || b > 0x5A) return '';
  return String.fromCharCode(0x1F1E6 + (a - 0x41)) +
      String.fromCharCode(0x1F1E6 + (b - 0x41));
}
