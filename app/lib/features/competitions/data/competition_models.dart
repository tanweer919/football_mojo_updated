/// Server-driven competition descriptor. Every UI surface that varies by
/// competition (Tournament screen tabs, Fantasy default, chip selectors) reads
/// these flags rather than hardcoding the WC.
class CompetitionDto {
  CompetitionDto({
    required this.id,
    required this.name,
    required this.type,                // 'tournament' | 'league'
    required this.season,
    required this.startsAt,
    required this.endsAt,
    this.emblemUrl,
    required this.teamCount,
    required this.matchCount,
    required this.activeFantasyTournaments,
    required this.showsBracket,
    required this.showsGroups,
    required this.showsStandings,
    required this.isLive,
    required this.isUpcoming,
  });

  factory CompetitionDto.fromJson(Map<String, dynamic> j) => CompetitionDto(
        id:       j['id']   as String,
        name:     j['name'] as String,
        type:     j['type'] as String,
        season:   j['season'] as String,
        startsAt: DateTime.parse(j['startsAt'] as String),
        endsAt:   DateTime.parse(j['endsAt']   as String),
        emblemUrl: j['emblemUrl'] as String?,
        teamCount:  (j['teamCount']  as int?) ?? 0,
        matchCount: (j['matchCount'] as int?) ?? 0,
        activeFantasyTournaments: ((j['activeFantasyTournaments'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(FantasyTournamentSummary.fromJson)
            .toList(),
        showsBracket:   (j['showsBracket']   as bool?) ?? false,
        showsGroups:    (j['showsGroups']    as bool?) ?? false,
        showsStandings: (j['showsStandings'] as bool?) ?? true,
        isLive:     (j['isLive']     as bool?) ?? false,
        isUpcoming: (j['isUpcoming'] as bool?) ?? false,
      );

  final String id;
  final String name;
  final String type;
  final String season;
  final DateTime startsAt, endsAt;
  final String? emblemUrl;
  final int teamCount, matchCount;
  final List<FantasyTournamentSummary> activeFantasyTournaments;
  final bool showsBracket, showsGroups, showsStandings, isLive, isUpcoming;

  bool get isTournament => type == 'tournament';
  bool get isLeague     => type == 'league';
  FantasyTournamentSummary? get primaryFantasy =>
      activeFantasyTournaments.isEmpty ? null : activeFantasyTournaments.first;
}

class FantasyTournamentSummary {
  FantasyTournamentSummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.format,
    required this.startsAt,
    required this.endsAt,
  });
  factory FantasyTournamentSummary.fromJson(Map<String, dynamic> j) => FantasyTournamentSummary(
        id:       j['id']   as String,
        slug:     j['slug'] as String,
        name:     j['name'] as String,
        format:   j['format'] as String,
        startsAt: DateTime.parse(j['startsAt'] as String),
        endsAt:   DateTime.parse(j['endsAt']   as String),
      );
  final String id, slug, name, format;
  final DateTime startsAt, endsAt;
}
