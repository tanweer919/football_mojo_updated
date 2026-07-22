import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_provider.dart';

/// Remote feature flags fetched from `GET /v1/app-config`.
///
/// Cached in memory for the app session. Falls back to sensible defaults
/// if the network request fails (offline, server error, etc.).
class RemoteAppConfig {
  const RemoteAppConfig({this.wcMode = false, this.adsEnabled = true});

  /// Legacy World-Cup emphasis flag. When true the home screen hid dormant
  /// European-league sections and promoted World Cup content. The World Cup is
  /// over, so this defaults to false (club football forward). Driven by the
  /// server env `WC_MODE` — set it to false in production too.
  final bool wcMode;

  /// Master ad kill-switch from the server env `ADS_ENABLED`. When false,
  /// the app skips AdMob init and hides every ad surface (banner +
  /// rewarded entry points) instantly on the next config fetch — no app
  /// release required.
  final bool adsEnabled;

  factory RemoteAppConfig.fromJson(Map<String, dynamic> json) {
    return RemoteAppConfig(
      wcMode: json['wcMode'] as bool? ?? false,
      adsEnabled: json['adsEnabled'] as bool? ?? true,
    );
  }
}

/// Fetches the remote config once per app session and caches.
/// Defaults to WC mode on if fetch fails.
final remoteAppConfigProvider = FutureProvider<RemoteAppConfig>((ref) async {
  try {
    final dio = ref.read(dioProvider);
    final res = await dio.get<Map<String, dynamic>>('/v1/app-config');
    if (res.data != null) {
      return RemoteAppConfig.fromJson(res.data!);
    }
  } on DioException catch (_) {
    // Offline or server down — default to WC mode on (tournament is live).
  }
  return const RemoteAppConfig();
});

/// Convenience accessor: true when World Cup mode is active.
final wcModeProvider = Provider<bool>((ref) {
  return ref.watch(remoteAppConfigProvider).valueOrNull?.wcMode ?? false;
});

/// Convenience accessor: true when ads should be shown. Defaults to true
/// until the config resolves so we never block the first banner on a slow
/// fetch; the server flag flips it off within one fetch when needed.
final adsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(remoteAppConfigProvider).valueOrNull?.adsEnabled ?? true;
});
