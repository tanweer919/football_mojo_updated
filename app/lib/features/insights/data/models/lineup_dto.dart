/// Lineup as returned by api-football. `grid` is a "row:col" string like "3:2"
/// where row 1 is the goalkeeper and the column count matches the formation.
class LineupPlayer {
  LineupPlayer({required this.id, required this.name, this.number, required this.pos, this.row, this.col});

  factory LineupPlayer.fromJson(Map<String, dynamic> j) {
    final p = (j['player'] as Map?)?.cast<String, dynamic>() ?? j;
    final grid = p['grid'] as String?;
    int? row, col;
    if (grid != null && grid.contains(':')) {
      final parts = grid.split(':');
      row = int.tryParse(parts[0]);
      col = int.tryParse(parts[1]);
    }
    return LineupPlayer(
      id: '${p['id'] ?? ''}',
      name: (p['name'] as String?) ?? '',
      number: p['number'] as int?,
      pos: (p['pos'] as String?) ?? '',
      row: row,
      col: col,
    );
  }

  final String id;
  final String name;
  final int? number;
  final String pos;          // 'G' | 'D' | 'M' | 'F'
  final int? row;
  final int? col;

  String get displayName {
    final parts = name.split(' ');
    return parts.length > 1 ? parts.last : name;
  }

  /// api-football omits the photo from the lineup payload but serves player
  /// headshots at a stable media URL keyed by id (same host as team logos).
  String? get photoUrl =>
      id.isEmpty ? null : 'https://media.api-sports.io/football/players/$id.png';
}

class LineupDto {
  LineupDto({
    required this.teamId,
    required this.teamName,
    this.teamLogo,
    required this.formation,
    required this.startXI,
    required this.substitutes,
    this.coachName,
  });

  factory LineupDto.fromJson(Map<String, dynamic> j) {
    final team = (j['team'] as Map?)?.cast<String, dynamic>() ?? const {};
    final coach = (j['coach'] as Map?)?.cast<String, dynamic>() ?? const {};
    final start = ((j['startXI']     as List?) ?? const []).cast<Map<String, dynamic>>();
    final subs  = ((j['substitutes'] as List?) ?? const []).cast<Map<String, dynamic>>();
    return LineupDto(
      teamId: '${team['id'] ?? ''}',
      teamName: (team['name'] as String?) ?? '',
      teamLogo: team['logo'] as String?,
      formation: (j['formation'] as String?) ?? '',
      startXI:     start.map(LineupPlayer.fromJson).toList(),
      substitutes: subs.map(LineupPlayer.fromJson).toList(),
      coachName: coach['name'] as String?,
    );
  }

  final String teamId;
  final String teamName;
  final String? teamLogo;
  final String formation;
  final List<LineupPlayer> startXI;
  final List<LineupPlayer> substitutes;
  final String? coachName;
}
