import 'package:freezed_annotation/freezed_annotation.dart';

part 'fantasy_models.freezed.dart';
part 'fantasy_models.g.dart';

enum PlayerPosition { GK, DEF, MID, FWD }

enum FantasyFormat { GLOBAL_CUP, FRIENDLY, H2H }

@freezed
abstract class FantasyTournamentDto with _$FantasyTournamentDto {
  const factory FantasyTournamentDto({
    required String id,
    required String slug,
    required String name,
    required FantasyFormat format,
    required double budget,
    String? description,
    String? emblemUrl,
    required DateTime startsAt,
    required DateTime endsAt,
    @Default(<FantasyGameweekDto>[]) List<FantasyGameweekDto> gameweeks,
  }) = _FantasyTournamentDto;

  factory FantasyTournamentDto.fromJson(Map<String, dynamic> json) =>
      _$FantasyTournamentDtoFromJson(json);
}

@freezed
abstract class FantasyGameweekDto with _$FantasyGameweekDto {
  const FantasyGameweekDto._();
  const factory FantasyGameweekDto({
    required String id,
    required int number,
    required String name,
    required DateTime lockAt,
    required DateTime endsAt,
    @Default(false) bool scored,
  }) = _FantasyGameweekDto;

  factory FantasyGameweekDto.fromJson(Map<String, dynamic> json) =>
      _$FantasyGameweekDtoFromJson(json);

  bool get isLocked => DateTime.now().isAfter(lockAt);
  Duration get untilLock => lockAt.difference(DateTime.now());
}

@freezed
abstract class PlayerValuationDto with _$PlayerValuationDto {
  const factory PlayerValuationDto({
    required String id,
    required String playerId,
    required double price,
    required double recentForm,
    required PlayerPosition position,
    required PlayerSummary player,
  }) = _PlayerValuationDto;

  factory PlayerValuationDto.fromJson(Map<String, dynamic> json) =>
      _$PlayerValuationDtoFromJson(json);
}

@freezed
abstract class PlayerSummary with _$PlayerSummary {
  const factory PlayerSummary({
    required String id,
    required String name,
    // Backend Prisma model is `Int?` — keep it numeric here.
    int? shirtNumber,
    String? photoUrl,
    String? position,
    required TeamSummary team,
  }) = _PlayerSummary;

  factory PlayerSummary.fromJson(Map<String, dynamic> json) => _$PlayerSummaryFromJson(json);
}

@freezed
abstract class TeamSummary with _$TeamSummary {
  const factory TeamSummary({
    required String id,
    required String name,
    String? shortName,
    String? crestUrl,
  }) = _TeamSummary;

  factory TeamSummary.fromJson(Map<String, dynamic> json) => _$TeamSummaryFromJson(json);
}

@freezed
abstract class LineupPick with _$LineupPick {
  const factory LineupPick({
    required String playerId,
    required PlayerPosition position,
    @Default(false) bool isCaptain,
  }) = _LineupPick;

  factory LineupPick.fromJson(Map<String, dynamic> json) => _$LineupPickFromJson(json);
}

@freezed
abstract class FantasyLineupDto with _$FantasyLineupDto {
  const factory FantasyLineupDto({
    required String id,
    required String userId,
    required String gameweekId,
    required List<LineupPick> picks,
    required String captainId,
    required double budgetUsed,
    @Default(false) bool locked,
    @Default(0) double totalPoints,
    int? rank,
  }) = _FantasyLineupDto;

  factory FantasyLineupDto.fromJson(Map<String, dynamic> json) => _$FantasyLineupDtoFromJson(json);
}

@freezed
abstract class LeaderboardEntry with _$LeaderboardEntry {
  const factory LeaderboardEntry({
    required int rank,
    required String userId,
    String? displayName,
    String? photoUrl,
    required double points,
    double? budgetUsed,
    int? lineups,
  }) = _LeaderboardEntry;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => _$LeaderboardEntryFromJson(json);
}
