import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';

class GemBalance {
  GemBalance({required this.balance, required this.canClaimDaily});
  final int balance;
  final bool canClaimDaily;
  factory GemBalance.fromJson(Map<String, dynamic> j) => GemBalance(
        balance: (j['balance'] as num?)?.toInt() ?? 0,
        canClaimDaily: j['canClaimDaily'] as bool? ?? false,
      );
}

class GemDailyResult {
  GemDailyResult({
    required this.balance,
    required this.awarded,
    required this.nextClaimAt,
  });
  final int balance;
  final int awarded;
  final DateTime nextClaimAt;
  factory GemDailyResult.fromJson(Map<String, dynamic> j) => GemDailyResult(
        balance: (j['balance'] as num?)?.toInt() ?? 0,
        awarded: (j['awarded'] as num?)?.toInt() ?? 0,
        nextClaimAt: DateTime.parse(j['nextClaimAt'] as String),
      );
}

class GemTxn {
  GemTxn({
    required this.id,
    required this.amount,
    required this.source,
    required this.balanceAfter,
    required this.createdAt,
    this.description,
    this.refType,
    this.refId,
  });
  final String id;
  final int amount;
  final String source;
  final int balanceAfter;
  final DateTime createdAt;
  final String? description;
  final String? refType;
  final String? refId;
  factory GemTxn.fromJson(Map<String, dynamic> j) => GemTxn(
        id: j['id'] as String,
        amount: (j['amount'] as num).toInt(),
        source: j['source'] as String,
        balanceAfter: (j['balanceAfter'] as num).toInt(),
        createdAt: DateTime.parse(j['createdAt'] as String),
        description: j['description'] as String?,
        refType: j['refType'] as String?,
        refId: j['refId'] as String?,
      );
}

class GemHistoryPage {
  GemHistoryPage({required this.rows, this.nextCursor});
  final List<GemTxn> rows;
  final String? nextCursor;
}

class GemCatalog {
  GemCatalog({
    required this.packs,
    required this.profileFlair,
    required this.captainReroll,
    required this.earnRules,
  });
  final Map<String, int> packs; // bronze/silver/gold
  final int profileFlair;
  final int captainReroll;
  final Map<String, dynamic> earnRules;

  factory GemCatalog.fromJson(Map<String, dynamic> j) => GemCatalog(
        packs: ((j['packs'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        profileFlair: (j['profileFlair'] as num?)?.toInt() ?? 0,
        captainReroll: (j['captainReroll'] as num?)?.toInt() ?? 0,
        earnRules: Map<String, dynamic>.from(j['earnRules'] as Map? ?? const {}),
      );
}

class GemsRepository {
  GemsRepository(this._dio);
  final Dio _dio;

  Future<GemBalance> balance() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/gems/me');
    return GemBalance.fromJson(res.data!);
  }

  Future<GemCatalog> catalog() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/gems/catalog');
    return GemCatalog.fromJson(res.data!);
  }

  Future<GemHistoryPage> history({String? cursor, int limit = 50}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/gems/history',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );
    final data = res.data!;
    return GemHistoryPage(
      rows: ((data['rows'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(GemTxn.fromJson)
          .toList(growable: false),
      nextCursor: data['nextCursor'] as String?,
    );
  }

  Future<GemDailyResult> claimDaily() async {
    final res = await _dio.post<Map<String, dynamic>>('/v1/gems/daily');
    return GemDailyResult.fromJson(res.data!);
  }
}

final gemsRepositoryProvider =
    Provider<GemsRepository>((ref) => GemsRepository(ref.read(dioProvider)));

final gemBalanceProvider = FutureProvider<GemBalance>(
    (ref) => ref.read(gemsRepositoryProvider).balance());

final gemCatalogProvider = FutureProvider<GemCatalog>(
    (ref) => ref.read(gemsRepositoryProvider).catalog());

final gemHistoryProvider =
    FutureProvider<GemHistoryPage>((ref) => ref.read(gemsRepositoryProvider).history());
