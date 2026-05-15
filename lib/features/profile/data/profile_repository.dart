import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'profile_models.dart';

class ProfileRepository {
  ProfileRepository(this._dio);
  final Dio _dio;

  /// Fetches the signed-in user's profile. Returns `null` when:
  ///   - the user isn't authenticated yet (401)
  ///   - the user record hasn't been provisioned server-side (404)
  ///
  /// The screen renders a friendly empty state in both cases.
  Future<Profile?> me() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/v1/users/me');
      return Profile.fromJson(res.data!);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 404) return null;
      rethrow;
    }
  }

  /// Mark the welcome-card reveal as seen on the server so /me stops
  /// returning it. Called after the user dismisses the reveal screen.
  Future<void> dismissWelcomeCard() async {
    try {
      await _dio.post('/v1/users/me/welcome-card/dismiss');
    } on DioException {
      // Non-fatal — server-side state will catch up on next /me read or on
      // a retry after the user reconnects. Don't surface to the UI.
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.read(dioProvider));
});

final myProfileProvider = FutureProvider<Profile?>((ref) {
  return ref.read(profileRepositoryProvider).me();
});
