import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';

class StandingRow {
  StandingRow({
    required this.position,
    required this.teamId,
    required this.teamName,
    this.teamLogo,
    required this.played,
    required this.win,
    required this.draw,
    required this.lose,
    required this.gf,
    required this.ga,
    required this.points,
    this.form,
  });
  factory StandingRow.fromJson(Map<String, dynamic> j) {
    final team = (j['team'] as Map?)?.cast<String, dynamic>() ?? const {};
    final all  = (j['all']  as Map?)?.cast<String, dynamic>() ?? const {};
    final goals = (all['goals'] as Map?)?.cast<String, dynamic>() ?? const {};
    return StandingRow(
      position: (j['rank'] as int?) ?? 0,
      teamId:   '${team['id'] ?? ''}',
      teamName: (team['name'] as String?) ?? '',
      teamLogo:  team['logo'] as String?,
      played:   (all['played'] as int?) ?? 0,
      win:      (all['win']  as int?) ?? 0,
      draw:     (all['draw'] as int?) ?? 0,
      lose:     (all['lose'] as int?) ?? 0,
      gf:       (goals['for']     as int?) ?? 0,
      ga:       (goals['against'] as int?) ?? 0,
      points:   (j['points'] as int?) ?? 0,
      form:     j['form'] as String?,
    );
  }
  final int position;
  final String teamId;
  final String teamName;
  final String? teamLogo;
  final int played, win, draw, lose, gf, ga, points;
  final String? form;
  int get gd => gf - ga;
}

class StandingsGroup {
  StandingsGroup({required this.name, required this.rows});
  final String name;
  final List<StandingRow> rows;
}

class StandingsRepository {
  StandingsRepository(this._dio);
  final Dio _dio;
  Future<List<StandingsGroup>> fetch() async {
    // /v1/insights/standings returns [{ league: { standings: [[row, row, ...], [...]] } }]
    final res = await _dio.get<List<dynamic>>('/v1/insights/standings');
    final list = (res.data ?? const []).cast<Map<String, dynamic>>();
    if (list.isEmpty) return [];
    final league = (list.first['league'] as Map?)?.cast<String, dynamic>() ?? const {};
    final groupsRaw = (league['standings'] as List?) ?? const [];
    final groups = <StandingsGroup>[];
    for (final g in groupsRaw) {
      final rowsRaw = (g as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (rowsRaw.isEmpty) continue;
      final rows = rowsRaw.map(StandingRow.fromJson).toList();
      final groupName = rowsRaw.first['group'] as String? ?? rows.first.teamName;
      groups.add(StandingsGroup(name: groupName, rows: rows));
    }
    return groups;
  }
}

final standingsRepositoryProvider = Provider<StandingsRepository>((ref) => StandingsRepository(ref.read(dioProvider)));
final standingsProvider = FutureProvider<List<StandingsGroup>>((ref) => ref.read(standingsRepositoryProvider).fetch());
