import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/notifications/fcm_service.dart';
import '../../profile/data/profile_repository.dart';

/// Search-result row from `GET /v1/competitions/teams/search`.
class TeamHit {
  const TeamHit({
    required this.id,
    required this.name,
    this.shortName,
    this.crestUrl,
    this.countryCode,
    this.competitionName,
  });
  final String id;
  final String name;
  final String? shortName;
  final String? crestUrl;
  final String? countryCode;
  final String? competitionName;

  factory TeamHit.fromJson(Map<String, dynamic> j) => TeamHit(
        id: j['id'] as String,
        name: j['name'] as String,
        shortName: j['shortName'] as String?,
        crestUrl: j['crestUrl'] as String?,
        countryCode: j['countryCode'] as String?,
        competitionName: (j['competition'] as Map?)?['name'] as String?,
      );
}

/// Thin Dio wrapper for team search + follow/unfollow toggles. Lives in
/// its own module so the picker screen + home "Your teams" prompt can
/// both depend on it without pulling the bigger profile module.
class TeamPickerRepository {
  TeamPickerRepository(this._dio, this._ref);
  final Dio _dio;
  final Ref _ref;

  Future<List<TeamHit>> search({String? query, String? competitionId}) async {
    final res = await _dio.get<List<dynamic>>(
      '/v1/competitions/teams/search',
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (competitionId != null && competitionId.isNotEmpty) 'competitionId': competitionId,
      },
    );
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(TeamHit.fromJson)
        .toList(growable: false);
  }

  /// Toggle a team. The backend is idempotent so we don't need to know the
  /// current state — just send the desired op. Returns the new follow
  /// state for optimistic UI use.
  Future<void> follow(String teamId) async {
    await _dio.post<void>('/v1/users/me/follow/$teamId');
    _ref.invalidate(myProfileProvider);
    await _syncTeamTopics();
  }

  Future<void> unfollow(String teamId) async {
    await _dio.delete<void>('/v1/users/me/follow/$teamId');
    _ref.invalidate(myProfileProvider);
    await _syncTeamTopics();
  }

  /// Reconcile FCM team topics with the freshly-updated follow list so push
  /// (goals/kickoff/FT/lineup/news) starts or stops immediately on a change.
  Future<void> _syncTeamTopics() async {
    try {
      final profile = await _ref.read(myProfileProvider.future);
      if (profile != null) {
        await FcmBootstrap.syncTeams(
          profile.followedTeams.map((t) => t.id).toSet(),
        );
      }
    } catch (_) {/* best-effort; also re-synced on next app start */}
  }
}

final teamPickerRepositoryProvider = Provider<TeamPickerRepository>(
  (ref) => TeamPickerRepository(ref.read(dioProvider), ref),
);

/// Family keyed by `(q, competitionId)` so each filter combination caches
/// separately and identical queries dedupe.
final teamSearchProvider = FutureProvider.family<
    List<TeamHit>, ({String? q, String? competitionId})>((ref, args) {
  return ref.read(teamPickerRepositoryProvider).search(
        query: args.q,
        competitionId: args.competitionId,
      );
});
