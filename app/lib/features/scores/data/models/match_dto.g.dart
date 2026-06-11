// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TeamDto _$TeamDtoFromJson(Map<String, dynamic> json) => _TeamDto(
  id: json['id'] as String,
  name: json['name'] as String,
  shortName: json['shortName'] as String?,
  crestUrl: json['crestUrl'] as String?,
);

Map<String, dynamic> _$TeamDtoToJson(_TeamDto instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'shortName': instance.shortName,
  'crestUrl': instance.crestUrl,
};

_MatchDto _$MatchDtoFromJson(Map<String, dynamic> json) => _MatchDto(
  id: json['id'] as String,
  competitionId: json['competitionId'] as String,
  homeTeam: TeamDto.fromJson(json['homeTeam'] as Map<String, dynamic>),
  awayTeam: TeamDto.fromJson(json['awayTeam'] as Map<String, dynamic>),
  kickoffAt: DateTime.parse(json['kickoffAt'] as String),
  status: $enumDecode(_$MatchStatusEnumMap, json['status']),
  minute: (json['minute'] as num?)?.toInt(),
  minuteExtra: (json['minuteExtra'] as num?)?.toInt(),
  homeScore: (json['homeScore'] as num?)?.toInt() ?? 0,
  awayScore: (json['awayScore'] as num?)?.toInt() ?? 0,
  homePenalties: (json['homePenalties'] as num?)?.toInt(),
  awayPenalties: (json['awayPenalties'] as num?)?.toInt(),
  stage: json['stage'] as String?,
  venue: json['venue'] as String?,
);

Map<String, dynamic> _$MatchDtoToJson(_MatchDto instance) => <String, dynamic>{
  'id': instance.id,
  'competitionId': instance.competitionId,
  'homeTeam': instance.homeTeam,
  'awayTeam': instance.awayTeam,
  'kickoffAt': instance.kickoffAt.toIso8601String(),
  'status': _$MatchStatusEnumMap[instance.status]!,
  'minute': instance.minute,
  'minuteExtra': instance.minuteExtra,
  'homeScore': instance.homeScore,
  'awayScore': instance.awayScore,
  'homePenalties': instance.homePenalties,
  'awayPenalties': instance.awayPenalties,
  'stage': instance.stage,
  'venue': instance.venue,
};

const _$MatchStatusEnumMap = {
  MatchStatus.SCHEDULED: 'SCHEDULED',
  MatchStatus.LIVE: 'LIVE',
  MatchStatus.HALF_TIME: 'HALF_TIME',
  MatchStatus.FINISHED: 'FINISHED',
  MatchStatus.POSTPONED: 'POSTPONED',
  MatchStatus.CANCELLED: 'CANCELLED',
};

_MatchUpdate _$MatchUpdateFromJson(Map<String, dynamic> json) => _MatchUpdate(
  id: json['id'] as String,
  status: $enumDecode(_$MatchStatusEnumMap, json['status']),
  minute: (json['minute'] as num?)?.toInt(),
  minuteExtra: (json['minuteExtra'] as num?)?.toInt(),
  homeScore: (json['homeScore'] as num).toInt(),
  awayScore: (json['awayScore'] as num).toInt(),
  homePenalties: (json['homePenalties'] as num?)?.toInt(),
  awayPenalties: (json['awayPenalties'] as num?)?.toInt(),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$MatchUpdateToJson(_MatchUpdate instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': _$MatchStatusEnumMap[instance.status]!,
      'minute': instance.minute,
      'minuteExtra': instance.minuteExtra,
      'homeScore': instance.homeScore,
      'awayScore': instance.awayScore,
      'homePenalties': instance.homePenalties,
      'awayPenalties': instance.awayPenalties,
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
