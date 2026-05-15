// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fantasy_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FantasyTournamentDto _$FantasyTournamentDtoFromJson(
  Map<String, dynamic> json,
) => _FantasyTournamentDto(
  id: json['id'] as String,
  slug: json['slug'] as String,
  name: json['name'] as String,
  format: $enumDecode(_$FantasyFormatEnumMap, json['format']),
  budget: (json['budget'] as num).toDouble(),
  description: json['description'] as String?,
  emblemUrl: json['emblemUrl'] as String?,
  startsAt: DateTime.parse(json['startsAt'] as String),
  endsAt: DateTime.parse(json['endsAt'] as String),
  gameweeks:
      (json['gameweeks'] as List<dynamic>?)
          ?.map((e) => FantasyGameweekDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <FantasyGameweekDto>[],
);

Map<String, dynamic> _$FantasyTournamentDtoToJson(
  _FantasyTournamentDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'slug': instance.slug,
  'name': instance.name,
  'format': _$FantasyFormatEnumMap[instance.format]!,
  'budget': instance.budget,
  'description': instance.description,
  'emblemUrl': instance.emblemUrl,
  'startsAt': instance.startsAt.toIso8601String(),
  'endsAt': instance.endsAt.toIso8601String(),
  'gameweeks': instance.gameweeks,
};

const _$FantasyFormatEnumMap = {
  FantasyFormat.GLOBAL_CUP: 'GLOBAL_CUP',
  FantasyFormat.FRIENDLY: 'FRIENDLY',
  FantasyFormat.H2H: 'H2H',
};

_FantasyGameweekDto _$FantasyGameweekDtoFromJson(Map<String, dynamic> json) =>
    _FantasyGameweekDto(
      id: json['id'] as String,
      number: (json['number'] as num).toInt(),
      name: json['name'] as String,
      lockAt: DateTime.parse(json['lockAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      scored: json['scored'] as bool? ?? false,
    );

Map<String, dynamic> _$FantasyGameweekDtoToJson(_FantasyGameweekDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'number': instance.number,
      'name': instance.name,
      'lockAt': instance.lockAt.toIso8601String(),
      'endsAt': instance.endsAt.toIso8601String(),
      'scored': instance.scored,
    };

_PlayerValuationDto _$PlayerValuationDtoFromJson(Map<String, dynamic> json) =>
    _PlayerValuationDto(
      id: json['id'] as String,
      playerId: json['playerId'] as String,
      price: (json['price'] as num).toDouble(),
      recentForm: (json['recentForm'] as num).toDouble(),
      position: $enumDecode(_$PlayerPositionEnumMap, json['position']),
      player: PlayerSummary.fromJson(json['player'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PlayerValuationDtoToJson(_PlayerValuationDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'playerId': instance.playerId,
      'price': instance.price,
      'recentForm': instance.recentForm,
      'position': _$PlayerPositionEnumMap[instance.position]!,
      'player': instance.player,
    };

const _$PlayerPositionEnumMap = {
  PlayerPosition.GK: 'GK',
  PlayerPosition.DEF: 'DEF',
  PlayerPosition.MID: 'MID',
  PlayerPosition.FWD: 'FWD',
};

_PlayerSummary _$PlayerSummaryFromJson(Map<String, dynamic> json) =>
    _PlayerSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      shirtNumber: (json['shirtNumber'] as num?)?.toInt(),
      photoUrl: json['photoUrl'] as String?,
      position: json['position'] as String?,
      team: TeamSummary.fromJson(json['team'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PlayerSummaryToJson(_PlayerSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'shirtNumber': instance.shirtNumber,
      'photoUrl': instance.photoUrl,
      'position': instance.position,
      'team': instance.team,
    };

_TeamSummary _$TeamSummaryFromJson(Map<String, dynamic> json) => _TeamSummary(
  id: json['id'] as String,
  name: json['name'] as String,
  shortName: json['shortName'] as String?,
  crestUrl: json['crestUrl'] as String?,
);

Map<String, dynamic> _$TeamSummaryToJson(_TeamSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'shortName': instance.shortName,
      'crestUrl': instance.crestUrl,
    };

_LineupPick _$LineupPickFromJson(Map<String, dynamic> json) => _LineupPick(
  playerId: json['playerId'] as String,
  position: $enumDecode(_$PlayerPositionEnumMap, json['position']),
  isCaptain: json['isCaptain'] as bool? ?? false,
);

Map<String, dynamic> _$LineupPickToJson(_LineupPick instance) =>
    <String, dynamic>{
      'playerId': instance.playerId,
      'position': _$PlayerPositionEnumMap[instance.position]!,
      'isCaptain': instance.isCaptain,
    };

_FantasyLineupDto _$FantasyLineupDtoFromJson(Map<String, dynamic> json) =>
    _FantasyLineupDto(
      id: json['id'] as String,
      userId: json['userId'] as String,
      gameweekId: json['gameweekId'] as String,
      picks:
          (json['picks'] as List<dynamic>)
              .map((e) => LineupPick.fromJson(e as Map<String, dynamic>))
              .toList(),
      captainId: json['captainId'] as String,
      budgetUsed: (json['budgetUsed'] as num).toDouble(),
      locked: json['locked'] as bool? ?? false,
      totalPoints: (json['totalPoints'] as num?)?.toDouble() ?? 0,
      rank: (json['rank'] as num?)?.toInt(),
    );

Map<String, dynamic> _$FantasyLineupDtoToJson(_FantasyLineupDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'gameweekId': instance.gameweekId,
      'picks': instance.picks,
      'captainId': instance.captainId,
      'budgetUsed': instance.budgetUsed,
      'locked': instance.locked,
      'totalPoints': instance.totalPoints,
      'rank': instance.rank,
    };

_LeaderboardEntry _$LeaderboardEntryFromJson(Map<String, dynamic> json) =>
    _LeaderboardEntry(
      rank: (json['rank'] as num).toInt(),
      userId: json['userId'] as String,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      points: (json['points'] as num).toDouble(),
      budgetUsed: (json['budgetUsed'] as num?)?.toDouble(),
      lineups: (json['lineups'] as num?)?.toInt(),
    );

Map<String, dynamic> _$LeaderboardEntryToJson(_LeaderboardEntry instance) =>
    <String, dynamic>{
      'rank': instance.rank,
      'userId': instance.userId,
      'displayName': instance.displayName,
      'photoUrl': instance.photoUrl,
      'points': instance.points,
      'budgetUsed': instance.budgetUsed,
      'lineups': instance.lineups,
    };
