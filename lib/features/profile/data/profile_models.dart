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

/// One-off signup gift surfaced by /me until the user dismisses the reveal.
class WelcomeCard {
  WelcomeCard({
    required this.id,
    required this.serialNumber,
    required this.rarity,
    required this.totalSupply,
    this.artUrl,
    this.playerName,
    this.playerPosition,
    this.teamName,
    this.teamCrestUrl,
  });
  final String id;
  final int serialNumber;
  final String rarity;
  final int totalSupply;
  final String? artUrl;
  final String? playerName;
  final String? playerPosition;
  final String? teamName;
  final String? teamCrestUrl;

  factory WelcomeCard.fromJson(Map<String, dynamic> j) {
    final t = (j['template'] as Map?)?.cast<String, dynamic>() ?? const {};
    final p = (j['player']   as Map?)?.cast<String, dynamic>();
    final team = (p?['team']  as Map?)?.cast<String, dynamic>();
    return WelcomeCard(
      id: j['id'] as String,
      serialNumber: (j['serialNumber'] as num?)?.toInt() ?? 0,
      rarity: (t['rarity'] as String?) ?? 'COMMON',
      totalSupply: (t['totalSupply'] as num?)?.toInt() ?? 0,
      artUrl: (t['artUrl'] as String?) ?? p?['photoUrl'] as String?,
      playerName: p?['name'] as String?,
      playerPosition: p?['position'] as String?,
      teamName: team?['name'] as String?,
      teamCrestUrl: team?['crestUrl'] as String?,
    );
  }
}

/// Subset of OwnedCard fields needed to render the profile showcase tile.
/// Smaller than OwnedCardDto on purpose — keeps the /me response light.
class PinnedCardSummary {
  PinnedCardSummary({
    required this.id,
    required this.serialNumber,
    required this.rarity,
    required this.totalSupply,
    required this.level,
    required this.trophies,
    this.artUrl,
    this.editionLabel,
    this.playerName,
    this.playerPosition,
    this.playerCountry,
    this.teamCrestUrl,
    this.teamShortName,
  });
  final String id;
  final int serialNumber;
  final String rarity;
  final int totalSupply;
  final int level;
  final List<String> trophies;
  final String? artUrl;
  final String? editionLabel;
  final String? playerName;
  final String? playerPosition;
  final String? playerCountry;
  final String? teamCrestUrl;
  final String? teamShortName;

  factory PinnedCardSummary.fromJson(Map<String, dynamic> j) {
    final t = (j['template'] as Map?)?.cast<String, dynamic>() ?? const {};
    final p = (t['player'] as Map?)?.cast<String, dynamic>();
    final team = (p?['team'] as Map?)?.cast<String, dynamic>();
    return PinnedCardSummary(
      id: j['id'] as String,
      serialNumber: (j['serialNumber'] as num).toInt(),
      level: (j['level'] as num?)?.toInt() ?? 0,
      trophies: ((j['trophies'] as List?) ?? const []).cast<String>(),
      rarity: (t['rarity'] as String?) ?? 'COMMON',
      totalSupply: (t['totalSupply'] as num?)?.toInt() ?? 0,
      artUrl: t['artUrl'] as String?,
      editionLabel: t['edition'] as String?,
      playerName: p?['name'] as String?,
      playerPosition: p?['position'] as String?,
      playerCountry: p?['nationality'] as String?,
      teamCrestUrl: team?['crestUrl'] as String?,
      teamShortName: team?['shortName'] as String?,
    );
  }
}

class Profile {
  Profile({
    required this.id,
    this.email,
    this.displayName,
    this.userTag,
    this.photoUrl,
    this.countryCode,
    required this.coins,
    required this.gems,
    this.proExpiresAt,
    required this.memberSince,
    required this.stats,
    required this.achievements,
    required this.followedTeams,
    this.welcomeCard,
    this.pinnedCard,
  });
  final String id;
  final String? email;
  final String? displayName;
  /// Public handle other users search/follow by — null until claimed.
  final String? userTag;
  final String? photoUrl;
  final String? countryCode;
  final int coins;
  final int gems;
  final DateTime? proExpiresAt;
  final DateTime memberSince;
  final ProfileStats stats;
  final List<ProfileAchievement> achievements;
  final List<ProfileTeam> followedTeams;
  /// Set when the server has minted a signup gift the user hasn't seen yet.
  /// Triggers the full-screen reveal animation on next sign-in.
  final WelcomeCard? welcomeCard;
  /// Card the user has pinned to their profile showcase. Public flex.
  /// Null when the user hasn't pinned anything yet — the profile screen
  /// renders a "pin your best card" prompt in that case.
  final PinnedCardSummary? pinnedCard;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        email: j['email'] as String?,
        displayName: j['displayName'] as String?,
        userTag: j['userTag'] as String?,
        photoUrl: j['photoUrl'] as String?,
        countryCode: j['countryCode'] as String?,
        coins: (j['coins'] as num?)?.toInt() ?? 0,
        gems: (j['gems'] as num?)?.toInt() ?? 0,
        proExpiresAt: j['proExpiresAt'] == null ? null : DateTime.parse(j['proExpiresAt'] as String),
        memberSince: DateTime.parse(j['memberSince'] as String),
        welcomeCard: j['welcomeCard'] == null ? null : WelcomeCard.fromJson(j['welcomeCard'] as Map<String, dynamic>),
        pinnedCard: j['pinnedCard'] == null ? null : PinnedCardSummary.fromJson((j['pinnedCard'] as Map).cast<String, dynamic>()),
        stats: ProfileStats.fromJson(j['stats'] as Map<String, dynamic>),
        achievements: ((j['achievements'] as List?) ?? const [])
            .map((a) => ProfileAchievement.fromJson(a as Map<String, dynamic>))
            .toList(),
        followedTeams: ((j['followedTeams'] as List?) ?? const [])
            .map((t) => ProfileTeam.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}
