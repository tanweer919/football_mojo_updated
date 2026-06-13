import 'dart:ui' as ui;

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
