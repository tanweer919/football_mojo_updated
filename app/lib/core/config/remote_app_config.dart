import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_provider.dart';

/// Remote feature flags fetched from `GET /v1/app-config`.
///
/// Cached in memory for the app session. Falls back to sensible defaults
/// if the network request fails (offline, server error, etc.).
class RemoteAppConfig {
  const RemoteAppConfig({this.wcMode = true});

  /// When true the home screen hides dormant European-league sections
  /// and promotes World Cup content. Driven by the server env `WC_MODE`.
  final bool wcMode;

  factory RemoteAppConfig.fromJson(Map<String, dynamic> json) {
    return RemoteAppConfig(
      wcMode: json['wcMode'] as bool? ?? true,
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
  return ref.watch(remoteAppConfigProvider).valueOrNull?.wcMode ?? true;
});
