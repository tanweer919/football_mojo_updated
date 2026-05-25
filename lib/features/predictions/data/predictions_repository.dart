import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';

class PredictionEntry {
  PredictionEntry({
    required this.id,
    required this.matchId,
    required this.homeScore,
    required this.awayScore,
    required this.pointsAwarded,
  });
  factory PredictionEntry.fromJson(Map<String, dynamic> j) => PredictionEntry(
        id: j['id'] as String,
        matchId: j['matchId'] as String,
        homeScore: j['homeScore'] as int,
        awayScore: j['awayScore'] as int,
        pointsAwarded: (j['pointsAwarded'] as num?)?.toInt() ?? 0,
      );
  final String id;
  final String matchId;
  final int homeScore;
  final int awayScore;
  final int pointsAwarded;
}

class PredictionLeaderRow {
  PredictionLeaderRow({required this.userId, required this.displayName, required this.total});
  factory PredictionLeaderRow.fromJson(Map<String, dynamic> j) => PredictionLeaderRow(
        userId: j['userId'] as String,
        displayName: j['displayName'] as String?,
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
  final String userId;
  final String? displayName;
  final int total;
}

class PredictionsRepository {
  PredictionsRepository(this._dio);
  final Dio _dio;

  Future<PredictionEntry> submit(String matchId, int homeScore, int awayScore) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/predictions/matches/$matchId',
      data: {'homeScore': homeScore, 'awayScore': awayScore},
    );
    return PredictionEntry.fromJson(res.data!);
  }

  Future<List<PredictionEntry>> mine() async {
    final res = await _dio.get<List<dynamic>>('/v1/predictions/mine');
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(PredictionEntry.fromJson)
        .toList();
  }

  Future<List<PredictionLeaderRow>> leaderboard({String? competitionId}) async {
    final res = await _dio.get<List<dynamic>>(
      '/v1/predictions/leaderboard',
      queryParameters: {if (competitionId != null) 'competitionId': competitionId},
    );
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(PredictionLeaderRow.fromJson)
        .toList();
  }

  Future<void> submitBracket(String competitionId, Map<String, String> picks) async {
    await _dio.post('/v1/predictions/bracket', data: {'competitionId': competitionId, 'picks': picks});
  }
}

final predictionsRepositoryProvider =
    Provider<PredictionsRepository>((ref) => PredictionsRepository(ref.read(dioProvider)));
final myPredictionsProvider =
    FutureProvider<List<PredictionEntry>>((ref) => ref.read(predictionsRepositoryProvider).mine());
final predictionsLeaderboardProvider =
    FutureProvider<List<PredictionLeaderRow>>((ref) => ref.read(predictionsRepositoryProvider).leaderboard());
