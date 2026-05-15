class H2HMatchDto {
  H2HMatchDto({
    required this.fixtureId,
    required this.date,
    required this.competitionName,
    required this.homeTeamId,
    required this.homeTeamName,
    this.homeTeamLogo,
    required this.awayTeamId,
    required this.awayTeamName,
    this.awayTeamLogo,
    required this.homeScore,
    required this.awayScore,
  });

  factory H2HMatchDto.fromJson(Map<String, dynamic> j) {
    final fx = (j['fixture'] as Map?)?.cast<String, dynamic>() ?? const {};
    final teams = (j['teams'] as Map?)?.cast<String, dynamic>() ?? const {};
    final home = (teams['home'] as Map?)?.cast<String, dynamic>() ?? const {};
    final away = (teams['away'] as Map?)?.cast<String, dynamic>() ?? const {};
    final goals = (j['goals'] as Map?)?.cast<String, dynamic>() ?? const {};
    final league = (j['league'] as Map?)?.cast<String, dynamic>() ?? const {};
    return H2HMatchDto(
      fixtureId: '${fx['id'] ?? ''}',
      date: DateTime.tryParse((fx['date'] as String?) ?? '') ?? DateTime.now(),
      competitionName: (league['name'] as String?) ?? '',
      homeTeamId: '${home['id'] ?? ''}',
      homeTeamName: (home['name'] as String?) ?? '',
      homeTeamLogo: home['logo'] as String?,
      awayTeamId: '${away['id'] ?? ''}',
      awayTeamName: (away['name'] as String?) ?? '',
      awayTeamLogo: away['logo'] as String?,
      homeScore: (goals['home'] as int?) ?? 0,
      awayScore: (goals['away'] as int?) ?? 0,
    );
  }

  final String fixtureId;
  final DateTime date;
  final String competitionName;
  final String homeTeamId, homeTeamName;
  final String? homeTeamLogo;
  final String awayTeamId, awayTeamName;
  final String? awayTeamLogo;
  final int homeScore, awayScore;
}
