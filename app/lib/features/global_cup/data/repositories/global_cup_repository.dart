import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import '../../../fantasy/data/models/fantasy_models.dart';

class GlobalCupPrize {
  GlobalCupPrize({
    required this.id,
    required this.rankFrom,
    required this.rankTo,
    required this.description,
    required this.cardTemplateId,
    required this.cardEdition,
    required this.cardRarity,
    required this.artUrl,
  });
  factory GlobalCupPrize.fromJson(Map<String, dynamic> j) {
    final tpl = j['cardTemplate'] as Map<String, dynamic>;
    return GlobalCupPrize(
      id: j['id'] as String,
      rankFrom: j['rankFrom'] as int,
      rankTo: j['rankTo'] as int,
      description: j['description'] as String,
      cardTemplateId: j['cardTemplateId'] as String,
      cardEdition: tpl['edition'] as String,
      cardRarity: tpl['rarity'] as String,
      artUrl: tpl['artUrl'] as String,
    );
  }
  final String id;
  final int rankFrom;
  final int rankTo;
  final String description;
  final String cardTemplateId;
  final String cardEdition;
  final String cardRarity;
  final String artUrl;

  int get supply => rankTo - rankFrom + 1;
}

class MyCupRank {
  MyCupRank({required this.rank, required this.total});
  factory MyCupRank.fromJson(Map<String, dynamic> j) =>
      MyCupRank(rank: (j['rank'] as int?) ?? 0, total: (j['total'] as num?)?.toDouble() ?? 0);
  final int rank;
  final double total;
}

class GlobalCupRepository {
  GlobalCupRepository(this._dio);
  final Dio _dio;

  Future<List<LeaderboardEntry>> leaderboard(String tournamentId, {int limit = 1000}) async {
    final res = await _dio.get<List<dynamic>>(
      '/v1/global-cup/$tournamentId/leaderboard',
      queryParameters: {'limit': limit},
    );
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(LeaderboardEntry.fromJson)
        .toList(growable: false);
  }

  Future<List<GlobalCupPrize>> prizes(String tournamentId) async {
    final res = await _dio.get<List<dynamic>>('/v1/global-cup/$tournamentId/prizes');
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(GlobalCupPrize.fromJson)
        .toList(growable: false);
  }

  Future<MyCupRank> myRank(String tournamentId) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/global-cup/$tournamentId/me');
    return MyCupRank.fromJson(res.data!);
  }
}

final globalCupRepositoryProvider = Provider<GlobalCupRepository>((ref) {
  return GlobalCupRepository(ref.read(dioProvider));
});

final globalCupLeaderboardProvider =
    FutureProvider.family<List<LeaderboardEntry>, String>((ref, id) {
  return ref.read(globalCupRepositoryProvider).leaderboard(id);
});

final globalCupPrizesProvider = FutureProvider.family<List<GlobalCupPrize>, String>((ref, id) {
  return ref.read(globalCupRepositoryProvider).prizes(id);
});

final myCupRankProvider = FutureProvider.family<MyCupRank, String>((ref, id) {
  return ref.read(globalCupRepositoryProvider).myRank(id);
});
