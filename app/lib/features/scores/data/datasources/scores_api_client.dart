import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_dto.dart';
import '../../../../core/network/dio_provider.dart';

final scoresApiClientProvider = Provider<ScoresApiClient>((ref) {
  return ScoresApiClient(ref.read(dioProvider));
});

class ScoresApiClient {
  ScoresApiClient(this._dio);
  final Dio _dio;

  Future<List<MatchDto>> fetchLive() async {
    final res = await _dio.get<List<dynamic>>('/v1/scores/live');
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(MatchDto.fromJson)
        .toList(growable: false);
  }

  Future<List<MatchDto>> fetchFixtures({DateTime? day}) async {
    final d = (day ?? DateTime.now()).toIso8601String().substring(0, 10);
    final res = await _dio.get<List<dynamic>>('/v1/scores/fixtures', queryParameters: {'day': d});
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(MatchDto.fromJson)
        .toList(growable: false);
  }

  /// Returns null when the backend has no record of this fixture (e.g. live
  /// match from an untracked league surfaced via /scores/live but never
  /// persisted, or a stale id). Throws on transport/server errors.
  Future<MatchDto?> fetchMatch(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/v1/scores/matches/$id');
      if (res.data == null) return null;
      return MatchDto.fromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
