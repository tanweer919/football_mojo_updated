/// Plain data classes for the World Cup screen.
/// Skip freezed/codegen — these are read-only, single-screen DTOs.

class WcTeamRef {
  WcTeamRef({
    required this.id,
    required this.name,
    required this.shortName,
    this.countryCode,
    this.crestUrl,
  });
  final String id;
  final String name;
  final String shortName;
  final String? countryCode;
  final String? crestUrl;

  factory WcTeamRef.fromJson(Map<String, dynamic> j) => WcTeamRef(
        id: j['id'] as String,
        name: j['name'] as String,
        shortName: j['shortName'] as String? ?? j['name'] as String,
        countryCode: j['countryCode'] as String?,
        crestUrl: j['crestUrl'] as String?,
      );
}

class WcOpeningMatch {
  WcOpeningMatch({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.kickoffAt,
    this.venue,
    this.stage,
  });
  final String id;
  final WcTeamRef homeTeam;
  final WcTeamRef awayTeam;
  final DateTime kickoffAt;
  final String? venue;
  final String? stage;

  factory WcOpeningMatch.fromJson(Map<String, dynamic> j) => WcOpeningMatch(
        id: j['id'] as String,
        homeTeam: WcTeamRef.fromJson(j['homeTeam'] as Map<String, dynamic>),
        awayTeam: WcTeamRef.fromJson(j['awayTeam'] as Map<String, dynamic>),
        kickoffAt: DateTime.parse(j['kickoffAt'] as String),
        venue: j['venue'] as String?,
        stage: j['stage'] as String?,
      );
}

class WcVenueSummary {
  WcVenueSummary({required this.name, required this.matchCount});
  final String name;
  final int matchCount;

  factory WcVenueSummary.fromJson(Map<String, dynamic> j) => WcVenueSummary(
        name: j['name'] as String,
        matchCount: (j['matchCount'] as num).toInt(),
      );
}

class WcOverview {
  WcOverview({
    required this.id,
    required this.name,
    required this.startsAt,
    required this.endsAt,
    required this.teamCount,
    required this.matchCount,
    required this.groupCount,
    required this.venueCount,
    required this.venues,
    this.openingMatch,
  });
  final String id;
  final String name;
  final DateTime startsAt;
  final DateTime endsAt;
  final int teamCount;
  final int matchCount;
  final int groupCount;
  final int venueCount;
  final List<WcVenueSummary> venues;
  final WcOpeningMatch? openingMatch;

  factory WcOverview.fromJson(Map<String, dynamic> j) => WcOverview(
        id: j['id'] as String,
        name: j['name'] as String,
        startsAt: DateTime.parse(j['startsAt'] as String),
        endsAt: DateTime.parse(j['endsAt'] as String),
        teamCount: (j['teamCount'] as num).toInt(),
        matchCount: (j['matchCount'] as num).toInt(),
        groupCount: (j['groupCount'] as num).toInt(),
        venueCount: (j['venueCount'] as num).toInt(),
        venues: ((j['venues'] as List?) ?? const [])
            .map((v) => WcVenueSummary.fromJson(v as Map<String, dynamic>))
            .toList(),
        openingMatch: j['openingMatch'] == null
            ? null
            : WcOpeningMatch.fromJson(j['openingMatch'] as Map<String, dynamic>),
      );
}

class GroupStandingRow {
  GroupStandingRow({
    required this.position,
    required this.team,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDiff,
    required this.points,
  });
  final int position;
  final WcTeamRef team;
  final int played, won, drawn, lost, goalsFor, goalsAgainst, goalDiff, points;

  factory GroupStandingRow.fromJson(Map<String, dynamic> j) => GroupStandingRow(
        position: (j['position'] as num).toInt(),
        team: WcTeamRef.fromJson(j['team'] as Map<String, dynamic>),
        played: (j['played'] as num).toInt(),
        won: (j['won'] as num).toInt(),
        drawn: (j['drawn'] as num).toInt(),
        lost: (j['lost'] as num).toInt(),
        goalsFor: (j['goalsFor'] as num).toInt(),
        goalsAgainst: (j['goalsAgainst'] as num).toInt(),
        goalDiff: (j['goalDiff'] as num).toInt(),
        points: (j['points'] as num).toInt(),
      );
}

class WcGroup {
  WcGroup({
    required this.id,
    required this.name,
    required this.letter,
    required this.standings,
  });
  final String id;
  final String name;
  final String letter;
  final List<GroupStandingRow> standings;

  factory WcGroup.fromJson(Map<String, dynamic> j) => WcGroup(
        id: j['id'] as String,
        name: j['name'] as String,
        letter: j['letter'] as String,
        standings: ((j['standings'] as List?) ?? const [])
            .map((s) => GroupStandingRow.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}
