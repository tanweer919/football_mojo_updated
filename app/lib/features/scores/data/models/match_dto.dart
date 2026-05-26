import 'package:freezed_annotation/freezed_annotation.dart';

part 'match_dto.freezed.dart';
part 'match_dto.g.dart';

enum MatchStatus {
  SCHEDULED,
  LIVE,
  HALF_TIME,
  FINISHED,
  POSTPONED,
  CANCELLED,
}

@freezed
abstract class TeamDto with _$TeamDto {
  const factory TeamDto({
    required String id,
    required String name,
    String? shortName,
    String? crestUrl,
  }) = _TeamDto;

  factory TeamDto.fromJson(Map<String, dynamic> json) => _$TeamDtoFromJson(json);
}

@freezed
abstract class MatchDto with _$MatchDto {
  const MatchDto._();

  const factory MatchDto({
    required String id,
    required String competitionId,
    required TeamDto homeTeam,
    required TeamDto awayTeam,
    required DateTime kickoffAt,
    required MatchStatus status,
    int? minute,
    @Default(0) int homeScore,
    @Default(0) int awayScore,
    int? homePenalties,
    int? awayPenalties,
    String? stage,
    String? venue,
  }) = _MatchDto;

  factory MatchDto.fromJson(Map<String, dynamic> json) => _$MatchDtoFromJson(json);

  bool get isLive => status == MatchStatus.LIVE || status == MatchStatus.HALF_TIME;
  bool get isFinished => status == MatchStatus.FINISHED;
  String get scoreLabel => '$homeScore - $awayScore';
}

// Partial WebSocket payload from CHANNELS.matchUpdate — applies a delta to an existing MatchDto.
@freezed
abstract class MatchUpdate with _$MatchUpdate {
  const factory MatchUpdate({
    required String id,
    required MatchStatus status,
    int? minute,
    required int homeScore,
    required int awayScore,
    int? homePenalties,
    int? awayPenalties,
    required DateTime updatedAt,
  }) = _MatchUpdate;

  factory MatchUpdate.fromJson(Map<String, dynamic> json) => _$MatchUpdateFromJson(json);
}
