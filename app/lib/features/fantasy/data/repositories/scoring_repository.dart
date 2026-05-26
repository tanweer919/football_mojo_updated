import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';

class ScoringBucket {
  ScoringBucket({required this.id, required this.name, required this.description, this.items, this.weights, this.cap, this.floor});
  factory ScoringBucket.fromJson(Map<String, dynamic> j) => ScoringBucket(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String,
        items: (j['items'] as List?)?.cast<Map<String, dynamic>>(),
        weights: j['weights'] as Map<String, dynamic>?,
        cap: (j['cap'] as num?)?.toDouble(),
        floor: (j['floor'] as num?)?.toDouble(),
      );
  final String id;
  final String name;
  final String description;
  final List<Map<String, dynamic>>? items;     // simple key/label/value
  final Map<String, dynamic>? weights;         // structured weights table
  final double? cap;
  final double? floor;
}

class ScoringRules {
  ScoringRules({required this.squad, required this.total, required this.buckets});
  factory ScoringRules.fromJson(Map<String, dynamic> j) => ScoringRules(
        squad: j['squad'] as Map<String, dynamic>,
        total: j['total'] as Map<String, dynamic>,
        buckets: (j['buckets'] as List).cast<Map<String, dynamic>>().map(ScoringBucket.fromJson).toList(),
      );
  final Map<String, dynamic> squad;
  final Map<String, dynamic> total;
  final List<ScoringBucket> buckets;
}

class PlayerBreakdownEntry {
  PlayerBreakdownEntry({required this.key, required this.bucket, required this.label, required this.count, required this.points});
  factory PlayerBreakdownEntry.fromJson(Map<String, dynamic> j) => PlayerBreakdownEntry(
        key: j['key'] as String,
        bucket: j['bucket'] as String,
        label: j['label'] as String,
        count: (j['count'] as num).toInt(),
        points: (j['points'] as num).toDouble(),
      );
  final String key;
  final String bucket;
  final String label;
  final int count;
  final double points;
}

class PlayerBreakdown {
  PlayerBreakdown({
    required this.playerId,
    required this.playerName,
    required this.teamName,
    required this.position,
    required this.minutes,
    required this.total,
    required this.bucketTotals,
    required this.entries,
  });
  factory PlayerBreakdown.fromApi(Map<String, dynamic> j) {
    final breakdown = (j['breakdown'] as Map?)?.cast<String, dynamic>() ?? const {};
    final entries = ((breakdown['entries'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(PlayerBreakdownEntry.fromJson)
        .toList();
    final bucketTotals = (breakdown['bucketTotals'] as Map?)?.cast<String, dynamic>() ?? const {};
    final player = (j['player'] as Map?)?.cast<String, dynamic>() ?? const {};
    final team = (player['team'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PlayerBreakdown(
      playerId: (player['id'] as String?) ?? '',
      playerName: (player['name'] as String?) ?? '',
      teamName: (team['name'] as String?) ?? '',
      position: (player['position'] as String?) ?? 'MID',
      minutes: (j['minutesPlayed'] as num?)?.toInt() ?? 0,
      total: (j['totalPoints'] as num?)?.toDouble() ?? 0,
      bucketTotals: bucketTotals.map((k, v) => MapEntry(k, (v as num).toDouble())),
      entries: entries,
    );
  }
  final String playerId;
  final String playerName;
  final String teamName;
  final String position;
  final int minutes;
  final double total;
  final Map<String, double> bucketTotals;
  final List<PlayerBreakdownEntry> entries;
}

class ScoringRepository {
  ScoringRepository(this._dio);
  final Dio _dio;

  Future<ScoringRules> rules() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/scoring/rules');
    return ScoringRules.fromJson(res.data!);
  }

  Future<PlayerBreakdown?> breakdown(String gameweekId, String playerId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/v1/scoring/breakdown/$gameweekId/$playerId');
      return res.data == null ? null : PlayerBreakdown.fromApi(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}

final scoringRepositoryProvider = Provider<ScoringRepository>((ref) => ScoringRepository(ref.read(dioProvider)));
final scoringRulesProvider = FutureProvider<ScoringRules>((ref) => ref.read(scoringRepositoryProvider).rules());
final playerBreakdownProvider = FutureProvider.family<PlayerBreakdown?, ({String gameweekId, String playerId})>(
  (ref, args) => ref.read(scoringRepositoryProvider).breakdown(args.gameweekId, args.playerId),
);
