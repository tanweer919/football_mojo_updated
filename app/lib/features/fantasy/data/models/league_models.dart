/// Private fantasy league DTOs. Plain classes — no codegen.

class FantasyLeagueSummary {
  FantasyLeagueSummary({
    required this.id,
    required this.tournamentId,
    required this.tournamentSlug,
    required this.tournamentName,
    required this.name,
    required this.joinCode,
    required this.memberCount,
    required this.memberLimit,
    required this.isOwner,
    this.joinedAt,
  });
  final String id;
  final String tournamentId;
  final String tournamentSlug;
  final String tournamentName;
  final String name;
  final String joinCode;
  final int memberCount;
  final int memberLimit;
  final bool isOwner;
  final DateTime? joinedAt;

  factory FantasyLeagueSummary.fromJson(Map<String, dynamic> j) =>
      FantasyLeagueSummary(
        id: j['id'] as String,
        tournamentId: j['tournamentId'] as String,
        tournamentSlug: j['tournamentSlug'] as String? ?? '',
        tournamentName: j['tournamentName'] as String? ?? '',
        name: j['name'] as String,
        joinCode: j['joinCode'] as String,
        memberCount: (j['memberCount'] as num?)?.toInt() ?? 0,
        memberLimit: (j['memberLimit'] as num?)?.toInt() ?? 100,
        isOwner: j['isOwner'] as bool? ?? false,
        joinedAt: j['joinedAt'] == null
            ? null
            : DateTime.parse(j['joinedAt'] as String),
      );
}
