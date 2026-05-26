import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';

enum AwardType { GOLDEN_BOOT, GOLDEN_BALL, BEST_YOUNG_PLAYER }

extension AwardTypeLabel on AwardType {
  String get label => switch (this) {
        AwardType.GOLDEN_BOOT => 'Golden Boot',
        AwardType.GOLDEN_BALL => 'Golden Ball',
        AwardType.BEST_YOUNG_PLAYER => 'Best Young Player',
      };
  String get tagline => switch (this) {
        AwardType.GOLDEN_BOOT => 'Top scorer of the tournament.',
        AwardType.GOLDEN_BALL => 'Player of the tournament.',
        AwardType.BEST_YOUNG_PLAYER => 'Best player under 22.',
      };
}

class AwardPlayer {
  AwardPlayer({
    required this.id,
    required this.name,
    this.teamName,
    this.teamCrestUrl,
    this.photoUrl,
    this.position,
  });
  factory AwardPlayer.fromJson(Map<String, dynamic> j) => AwardPlayer(
        id: j['id'] as String,
        name: j['name'] as String,
        teamName: (j['team'] as Map?)?['name'] as String?,
        teamCrestUrl: (j['team'] as Map?)?['crestUrl'] as String?,
        photoUrl: j['photoUrl'] as String?,
        position: j['position'] as String?,
      );
  final String id;
  final String name;
  final String? teamName;
  final String? teamCrestUrl;
  final String? photoUrl;
  final String? position;
}

class AwardPick {
  AwardPick({
    required this.awardType,
    required this.playerId,
    required this.pointsAwarded,
    this.player,
    this.scoredAt,
    this.lockedAt,
  });
  factory AwardPick.fromJson(Map<String, dynamic> j) {
    final raw = j['player'] as Map<String, dynamic>?;
    return AwardPick(
      awardType: AwardType.values.byName(j['awardType'] as String),
      playerId: j['playerId'] as String,
      pointsAwarded: (j['pointsAwarded'] as num?)?.toInt() ?? 0,
      player: raw == null ? null : AwardPlayer.fromJson(raw),
      scoredAt: j['scoredAt'] == null ? null : DateTime.parse(j['scoredAt'] as String),
      lockedAt: j['lockedAt'] == null ? null : DateTime.parse(j['lockedAt'] as String),
    );
  }
  final AwardType awardType;
  final String playerId;
  final int pointsAwarded;
  final AwardPlayer? player;
  final DateTime? scoredAt;
  final DateTime? lockedAt;
}

class AwardsRepository {
  AwardsRepository(this._dio);
  final Dio _dio;

  Future<List<AwardPlayer>> candidates({
    required String competitionId,
    required AwardType awardType,
    int limit = 30,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/v1/awards/candidates',
      queryParameters: {
        'competitionId': competitionId,
        'awardType': awardType.name,
        'limit': limit,
      },
    );
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(AwardPlayer.fromJson)
        .toList(growable: false);
  }

  Future<List<AwardPick>> myPicks(String competitionId) async {
    final res = await _dio.get<List<dynamic>>(
      '/v1/awards/mine',
      queryParameters: {'competitionId': competitionId},
    );
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(AwardPick.fromJson)
        .toList(growable: false);
  }

  Future<AwardPick> submitPick({
    required String competitionId,
    required AwardType awardType,
    required String playerId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/awards/picks',
      data: {
        'competitionId': competitionId,
        'awardType': awardType.name,
        'playerId': playerId,
      },
    );
    return AwardPick.fromJson(res.data!);
  }
}

final awardsRepositoryProvider =
    Provider<AwardsRepository>((ref) => AwardsRepository(ref.read(dioProvider)));

final myAwardPicksProvider =
    FutureProvider.family<List<AwardPick>, String>((ref, competitionId) {
  return ref.read(awardsRepositoryProvider).myPicks(competitionId);
});

final awardCandidatesProvider = FutureProvider.family<List<AwardPlayer>,
    ({String competitionId, AwardType awardType})>((ref, args) {
  return ref.read(awardsRepositoryProvider).candidates(
        competitionId: args.competitionId,
        awardType: args.awardType,
      );
});
