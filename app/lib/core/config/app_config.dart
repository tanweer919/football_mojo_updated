import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.realtimeUrl});
  final String apiBaseUrl;
  final String realtimeUrl;
}

// Real builds wire these from --dart-define / Firebase Remote Config.
final appConfigProvider = Provider<AppConfig>((_) => const AppConfig(
      apiBaseUrl: String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.footballmojo.in/api'),
      realtimeUrl: String.fromEnvironment('REALTIME_URL', defaultValue: 'https://api.footballmojo.in'),
    ));
