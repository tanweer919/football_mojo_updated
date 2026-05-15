import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.realtimeUrl});
  final String apiBaseUrl;
  final String realtimeUrl;
}

// Real builds wire these from --dart-define / Firebase Remote Config.
final appConfigProvider = Provider<AppConfig>((_) => const AppConfig(
      apiBaseUrl: String.fromEnvironment('API_BASE_URL', defaultValue: 'https://8d3c-223-181-24-32.ngrok-free.app/api'),
      realtimeUrl: String.fromEnvironment('REALTIME_URL', defaultValue: 'https://8d3c-223-181-24-32.ngrok-free.app'),
    ));
