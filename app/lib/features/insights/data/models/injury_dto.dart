class InjuryDto {
  InjuryDto({
    required this.playerId,
    required this.playerName,
    this.playerPhoto,
    required this.teamId,
    required this.teamName,
    this.teamLogo,
    required this.type,
    required this.reason,
    required this.fixtureDate,
  });

  factory InjuryDto.fromJson(Map<String, dynamic> j) {
    final p = (j['player']  as Map?)?.cast<String, dynamic>() ?? const {};
    final t = (j['team']    as Map?)?.cast<String, dynamic>() ?? const {};
    final f = (j['fixture'] as Map?)?.cast<String, dynamic>() ?? const {};
    return InjuryDto(
      playerId: '${p['id'] ?? ''}',
      playerName: (p['name'] as String?) ?? '',
      playerPhoto: p['photo'] as String?,
      teamId: '${t['id'] ?? ''}',
      teamName: (t['name'] as String?) ?? '',
      teamLogo: t['logo'] as String?,
      type: (p['type'] as String?) ?? '',          // "Missing Fixture" | "Questionable"
      reason: (p['reason'] as String?) ?? '',
      fixtureDate: DateTime.tryParse((f['date'] as String?) ?? '') ?? DateTime.now(),
    );
  }

  final String playerId;
  final String playerName;
  final String? playerPhoto;
  final String teamId;
  final String teamName;
  final String? teamLogo;
  final String type;
  final String reason;
  final DateTime fixtureDate;
}
