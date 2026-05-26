import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';

class PlayerProfileBundle {
  PlayerProfileBundle({
    required this.id,
    required this.name,
    this.firstName,
    this.lastName,
    this.photo,
    this.nationality,
    this.birthDate,
    this.height,
    this.weight,
    this.position,
    this.teamName,
    this.teamLogo,
    required this.seasonStats,
    required this.transfers,
    required this.trophies,
    required this.sidelined,
  });

  factory PlayerProfileBundle.fromJson(Map<String, dynamic> j) {
    final profile = (j['profile'] as Map?)?.cast<String, dynamic>() ?? const {};
    final player  = (profile['player'] as Map?)?.cast<String, dynamic>() ?? profile;
    final birth   = (player['birth'] as Map?)?.cast<String, dynamic>() ?? const {};

    final season = (j['season'] as Map?)?.cast<String, dynamic>();
    final stats  = ((season?['statistics'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final agg = _aggregateSeason(stats);

    String? teamName, teamLogo;
    String? mainPosition;
    if (stats.isNotEmpty) {
      final t = (stats.first['team'] as Map?)?.cast<String, dynamic>() ?? const {};
      teamName = t['name'] as String?;
      teamLogo = t['logo'] as String?;
      final g  = (stats.first['games'] as Map?)?.cast<String, dynamic>() ?? const {};
      mainPosition = g['position'] as String?;
    }

    final transfersRaw = (j['transfers'] as Map?)?.cast<String, dynamic>();
    final transfersList = ((transfersRaw?['transfers'] as List?) ?? const []).cast<Map<String, dynamic>>();

    return PlayerProfileBundle(
      id:          '${player['id'] ?? ''}',
      name:        (player['name'] as String?) ?? '',
      firstName:   player['firstname'] as String?,
      lastName:    player['lastname']  as String?,
      photo:       player['photo']     as String?,
      nationality: player['nationality'] as String?,
      birthDate:   birth['date'] as String?,
      height:      player['height'] as String?,
      weight:      player['weight'] as String?,
      position:    mainPosition,
      teamName:    teamName,
      teamLogo:    teamLogo,
      seasonStats: agg,
      transfers:   transfersList.map(PlayerTransfer.fromJson).toList(),
      trophies:    ((j['trophies'] as List?) ?? const []).cast<Map<String, dynamic>>().map(PlayerTrophy.fromJson).toList(),
      sidelined:   ((j['sidelined'] as List?) ?? const []).cast<Map<String, dynamic>>().map(PlayerSidelined.fromJson).toList(),
    );
  }

  final String id;
  final String name;
  final String? firstName, lastName;
  final String? photo;
  final String? nationality;
  final String? birthDate;
  final String? height, weight;
  final String? position;
  final String? teamName;
  final String? teamLogo;
  final SeasonAggregate seasonStats;
  final List<PlayerTransfer> transfers;
  final List<PlayerTrophy> trophies;
  final List<PlayerSidelined> sidelined;
}

class SeasonAggregate {
  SeasonAggregate({
    required this.appearances,
    required this.minutes,
    required this.goals,
    required this.assists,
    required this.yellow,
    required this.red,
    required this.shotsOnTarget,
    required this.passAccuracy,
    required this.rating,
  });
  final int appearances, minutes, goals, assists, yellow, red, shotsOnTarget;
  final double passAccuracy;       // 0..1
  final double rating;             // average across stat blocks
}

SeasonAggregate _aggregateSeason(List<Map<String, dynamic>> stats) {
  var apps = 0, mins = 0, g = 0, a = 0, y = 0, r = 0, sot = 0;
  var paSum = 0.0, paN = 0, ratingSum = 0.0, ratingN = 0;
  for (final s in stats) {
    final games  = (s['games']  as Map?)?.cast<String, dynamic>() ?? const {};
    final goals  = (s['goals']  as Map?)?.cast<String, dynamic>() ?? const {};
    final cards  = (s['cards']  as Map?)?.cast<String, dynamic>() ?? const {};
    final shots  = (s['shots']  as Map?)?.cast<String, dynamic>() ?? const {};
    final passes = (s['passes'] as Map?)?.cast<String, dynamic>() ?? const {};

    apps += (games['appearences'] as int?) ?? 0;
    mins += (games['minutes']    as int?) ?? 0;
    g    += (goals['total']      as int?) ?? 0;
    a    += (goals['assists']    as int?) ?? 0;
    y    += (cards['yellow']     as int?) ?? 0;
    r    += (cards['red']        as int?) ?? 0;
    sot  += (shots['on']         as int?) ?? 0;
    final pAcc = passes['accuracy'];
    if (pAcc != null) {
      final n = num.tryParse(pAcc.toString());
      if (n != null) { paSum += n.toDouble(); paN++; }
    }
    final rt = games['rating'];
    if (rt != null) {
      final n = num.tryParse(rt.toString());
      if (n != null) { ratingSum += n.toDouble(); ratingN++; }
    }
  }
  return SeasonAggregate(
    appearances: apps, minutes: mins, goals: g, assists: a,
    yellow: y, red: r, shotsOnTarget: sot,
    passAccuracy: paN == 0 ? 0 : (paSum / paN) / 100,
    rating: ratingN == 0 ? 0 : ratingSum / ratingN,
  );
}

class PlayerTransfer {
  PlayerTransfer({required this.date, required this.type, required this.from, required this.to});
  factory PlayerTransfer.fromJson(Map<String, dynamic> j) {
    final teams = (j['teams'] as Map?)?.cast<String, dynamic>() ?? const {};
    final out   = (teams['out'] as Map?)?.cast<String, dynamic>() ?? const {};
    final ins   = (teams['in']  as Map?)?.cast<String, dynamic>() ?? const {};
    return PlayerTransfer(
      date: j['date'] as String? ?? '',
      type: j['type'] as String? ?? '',
      from: out['name'] as String? ?? '',
      to:   ins['name'] as String? ?? '',
    );
  }
  final String date, type, from, to;
}

class PlayerTrophy {
  PlayerTrophy({required this.competition, required this.country, required this.season, required this.place});
  factory PlayerTrophy.fromJson(Map<String, dynamic> j) => PlayerTrophy(
        competition: (j['league'] as String?) ?? '',
        country:     (j['country'] as String?) ?? '',
        season:      (j['season'] as String?) ?? '',
        place:       (j['place'] as String?) ?? '',
      );
  final String competition, country, season, place;
}

class PlayerSidelined {
  PlayerSidelined({required this.type, required this.start, required this.end});
  factory PlayerSidelined.fromJson(Map<String, dynamic> j) => PlayerSidelined(
        type:  (j['type']  as String?) ?? '',
        start: (j['start'] as String?) ?? '',
        end:   (j['end']   as String?) ?? '',
      );
  final String type, start, end;
}

class PlayerRepository {
  PlayerRepository(this._dio);
  final Dio _dio;
  Future<PlayerProfileBundle> get(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/insights/player/$id');
    return PlayerProfileBundle.fromJson(res.data!);
  }
}

final playerRepositoryProvider = Provider<PlayerRepository>((ref) => PlayerRepository(ref.read(dioProvider)));
final playerProfileProvider = FutureProvider.family<PlayerProfileBundle, String>(
  (ref, id) => ref.read(playerRepositoryProvider).get(id),
);
