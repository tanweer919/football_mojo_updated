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
    required this.opponent,
    required this.status,
    required this.challengerScore,
    required this.opponentScore,
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
      opponent: H2HUserSummary.fromJson(j['opponent'] as Map<String, dynamic>),
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
  final H2HUserSummary opponent;
  final H2HStatus status;
  final double challengerScore;
  final double opponentScore;
  final String? winnerId;
  final String? message;
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

  Future<H2HChallenge> propose({required String opponentId, required String gameweekId, String? message}) async {
    final res = await _dio.post<Map<String, dynamic>>('/v1/h2h', data: {
      'opponentId': opponentId,
      'gameweekId': gameweekId,
      if (message != null) 'message': message,
    });
    return H2HChallenge.fromJson(res.data!);
  }

  Future<void> accept(String id)  => _dio.post('/v1/h2h/$id/accept');
  Future<void> decline(String id) => _dio.post('/v1/h2h/$id/decline');
  Future<void> cancel(String id)  => _dio.post('/v1/h2h/$id/cancel');
}

final h2hRepositoryProvider = Provider<H2HRepository>((ref) => H2HRepository(ref.read(dioProvider)));
final h2hListProvider = FutureProvider<List<H2HChallenge>>((ref) => ref.read(h2hRepositoryProvider).list());
