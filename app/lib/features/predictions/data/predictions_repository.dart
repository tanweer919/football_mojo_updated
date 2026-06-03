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

  /// Submit the user's bracket picks. `picks` keys map to either:
  ///   - a single team id String   (GROUP_<letter>_1/2, CHAMPION)
  ///   - a List<String> of team ids (REACH_R16, REACH_QF, REACH_SF, REACH_FINAL)
  /// Backend stores the JSON verbatim; scoring inspects each key by shape.
  Future<BracketDto> submitBracket(
    String competitionId,
    Map<String, dynamic> picks,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/predictions/bracket',
      data: {'competitionId': competitionId, 'picks': picks},
    );
    return BracketDto.fromJson(res.data!);
  }

  Future<BracketDto?> myBracket(String competitionId) async {
    final res = await _dio.get<dynamic>(
      '/v1/predictions/bracket/me',
      queryParameters: {'competitionId': competitionId},
    );
    if (res.data == null) return null;
    return BracketDto.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<BracketLeaderRow>> bracketLeaderboard(String competitionId) async {
    final res = await _dio.get<List<dynamic>>(
      '/v1/predictions/bracket/leaderboard',
      queryParameters: {'competitionId': competitionId},
    );
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(BracketLeaderRow.fromJson)
        .toList(growable: false);
  }
}

class BracketDto {
  BracketDto({
    required this.id,
    required this.competitionId,
    required this.picks,
    required this.pointsAwarded,
    required this.isLocked,
    this.lockedAt,
    this.updatedAt,
  });
  final String id;
  final String competitionId;
  /// Mixed-shape picks map. Group + champion slots store a single teamId
  /// string ("GROUP_A_1" → "team-arg-id"). Knockout-reach slots store a
  /// list of teamIds ("REACH_R16" → ["team-arg-id", "team-fra-id", …]).
  /// Untyped here; callers use the typed getters below.
  final Map<String, dynamic> picks;
  final int pointsAwarded;
  final bool isLocked;
  final DateTime? lockedAt;
  final DateTime? updatedAt;

  factory BracketDto.fromJson(Map<String, dynamic> j) => BracketDto(
        id: j['id'] as String,
        competitionId: j['competitionId'] as String,
        picks: ((j['picks'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, v)),
        pointsAwarded: (j['pointsAwarded'] as num?)?.toInt() ?? 0,
        isLocked: j['isLocked'] as bool? ?? false,
        lockedAt: j['lockedAt'] == null ? null : DateTime.parse(j['lockedAt'] as String),
        updatedAt: j['updatedAt'] == null ? null : DateTime.parse(j['updatedAt'] as String),
      );

  // ─── Typed read helpers ────────────────────────────────────────────────
  // Picks shape (must match the bracket screen + backend):
  //   GROUP_<letter>_<pos>  → teamId String   (12 × 4 = 48)
  //   BEST_THIRDS           → List<letter>     (up to 8)
  //   MATCH_<n>_WINNER      → teamId String    (R32..Final = 32, incl. bronze)
  String? slotPick(String key) {
    final v = picks[key];
    return v is String ? v : null;
  }
  List<String> reachPicks(String key) {
    final v = picks[key];
    if (v is List) return v.whereType<String>().toList(growable: false);
    return const [];
  }

  /// Champion = winner of the final (match 104).
  String? get championId => slotPick('MATCH_104_WINNER');

  /// Filled group-position picks (GROUP_<L>_<pos> with a teamId).
  int get groupPickCount =>
      picks.keys.where((k) => k.startsWith('GROUP_') && picks[k] is String).length;

  /// Selected best-third group letters (BEST_THIRDS list).
  int get bestThirdsCount => reachPicks('BEST_THIRDS').length;

  /// Filled knockout match winners (MATCH_<n>_WINNER with a teamId).
  int get knockoutPickCount => picks.keys
      .where((k) => k.startsWith('MATCH_') && k.endsWith('_WINNER') && picks[k] is String)
      .length;

  int get totalPickCount => groupPickCount + bestThirdsCount + knockoutPickCount;
}

class BracketLeaderRow {
  BracketLeaderRow({
    required this.rank,
    required this.userId,
    required this.total,
    this.displayName,
    this.photoUrl,
    this.countryCode,
  });
  final int rank;
  final String userId;
  final String? displayName;
  final String? photoUrl;
  final String? countryCode;
  final int total;

  factory BracketLeaderRow.fromJson(Map<String, dynamic> j) => BracketLeaderRow(
        rank: (j['rank'] as num).toInt(),
        userId: j['userId'] as String,
        displayName: j['displayName'] as String?,
        photoUrl: j['photoUrl'] as String?,
        countryCode: j['countryCode'] as String?,
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}

final predictionsRepositoryProvider =
    Provider<PredictionsRepository>((ref) => PredictionsRepository(ref.read(dioProvider)));
final myPredictionsProvider =
    FutureProvider<List<PredictionEntry>>((ref) => ref.read(predictionsRepositoryProvider).mine());
final predictionsLeaderboardProvider =
    FutureProvider<List<PredictionLeaderRow>>((ref) => ref.read(predictionsRepositoryProvider).leaderboard());

final myBracketProvider = FutureProvider.family<BracketDto?, String>(
  (ref, competitionId) => ref.read(predictionsRepositoryProvider).myBracket(competitionId),
);
final bracketLeaderboardProvider = FutureProvider.family<List<BracketLeaderRow>, String>(
  (ref, competitionId) => ref.read(predictionsRepositoryProvider).bracketLeaderboard(competitionId),
);
