import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'world_cup_models.dart';

class WorldCupRepository {
  WorldCupRepository(this._dio);
  final Dio _dio;

  Future<WcOverview> overview(String competitionId) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/competitions/$competitionId/overview');
    return WcOverview.fromJson(res.data!);
  }

  Future<List<WcGroup>> groups(String competitionId) async {
    final res = await _dio.get<List<dynamic>>('/v1/competitions/$competitionId/groups');
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(WcGroup.fromJson)
        .toList(growable: false);
  }
}

final worldCupRepositoryProvider = Provider<WorldCupRepository>((ref) {
  return WorldCupRepository(ref.read(dioProvider));
});

final wcOverviewProvider = FutureProvider.family<WcOverview, String>((ref, id) {
  return ref.read(worldCupRepositoryProvider).overview(id);
});

final wcGroupsProvider = FutureProvider.family<List<WcGroup>, String>((ref, id) {
  return ref.read(worldCupRepositoryProvider).groups(id);
});
