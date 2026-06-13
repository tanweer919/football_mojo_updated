import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/util/region.dart';
import 'models/broadcast_dto.dart';
import 'models/h2h_dto.dart';
import 'models/injury_dto.dart';
import 'models/lineup_dto.dart';
import 'models/match_event_dto.dart';
import 'models/match_preview_dto.dart';
import 'models/match_stats_dto.dart';
import 'models/top_player_dto.dart';

/// Single repository over every `/v1/insights/*` endpoint. Backend handles
/// caching + rate-limiting; the client just maps JSON to typed models.
class InsightsRepository {
  InsightsRepository(this._dio);
  final Dio _dio;

  // ── Match Detail tabs ───────────────────────────────────────────────────────
  Future<List<MatchEventDto>> matchEvents(String fixtureId) async {
    final res = await _dio.get<List<dynamic>>('/v1/insights/match-events/$fixtureId');
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(MatchEventDto.fromJson)
        .toList(growable: false);
  }

  Future<List<TeamMatchStatsDto>> matchStats(String fixtureId) async {
    final res = await _dio.get<List<dynamic>>('/v1/insights/match-statistics/$fixtureId');
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(TeamMatchStatsDto.fromJson)
        .toList(growable: false);
  }

  Future<List<LineupDto>> matchLineups(String fixtureId) async {
    final res = await _dio.get<List<dynamic>>('/v1/insights/lineup/$fixtureId');
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(LineupDto.fromJson)
        .toList(growable: false);
  }

  /// Where-to-watch broadcasters, grouped by country. `country` is a hint the
  /// backend can use alongside the request IP to rank the viewer's region
  /// first. Returns `[]` until the backend's broadcast source is wired up
  /// (api-football carries no TV data).
  Future<List<MatchBroadcastDto>> matchBroadcasts(String fixtureId, {String? country}) async {
    final res = await _dio.get<List<dynamic>>(
      '/v1/insights/broadcasts/$fixtureId',
      queryParameters: {if (country != null && country.isNotEmpty) 'country': country},
    );
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(MatchBroadcastDto.fromJson)
        .toList(growable: false);
  }

  // ── Match preview / context ─────────────────────────────────────────────────
  Future<MatchPreviewDto?> matchPreview(String fixtureId) async {
    final res = await _dio.get<List<dynamic>>('/v1/insights/predictions/$fixtureId');
    final rows = (res.data ?? const []).cast<Map<String, dynamic>>();
    return rows.isEmpty ? null : MatchPreviewDto.fromJson(rows.first);
  }

  Future<List<H2HMatchDto>> h2h(String team1, String team2, {int last = 10}) async {
    final res = await _dio.get<List<dynamic>>('/v1/insights/h2h', queryParameters: {
      'team1': team1, 'team2': team2, 'last': last,
    });
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(H2HMatchDto.fromJson)
        .toList(growable: false);
  }

  // ── Tournament-wide insights ────────────────────────────────────────────────
  Future<List<InjuryDto>> injuries() async {
    final res = await _dio.get<List<dynamic>>('/v1/insights/injuries');
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(InjuryDto.fromJson)
        .toList(growable: false);
  }

  Future<List<TopPlayerDto>> topScorers() async {
    final res = await _dio.get<List<dynamic>>('/v1/insights/top-scorers');
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map((j) => TopPlayerDto.fromJson(j, statKey: 'goals'))
        .toList(growable: false);
  }

  Future<List<TopPlayerDto>> topAssists() async {
    final res = await _dio.get<List<dynamic>>('/v1/insights/top-assists');
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map((j) => TopPlayerDto.fromJson(j, statKey: 'assists'))
        .toList(growable: false);
  }
}

final insightsRepositoryProvider = Provider<InsightsRepository>((ref) {
  return InsightsRepository(ref.read(dioProvider));
});

// Per-fixture providers — cached on backend, family-keyed on client.
final matchEventsProvider   = FutureProvider.family<List<MatchEventDto>,     String>((ref, id) => ref.read(insightsRepositoryProvider).matchEvents(id));
final matchStatsProvider    = FutureProvider.family<List<TeamMatchStatsDto>, String>((ref, id) => ref.read(insightsRepositoryProvider).matchStats(id));
final matchLineupsProvider  = FutureProvider.family<List<LineupDto>,         String>((ref, id) => ref.read(insightsRepositoryProvider).matchLineups(id));
final matchPreviewProvider  = FutureProvider.family<MatchPreviewDto?,        String>((ref, id) => ref.read(insightsRepositoryProvider).matchPreview(id));
final matchBroadcastsProvider = FutureProvider.family<List<MatchBroadcastDto>, String>(
  (ref, id) => ref.read(insightsRepositoryProvider).matchBroadcasts(id, country: deviceCountryCode()),
);

final h2hProvider = FutureProvider.family<List<H2HMatchDto>, ({String team1, String team2})>(
  (ref, args) => ref.read(insightsRepositoryProvider).h2h(args.team1, args.team2),
);

final injuriesProvider   = FutureProvider<List<InjuryDto>>   ((ref) => ref.read(insightsRepositoryProvider).injuries());
final topScorersProvider = FutureProvider<List<TopPlayerDto>>((ref) => ref.read(insightsRepositoryProvider).topScorers());
final topAssistsProvider = FutureProvider<List<TopPlayerDto>>((ref) => ref.read(insightsRepositoryProvider).topAssists());
