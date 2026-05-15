/// DTOs for /v1/users/me.
class ProfileTeam {
  ProfileTeam({
    required this.id,
    required this.name,
    required this.shortName,
    this.crestUrl,
    this.competitionName,
  });
  final String id;
  final String name;
  final String shortName;
  final String? crestUrl;
  final String? competitionName;

  factory ProfileTeam.fromJson(Map<String, dynamic> j) => ProfileTeam(
        id: j['id'] as String,
        name: j['name'] as String,
        shortName: j['shortName'] as String? ?? j['name'] as String,
        crestUrl: j['crestUrl'] as String?,
        competitionName: (j['competition'] as Map<String, dynamic>?)?['name'] as String?,
      );
}

class ProfileAchievement {
  ProfileAchievement({
    required this.id,
    required this.name,
    required this.description,
    required this.unlockedAt,
    this.iconUrl,
  });
  final String id;
  final String name;
  final String description;
  final DateTime unlockedAt;
  final String? iconUrl;

  factory ProfileAchievement.fromJson(Map<String, dynamic> j) => ProfileAchievement(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String,
        iconUrl: j['iconUrl'] as String?,
        unlockedAt: DateTime.parse(j['unlockedAt'] as String),
      );
}

class ProfileStats {
  ProfileStats({
    required this.ownedCards,
    required this.totalFantasyPoints,
    required this.h2hWins,
    required this.rarityCount,
  });
  final int ownedCards;
  final double totalFantasyPoints;
  final int h2hWins;
  final Map<String, int> rarityCount;

  factory ProfileStats.fromJson(Map<String, dynamic> j) => ProfileStats(
        ownedCards: (j['ownedCards'] as num?)?.toInt() ?? 0,
        totalFantasyPoints: ((j['totalFantasyPoints'] as num?) ?? 0).toDouble(),
        h2hWins: (j['h2hWins'] as num?)?.toInt() ?? 0,
        rarityCount: ((j['rarityCount'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
      );
}

class Profile {
  Profile({
    required this.id,
    this.email,
    this.displayName,
    this.photoUrl,
    this.countryCode,
    required this.coins,
    required this.gems,
    this.proExpiresAt,
    required this.memberSince,
    required this.stats,
    required this.achievements,
    required this.followedTeams,
  });
  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? countryCode;
  final int coins;
  final int gems;
  final DateTime? proExpiresAt;
  final DateTime memberSince;
  final ProfileStats stats;
  final List<ProfileAchievement> achievements;
  final List<ProfileTeam> followedTeams;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        email: j['email'] as String?,
        displayName: j['displayName'] as String?,
        photoUrl: j['photoUrl'] as String?,
        countryCode: j['countryCode'] as String?,
        coins: (j['coins'] as num?)?.toInt() ?? 0,
        gems: (j['gems'] as num?)?.toInt() ?? 0,
        proExpiresAt: j['proExpiresAt'] == null ? null : DateTime.parse(j['proExpiresAt'] as String),
        memberSince: DateTime.parse(j['memberSince'] as String),
        stats: ProfileStats.fromJson(j['stats'] as Map<String, dynamic>),
        achievements: ((j['achievements'] as List?) ?? const [])
            .map((a) => ProfileAchievement.fromJson(a as Map<String, dynamic>))
            .toList(),
        followedTeams: ((j['followedTeams'] as List?) ?? const [])
            .map((t) => ProfileTeam.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}
