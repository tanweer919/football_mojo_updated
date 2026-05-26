import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_repository.dart';
import '../config/app_config.dart';

final dioProvider = Provider<Dio>((ref) {
  final cfg = ref.read(appConfigProvider);
  final dio = Dio(BaseOptions(
    baseUrl: cfg.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'accept': 'application/json'},
  ));

  // Attach the Firebase ID token to every request if signed in.
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      try {
        final token = await ref.read(authRepositoryProvider).getIdToken();
        if (token != null) options.headers['authorization'] = 'Bearer $token';
      } catch (_) { /* unauthenticated requests are fine for public endpoints */ }
      handler.next(options);
    },
  ));

  dio.interceptors.add(RetryInterceptor(
    dio: dio,
    retries: 3,
    retryDelays: const [Duration(milliseconds: 300), Duration(seconds: 1), Duration(seconds: 3)],
    retryableExtraStatuses: const {408, 429, 500, 502, 503, 504},
  ));

  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(responseBody: false, requestBody: false));
  }
  return dio;
});
