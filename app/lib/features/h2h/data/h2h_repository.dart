import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';

enum H2HStatus { PENDING, ACCEPTED, LOCKED, RESOLVED, DECLINED, CANCELLED }

class H2HUserSummary {
  H2HUserSummary({required this.id, this.displayName, this.photoUrl});
  factory H2HUserSummary.fromJson(Map<String, dynamic> j) => H2HUserSummary(
        id: j['id'] as String,
        displayName: j['displayName'] as String?,
        photoUrl: j['photoUrl'] as String?,
      );
  final String id;
  final String? displayName;
  final String? photoUrl;
}

class H2HChallenge {
  H2HChallenge({
    required this.id,
    required this.tournamentId,
    required this.gameweekId,
    required this.gameweekName,
    required this.lockAt,
    required this.challenger,
    required this.status,
    required this.challengerScore,
    required this.opponentScore,
    this.opponent,
    this.inviteToken,
    this.winnerId,
    this.message,
  });
  factory H2HChallenge.fromJson(Map<String, dynamic> j) {
    final gw = (j['gameweek'] as Map<String, dynamic>?) ?? const {};
    return H2HChallenge(
      id: j['id'] as String,
      tournamentId: j['tournamentId'] as String,
      gameweekId: j['gameweekId'] as String,
      gameweekName: (gw['name'] as String?) ?? 'Gameweek',
      lockAt: DateTime.parse((gw['lockAt'] as String?) ?? DateTime.now().toIso8601String()),
      challenger: H2HUserSummary.fromJson(j['challenger'] as Map<String, dynamic>),
      opponent: j['opponent'] == null
          ? null
          : H2HUserSummary.fromJson(j['opponent'] as Map<String, dynamic>),
      inviteToken: j['inviteToken'] as String?,
      status: H2HStatus.values.byName(j['status'] as String),
      challengerScore: ((j['challengerScore'] as num?) ?? 0).toDouble(),
      opponentScore: ((j['opponentScore'] as num?) ?? 0).toDouble(),
      winnerId: j['winnerId'] as String?,
      message: j['message'] as String?,
    );
  }
  final String id;
  final String tournamentId;
  final String gameweekId;
  final String gameweekName;
  final DateTime lockAt;
  final H2HUserSummary challenger;
  final H2HUserSummary? opponent;
  final String? inviteToken;
  final H2HStatus status;
  final double challengerScore;
  final double opponentScore;
  final String? winnerId;
  final String? message;
}

class H2HInvitePreview {
  H2HInvitePreview({
    required this.id,
    required this.status,
    required this.challenger,
    required this.gameweekName,
    required this.lockAt,
    required this.tournamentName,
    required this.claimed,
    required this.expired,
    this.message,
  });
  factory H2HInvitePreview.fromJson(Map<String, dynamic> j) {
    final gw = (j['gameweek'] as Map<String, dynamic>?) ?? const {};
    final t = (j['tournament'] as Map<String, dynamic>?) ?? const {};
    return H2HInvitePreview(
      id: j['id'] as String,
      status: H2HStatus.values.byName(j['status'] as String),
      challenger: H2HUserSummary.fromJson(j['challenger'] as Map<String, dynamic>),
      gameweekName: (gw['name'] as String?) ?? 'Gameweek',
      lockAt: DateTime.parse((gw['lockAt'] as String?) ?? DateTime.now().toIso8601String()),
      tournamentName: (t['name'] as String?) ?? 'Tournament',
      claimed: j['claimed'] as bool? ?? false,
      expired: j['expired'] as bool? ?? false,
      message: j['message'] as String?,
    );
  }
  final String id;
  final H2HStatus status;
  final H2HUserSummary challenger;
  final String gameweekName;
  final DateTime lockAt;
  final String tournamentName;
  final bool claimed;
  final bool expired;
  final String? message;
}

class H2HLadderRow {
  H2HLadderRow({
    required this.rank,
    required this.userId,
    required this.wins,
    required this.played,
    this.displayName,
    this.photoUrl,
    this.userTag,
    this.countryCode,
  });
  factory H2HLadderRow.fromJson(Map<String, dynamic> j) => H2HLadderRow(
        rank: (j['rank'] as num).toInt(),
        userId: j['userId'] as String,
        wins: (j['wins'] as num?)?.toInt() ?? 0,
        played: (j['played'] as num?)?.toInt() ?? 0,
        displayName: j['displayName'] as String?,
        photoUrl: j['photoUrl'] as String?,
        userTag: j['userTag'] as String?,
        countryCode: j['countryCode'] as String?,
      );
  final int rank;
  final String userId;
  final int wins;
  final int played;
  final String? displayName;
  final String? photoUrl;
  final String? userTag;
  final String? countryCode;
}

class H2HRepository {
  H2HRepository(this._dio);
  final Dio _dio;

  Future<List<H2HChallenge>> list({H2HStatus? status}) async {
    final res = await _dio.get<List<dynamic>>(
      '/v1/h2h',
      queryParameters: {if (status != null) 'status': status.name},
    );
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(H2HChallenge.fromJson)
        .toList(growable: false);
  }

  Future<H2HChallenge> propose({String? opponentId, required String gameweekId, String? message}) async {
    final res = await _dio.post<Map<String, dynamic>>('/v1/h2h', data: {
      if (opponentId != null) 'opponentId': opponentId,
      'gameweekId': gameweekId,
      if (message != null) 'message': message,
    });
    return H2HChallenge.fromJson(res.data!);
  }

  Future<H2HInvitePreview> invitePreview(String token) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/h2h/invite/$token');
    return H2HInvitePreview.fromJson(res.data!);
  }

  Future<H2HChallenge> acceptInvite(String token) async {
    final res = await _dio.post<Map<String, dynamic>>('/v1/h2h/invite/$token/accept');
    return H2HChallenge.fromJson(res.data!);
  }

  Future<List<H2HLadderRow>> ladder({String? tournamentId}) async {
    final res = await _dio.get<List<dynamic>>('/v1/h2h/ladder', queryParameters: {
      if (tournamentId != null) 'tournamentId': tournamentId,
    });
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(H2HLadderRow.fromJson)
        .toList(growable: false);
  }

  Future<void> accept(String id)  => _dio.post('/v1/h2h/$id/accept');
  Future<void> decline(String id) => _dio.post('/v1/h2h/$id/decline');
  Future<void> cancel(String id)  => _dio.post('/v1/h2h/$id/cancel');
}

final h2hRepositoryProvider = Provider<H2HRepository>((ref) => H2HRepository(ref.read(dioProvider)));
final h2hListProvider = FutureProvider<List<H2HChallenge>>((ref) => ref.read(h2hRepositoryProvider).list());
final h2hLadderProvider = FutureProvider<List<H2HLadderRow>>(
    (ref) => ref.read(h2hRepositoryProvider).ladder());
final h2hInvitePreviewProvider = FutureProvider.family<H2HInvitePreview, String>(
    (ref, token) => ref.read(h2hRepositoryProvider).invitePreview(token));
