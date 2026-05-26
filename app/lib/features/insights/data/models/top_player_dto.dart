/// Used for both Top Scorers and Top Assists — the api-football payload is
/// identical except for which `statistics[i].goals.*` field matters.
class TopPlayerDto {
  TopPlayerDto({
    required this.playerId,
    required this.playerName,
    this.playerPhoto,
    required this.teamName,
    this.teamLogo,
    required this.statValue,
  });

  factory TopPlayerDto.fromJson(Map<String, dynamic> j, {required String statKey}) {
    final p = (j['player'] as Map?)?.cast<String, dynamic>() ?? const {};
    final stats = ((j['statistics'] as List?) ?? const []).cast<Map<String, dynamic>>();
    int total = 0;
    String teamName = '';
    String? teamLogo;
    for (final s in stats) {
      final goals = (s['goals'] as Map?)?.cast<String, dynamic>() ?? const {};
      total += ((goals[statKey] as int?) ?? 0);
      final team = (s['team'] as Map?)?.cast<String, dynamic>();
      if (team != null && teamName.isEmpty) {
        teamName = (team['name'] as String?) ?? '';
        teamLogo = team['logo'] as String?;
      }
    }
    return TopPlayerDto(
      playerId: '${p['id'] ?? ''}',
      playerName: (p['name'] as String?) ?? '',
      playerPhoto: p['photo'] as String?,
      teamName: teamName,
      teamLogo: teamLogo,
      statValue: total,
    );
  }

  final String playerId;
  final String playerName;
  final String? playerPhoto;
  final String teamName;
  final String? teamLogo;
  final int statValue;
}
