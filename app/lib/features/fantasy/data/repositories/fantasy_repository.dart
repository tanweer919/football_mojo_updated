import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import '../models/fantasy_models.dart';
import '../models/league_models.dart';

/// The passive fantasy boost a user gets for owning a player's collectible
/// card. Keyed by playerId in the map returned by [FantasyRepository
/// .ownedCardMultipliers]. `multiplier` is the scoring factor the backend
/// applies at rollup (e.g. 1.6 for ICONIC); [pctLabel] renders the "+60%"
/// badge in the picker + lineup builder.
class CardBoost {
  const CardBoost({required this.rarity, required this.multiplier});
  factory CardBoost.fromJson(Map<String, dynamic> j) => CardBoost(
        rarity: j['rarity'] as String? ?? '',
        multiplier: (j['multiplier'] as num?)?.toDouble() ?? 1.0,
      );
  final String rarity;
  final double multiplier;

  /// "+60%" — the percentage uplift over the 1.0 base, rounded.
  String get pctLabel => '+${((multiplier - 1) * 100).round()}%';
}

class FantasyRepository {
  FantasyRepository(this._dio);
  final Dio _dio;

  /// Owned-card boosts keyed by playerId for the signed-in user. The backend
  /// auto-applies the user's highest-rarity card per player at scoring time;
  /// this drives the "+X%" badges so the boost is visible while picking.
  /// Returns an empty map for anonymous users (401) or anyone with no cards.
  Future<Map<String, CardBoost>> ownedCardMultipliers() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/v1/fantasy/me/owned-multipliers');
      final data = res.data ?? const <String, dynamic>{};
      return data.map(
        (k, v) => MapEntry(k, CardBoost.fromJson((v as Map).cast<String, dynamic>())),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return const {};
      rethrow;
    }
  }

  Future<List<FantasyTournamentDto>> listTournaments() async {
    final res = await _dio.get<List<dynamic>>('/v1/fantasy/tournaments');
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(FantasyTournamentDto.fromJson)
        .toList(growable: false);
  }

  Future<FantasyTournamentDto> getTournament(String slug) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/fantasy/tournaments/$slug');
    return FantasyTournamentDto.fromJson(res.data!);
  }

  Future<FantasyGameweekDto?> currentGameweek(String slug) async {
    final res = await _dio.get('/v1/fantasy/tournaments/$slug/current-gameweek');
    if (res.data == null) return null;
    return FantasyGameweekDto.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<PlayerValuationDto>> selectablePlayers(String slug) async {
    final res = await _dio.get<List<dynamic>>('/v1/fantasy/tournaments/$slug/players');
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(PlayerValuationDto.fromJson)
        .toList(growable: false);
  }

  Future<FantasyLineupDto?> myLineup(String slug, String gameweekId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/fantasy/tournaments/$slug/gameweeks/$gameweekId/lineup/mine',
      );
      if (res.data == null) return null;
      return FantasyLineupDto.fromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<FantasyLineupDto> submitLineup({
    required String slug,
    required String gameweekId,
    required List<LineupPick> picks,
    required String captainId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/fantasy/tournaments/$slug/gameweeks/$gameweekId/lineup',
      data: {
        'picks': picks.map((p) => p.toJson()).toList(),
        'captainId': captainId,
      },
    );
    return FantasyLineupDto.fromJson(res.data!);
  }

  Future<List<LeaderboardEntry>> leaderboard(String slug, String gameweekId, {int limit = 100}) async {
    final res = await _dio.get<List<dynamic>>(
      '/v1/fantasy/tournaments/$slug/gameweeks/$gameweekId/leaderboard',
      queryParameters: {'limit': limit},
    );
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(LeaderboardEntry.fromJson)
        .toList(growable: false);
  }

  // ─── Private leagues ────────────────────────────────────────────────────
  Future<List<FantasyLeagueSummary>> myLeagues({String? tournamentId}) async {
    final res = await _dio.get<List<dynamic>>(
      '/v1/fantasy/leagues/mine',
      queryParameters: {if (tournamentId != null) 'tournamentId': tournamentId},
    );
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(FantasyLeagueSummary.fromJson)
        .toList(growable: false);
  }

  Future<FantasyLeagueSummary> createLeague({
    required String tournamentId,
    required String name,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/fantasy/leagues',
      data: {'tournamentId': tournamentId, 'name': name},
    );
    final j = res.data!;
    // Server returns the league row; coerce into our flat summary shape.
    return FantasyLeagueSummary(
      id: j['id'] as String,
      tournamentId: j['tournamentId'] as String,
      tournamentSlug: '',
      tournamentName: '',
      name: j['name'] as String,
      joinCode: j['joinCode'] as String,
      memberCount: ((j['_count'] as Map?)?['members'] as num?)?.toInt() ?? 1,
      memberLimit: (j['memberLimit'] as num?)?.toInt() ?? 100,
      isOwner: true,
    );
  }

  Future<FantasyLeagueSummary> joinLeague(String joinCode) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/fantasy/leagues/join',
      data: {'joinCode': joinCode},
    );
    final j = res.data!;
    return FantasyLeagueSummary(
      id: j['id'] as String,
      tournamentId: j['tournamentId'] as String,
      tournamentSlug: '',
      tournamentName: '',
      name: j['name'] as String,
      joinCode: j['joinCode'] as String,
      memberCount: ((j['_count'] as Map?)?['members'] as num?)?.toInt() ?? 1,
      memberLimit: (j['memberLimit'] as num?)?.toInt() ?? 100,
      isOwner: false,
    );
  }

  Future<void> leaveLeague(String leagueId) async {
    await _dio.post('/v1/fantasy/leagues/$leagueId/leave');
  }

  Future<List<LeaderboardEntry>> leagueLeaderboard({
    required String leagueId,
    required String gameweekId,
    int limit = 100,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/v1/fantasy/leagues/$leagueId/gameweeks/$gameweekId/leaderboard',
      queryParameters: {'limit': limit},
    );
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(LeaderboardEntry.fromJson)
        .toList(growable: false);
  }
}

final fantasyRepositoryProvider = Provider<FantasyRepository>((ref) {
  return FantasyRepository(ref.read(dioProvider));
});
