// Match event from api-football /fixtures/events.
// Loose JSON — hand-written for stability.

enum EventKind { goal, ownGoal, penalty, penaltyMissed, yellow, red, sub, varCheck, unknown }

class MatchEventDto {
  MatchEventDto({
    required this.minute,
    this.extraMinute,
    required this.teamId,
    required this.teamName,
    this.teamLogo,
    this.playerId,
    this.playerName,
    this.assistName,
    required this.kind,
    required this.detail,
  });

  factory MatchEventDto.fromJson(Map<String, dynamic> j) {
    final time   = (j['time']   as Map?)?.cast<String, dynamic>() ?? const {};
    final team   = (j['team']   as Map?)?.cast<String, dynamic>() ?? const {};
    final player = (j['player'] as Map?)?.cast<String, dynamic>() ?? const {};
    final assist = (j['assist'] as Map?)?.cast<String, dynamic>() ?? const {};
    final type   = (j['type']   as String?) ?? '';
    final detail = (j['detail'] as String?) ?? '';
    return MatchEventDto(
      minute: (time['elapsed'] as int?) ?? 0,
      extraMinute: time['extra'] as int?,
      teamId: '${team['id'] ?? ''}',
      teamName: (team['name'] as String?) ?? '',
      teamLogo: team['logo'] as String?,
      playerId: player['id'] == null ? null : '${player['id']}',
      playerName: player['name'] as String?,
      assistName: assist['name'] as String?,
      kind: _classify(type, detail),
      detail: detail,
    );
  }

  final int minute;
  final int? extraMinute;
  final String teamId;
  final String teamName;
  final String? teamLogo;
  final String? playerId;
  final String? playerName;
  final String? assistName;
  final EventKind kind;
  final String detail;

  String get displayMinute => extraMinute == null ? "$minute'" : "$minute+$extraMinute'";
}

EventKind _classify(String type, String detail) {
  final t = type.toLowerCase();
  final d = detail.toLowerCase();
  if (t == 'goal') {
    if (d.contains('own')) return EventKind.ownGoal;
    if (d.contains('penalty')) return EventKind.penalty;
    if (d.contains('missed')) return EventKind.penaltyMissed;
    return EventKind.goal;
  }
  if (t == 'card') {
    if (d.contains('red')) return EventKind.red;
    if (d.contains('yellow')) return EventKind.yellow;
  }
  if (t == 'subst') return EventKind.sub;
  if (t == 'var') return EventKind.varCheck;
  return EventKind.unknown;
}
