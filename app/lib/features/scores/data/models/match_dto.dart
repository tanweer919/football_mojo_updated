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
    int? minuteExtra,
    @Default(0) int homeScore,
    @Default(0) int awayScore,
    int? homePenalties,
    int? awayPenalties,
    String? stage,
    String? venue,
    String? highlightUrl,
  }) = _MatchDto;

  factory MatchDto.fromJson(Map<String, dynamic> json) => _$MatchDtoFromJson(json);

  bool get isLive => status == MatchStatus.LIVE || status == MatchStatus.HALF_TIME;
  bool get isFinished => status == MatchStatus.FINISHED;
  String get scoreLabel => '$homeScore - $awayScore';

  /// True when a FIFA-official highlight is available to watch in-app.
  bool get hasHighlight => isFinished && (highlightUrl?.isNotEmpty ?? false);

  /// Clock label with stoppage time, e.g. `45+4'` (or `45'`). Callers render
  /// HALF_TIME as "HT" separately.
  ///
  /// Only show `+extra` when there's a real base minute — api-football
  /// sometimes sends `extra` with a null/0 `elapsed`, which would otherwise
  /// render the nonsensical `0+3'`.
  String get minuteLabel {
    final m = minute ?? 0;
    final x = minuteExtra;
    return (x != null && x > 0 && m > 0) ? "$m+$x'" : "$m'";
  }
}

// Partial WebSocket payload from CHANNELS.matchUpdate — applies a delta to an existing MatchDto.
@freezed
abstract class MatchUpdate with _$MatchUpdate {
  const factory MatchUpdate({
    required String id,
    required MatchStatus status,
    int? minute,
    int? minuteExtra,
    required int homeScore,
    required int awayScore,
    int? homePenalties,
    int? awayPenalties,
    required DateTime updatedAt,
  }) = _MatchUpdate;

  factory MatchUpdate.fromJson(Map<String, dynamic> json) => _$MatchUpdateFromJson(json);
}
