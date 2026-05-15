class TeamMatchStatsDto {
  TeamMatchStatsDto({required this.teamId, required this.teamName, this.teamLogo, required this.stats});

  factory TeamMatchStatsDto.fromJson(Map<String, dynamic> j) {
    final team = (j['team'] as Map?)?.cast<String, dynamic>() ?? const {};
    final stats = ((j['statistics'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map<MapEntry<String, num?>>((s) => MapEntry(
              (s['type'] as String?) ?? '',
              _parseValue(s['value']),
            ))
        .toList();
    return TeamMatchStatsDto(
      teamId: '${team['id'] ?? ''}',
      teamName: (team['name'] as String?) ?? '',
      teamLogo: team['logo'] as String?,
      stats: { for (final e in stats) e.key: e.value },
    );
  }

  final String teamId;
  final String teamName;
  final String? teamLogo;
  final Map<String, num?> stats;

  num? operator [](String key) => stats[key];
}

num? _parseValue(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) {
    final cleaned = v.replaceAll('%', '').trim();
    return num.tryParse(cleaned);
  }
  return null;
}
