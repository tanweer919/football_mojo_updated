import '../../album/data/models/card_models.dart' show CardRarity;

/// Parse the wire rarity string (Prisma enum value) back into the Flutter
/// enum. Defaults to COMMON when the server adds a new value we don't know.
CardRarity rarityFromString(String s) {
  switch (s) {
    case 'COMMON':    return CardRarity.COMMON;
    case 'UNCOMMON':  return CardRarity.UNCOMMON;
    case 'RARE':      return CardRarity.RARE;
    case 'EPIC':      return CardRarity.EPIC;
    case 'LEGENDARY': return CardRarity.LEGENDARY;
    case 'ICONIC':    return CardRarity.ICONIC;
    default:          return CardRarity.COMMON;
  }
}

String rarityLabel(CardRarity r) => switch (r) {
      CardRarity.COMMON    => 'Common',
      CardRarity.UNCOMMON  => 'Uncommon',
      CardRarity.RARE      => 'Rare',
      CardRarity.EPIC      => 'Epic',
      CardRarity.LEGENDARY => 'Legendary',
      CardRarity.ICONIC    => 'Iconic',
    };

class MarketTeam {
  const MarketTeam({
    required this.id,
    required this.name,
    required this.shortName,
    this.crestUrl,
    this.countryCode,
  });
  final String id;
  final String name;
  final String shortName;
  final String? crestUrl;
  final String? countryCode;

  factory MarketTeam.fromJson(Map<String, dynamic> j) => MarketTeam(
        id: j['id'] as String,
        name: j['name'] as String,
        shortName: (j['shortName'] as String?) ?? (j['name'] as String),
        crestUrl: j['crestUrl'] as String?,
        countryCode: j['countryCode'] as String?,
      );
}

class MarketPlayer {
  const MarketPlayer({
    required this.id,
    required this.name,
    this.position,
    this.photoUrl,
    this.country,
    this.shirtNumber,
    this.team,
  });
  final String id;
  final String name;
  final String? position;
  final String? photoUrl;
  final String? country;
  final int? shirtNumber;
  final MarketTeam? team;

  factory MarketPlayer.fromJson(Map<String, dynamic> j) => MarketPlayer(
        id: j['id'] as String,
        name: j['name'] as String,
        position: j['position'] as String?,
        photoUrl: j['photoUrl'] as String?,
        country: j['country'] as String?,
        shirtNumber: (j['shirtNumber'] as num?)?.toInt(),
        team: j['team'] == null ? null : MarketTeam.fromJson((j['team'] as Map).cast<String, dynamic>()),
      );
}

/// Grid-tile DTO returned by `GET /v1/cards/market`.
class MarketCard {
  const MarketCard({
    required this.id,
    required this.edition,
    required this.rarity,
    required this.totalSupply,
    required this.mintedCount,
    required this.remaining,
    required this.artUrl,
    required this.frameStyle,
    required this.giftableOnly,
    required this.purchasable,
    required this.ownedByMe,
    this.gemPrice,
    this.player,
    this.formScore,
  });
  final String id;
  final String edition;
  final CardRarity rarity;
  final int totalSupply;
  final int mintedCount;
  final int remaining;
  final String artUrl;
  final String frameStyle;
  final bool giftableOnly;
  final bool purchasable;
  final int? gemPrice;
  final MarketPlayer? player;

  /// 0 when anonymous or not held. Powers the "in collection" badge.
  final int ownedByMe;

  /// Last-5 average score — shown as hex badge on the grid tile.
  /// Null when the backend hasn't shipped the form fields yet.
  final double? formScore;

  bool get isSoldOut => remaining <= 0;

  /// Rarity bonus percentage for fantasy scoring.
  int get bonusPct => switch (rarity) {
        CardRarity.COMMON    => 0,
        CardRarity.UNCOMMON  => 2,
        CardRarity.RARE      => 5,
        CardRarity.EPIC      => 10,
        CardRarity.LEGENDARY => 15,
        CardRarity.ICONIC    => 20,
      };

  factory MarketCard.fromJson(Map<String, dynamic> j) => MarketCard(
        id: j['id'] as String,
        edition: j['edition'] as String,
        rarity: rarityFromString(j['rarity'] as String),
        totalSupply: (j['totalSupply'] as num).toInt(),
        mintedCount: (j['mintedCount'] as num).toInt(),
        remaining:   (j['remaining']   as num).toInt(),
        artUrl: j['artUrl'] as String,
        frameStyle: (j['frameStyle'] as String?) ?? 'base',
        giftableOnly: (j['giftableOnly'] as bool?) ?? false,
        purchasable:  (j['purchasable']  as bool?) ?? false,
        gemPrice: (j['gemPrice'] as num?)?.toInt(),
        ownedByMe: (j['ownedByMe'] as num?)?.toInt() ?? 0,
        formScore: (j['formScore'] as num?)?.toDouble(),
        player: j['player'] == null ? null : MarketPlayer.fromJson((j['player'] as Map).cast<String, dynamic>()),
      );
}

class MarketPage {
  const MarketPage({required this.items, this.nextCursor});
  final List<MarketCard> items;
  final String? nextCursor;

  factory MarketPage.fromJson(Map<String, dynamic> j) => MarketPage(
        items: ((j['items'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(MarketCard.fromJson)
            .toList(),
        nextCursor: j['nextCursor'] as String?,
      );
}

/// Facet bucket — value + how many templates fall into it. Surfaced in the
/// filter sheet so a chip showing "Iconic · 24" tells the user upfront how
/// many cards a tap will reveal.
class FacetBucket {
  const FacetBucket({required this.value, required this.count, this.label, this.crestUrl});
  final String value;
  final int count;
  final String? label;
  final String? crestUrl;
}

class MarketFacets {
  const MarketFacets({
    required this.rarities,
    required this.editions,
    required this.positions,
    required this.countries,
    required this.teams,
  });
  final List<FacetBucket> rarities;
  final List<FacetBucket> editions;
  final List<FacetBucket> positions;
  final List<FacetBucket> countries;
  final List<FacetBucket> teams;

  factory MarketFacets.fromJson(Map<String, dynamic> j) {
    List<FacetBucket> simple(String k) => ((j[k] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .where((m) => m['value'] != null)
        .map((m) => FacetBucket(value: m['value'].toString(), count: (m['count'] as num).toInt()))
        .toList();
    return MarketFacets(
      rarities: simple('rarities'),
      editions: simple('editions'),
      positions: simple('positions'),
      countries: simple('countries'),
      teams: ((j['teams'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((m) => FacetBucket(
                value: m['id'].toString(),
                label: m['name'].toString(),
                crestUrl: m['crestUrl'] as String?,
                count: (m['count'] as num).toInt(),
              ))
          .toList(),
    );
  }
}

enum MarketSort { newest, rarityDesc, supplyAsc, mostMinted, nameAsc }

extension MarketSortApi on MarketSort {
  String get wire => switch (this) {
        MarketSort.newest     => 'newest',
        MarketSort.rarityDesc => 'rarity_desc',
        MarketSort.supplyAsc  => 'supply_asc',
        MarketSort.mostMinted => 'most_minted',
        MarketSort.nameAsc    => 'name_asc',
      };
  String get label => switch (this) {
        MarketSort.newest     => 'Newest',
        MarketSort.rarityDesc => 'Rarity (high → low)',
        MarketSort.supplyAsc  => 'Scarcest first',
        MarketSort.mostMinted => 'Most minted',
        MarketSort.nameAsc    => 'Name A → Z',
      };
}

enum MarketAvailability { all, available, soldOut }

extension MarketAvailabilityApi on MarketAvailability {
  String get wire => switch (this) {
        MarketAvailability.all       => 'all',
        MarketAvailability.available => 'available',
        MarketAvailability.soldOut   => 'sold_out',
      };
  String get label => switch (this) {
        MarketAvailability.all       => 'All',
        MarketAvailability.available => 'Available',
        MarketAvailability.soldOut   => 'Sold out',
      };
}

enum MarketOwnership { all, owned, unowned }

extension MarketOwnershipApi on MarketOwnership {
  String get wire => switch (this) {
        MarketOwnership.all     => 'all',
        MarketOwnership.owned   => 'owned',
        MarketOwnership.unowned => 'unowned',
      };
  String get label => switch (this) {
        MarketOwnership.all     => 'All',
        MarketOwnership.owned   => 'In collection',
        MarketOwnership.unowned => 'Missing',
      };
}

/// Immutable filter state shared between the screen and the filter sheet.
/// Equality is structural so Riverpod families cache identical queries.
class MarketFilters {
  const MarketFilters({
    this.rarities = const {},
    this.editions = const {},
    this.positions = const {},
    this.countries = const {},
    this.teamIds = const {},
    this.search = '',
    this.availability = MarketAvailability.all,
    this.ownership = MarketOwnership.all,
    this.sort = MarketSort.newest,
  });

  final Set<CardRarity> rarities;
  final Set<String> editions;
  final Set<String> positions;
  final Set<String> countries;
  final Set<String> teamIds;
  final String search;
  final MarketAvailability availability;
  final MarketOwnership ownership;
  final MarketSort sort;

  bool get isPristine =>
      rarities.isEmpty &&
      editions.isEmpty &&
      positions.isEmpty &&
      countries.isEmpty &&
      teamIds.isEmpty &&
      search.isEmpty &&
      availability == MarketAvailability.all &&
      ownership == MarketOwnership.all &&
      sort == MarketSort.newest;

  /// Number of *categorical* facets active — used for the badge count next
  /// to the Filters button. Sort + search don't count toward "filters".
  int get activeCount {
    var n = 0;
    if (rarities.isNotEmpty) n++;
    if (editions.isNotEmpty) n++;
    if (positions.isNotEmpty) n++;
    if (countries.isNotEmpty) n++;
    if (teamIds.isNotEmpty) n++;
    if (availability != MarketAvailability.all) n++;
    if (ownership != MarketOwnership.all) n++;
    return n;
  }

  MarketFilters copyWith({
    Set<CardRarity>? rarities,
    Set<String>? editions,
    Set<String>? positions,
    Set<String>? countries,
    Set<String>? teamIds,
    String? search,
    MarketAvailability? availability,
    MarketOwnership? ownership,
    MarketSort? sort,
  }) => MarketFilters(
        rarities: rarities ?? this.rarities,
        editions: editions ?? this.editions,
        positions: positions ?? this.positions,
        countries: countries ?? this.countries,
        teamIds: teamIds ?? this.teamIds,
        search: search ?? this.search,
        availability: availability ?? this.availability,
        ownership: ownership ?? this.ownership,
        sort: sort ?? this.sort,
      );

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{
      'sort': sort.wire,
      'availability': availability.wire,
      'ownership': ownership.wire,
    };
    if (rarities.isNotEmpty)   q['rarities']  = rarities.map((r) => r.name).join(',');
    if (editions.isNotEmpty)   q['editions']  = editions.join(',');
    if (positions.isNotEmpty)  q['positions'] = positions.join(',');
    if (countries.isNotEmpty)  q['countries'] = countries.join(',');
    if (teamIds.isNotEmpty)    q['teamIds']   = teamIds.join(',');
    if (search.trim().isNotEmpty) q['search'] = search.trim();
    return q;
  }

  // Cheap structural equality so Riverpod's `FutureProvider.family` doesn't
  // refetch when an identical filter set rebuilds.
  @override
  bool operator ==(Object other) =>
      other is MarketFilters &&
      _setEq(rarities, other.rarities) &&
      _setEq(editions, other.editions) &&
      _setEq(positions, other.positions) &&
      _setEq(countries, other.countries) &&
      _setEq(teamIds, other.teamIds) &&
      search == other.search &&
      availability == other.availability &&
      ownership == other.ownership &&
      sort == other.sort;

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(rarities),
        Object.hashAllUnordered(editions),
        Object.hashAllUnordered(positions),
        Object.hashAllUnordered(countries),
        Object.hashAllUnordered(teamIds),
        search,
        availability,
        ownership,
        sort,
      );
}

bool _setEq<T>(Set<T> a, Set<T> b) {
  if (a.length != b.length) return false;
  for (final x in a) {
    if (!b.contains(x)) return false;
  }
  return true;
}

// ─── Player form stats (for market detail) ────────────────────────────────

/// Per-bucket form average — parallel to the album's OwnedCardFormBucket
/// but kept separate to avoid cross-feature coupling.
class MarketFormBucket {
  const MarketFormBucket({required this.avg, required this.n});
  final double avg;
  final int n;
  factory MarketFormBucket.fromJson(Map<String, dynamic> j) => MarketFormBucket(
        avg: ((j['avg'] as num?) ?? 0).toDouble(),
        n: (j['n'] as num?)?.toInt() ?? 0,
      );
}

class MarketFormStats {
  const MarketFormStats({required this.last5, required this.last10, required this.last40});
  final MarketFormBucket last5;
  final MarketFormBucket last10;
  final MarketFormBucket last40;
  factory MarketFormStats.fromJson(Map<String, dynamic> j) => MarketFormStats(
        last5: MarketFormBucket.fromJson((j['last5'] as Map).cast<String, dynamic>()),
        last10: MarketFormBucket.fromJson((j['last10'] as Map).cast<String, dynamic>()),
        last40: MarketFormBucket.fromJson((j['last40'] as Map).cast<String, dynamic>()),
      );
}

class MarketPlayerScore {
  const MarketPlayerScore({
    required this.gameweekId,
    required this.totalPoints,
    this.gameweekNumber,
    this.breakdown,
  });
  final String gameweekId;
  final int? gameweekNumber;
  final double totalPoints;
  final dynamic breakdown;
  factory MarketPlayerScore.fromJson(Map<String, dynamic> j) => MarketPlayerScore(
        gameweekId: j['gameweekId'] as String,
        gameweekNumber: (j['gameweekNumber'] as num?)?.toInt(),
        totalPoints: ((j['totalPoints'] as num?) ?? 0).toDouble(),
        breakdown: j['breakdown'],
      );
}

/// Detail payload for the template page — supply economics + collection
/// holdings + player form data.
class MarketTemplateDetail {
  const MarketTemplateDetail({
    required this.template,
    required this.stats,
    required this.sets,
    required this.myCopies,
    this.player,
    this.formStats,
    this.lastScores = const [],
  });
  final MarketCard template;        // re-uses tile DTO (superset of fields we need)
  final MarketTemplateStats stats;
  final List<MarketSetRef> sets;
  final List<MarketOwnedCopy> myCopies;
  final MarketPlayer? player;
  final MarketFormStats? formStats;
  final List<MarketPlayerScore> lastScores;

  factory MarketTemplateDetail.fromJson(Map<String, dynamic> j) {
    final tj = (j['template'] as Map).cast<String, dynamic>();
    final player = j['player'] == null
        ? null
        : MarketPlayer.fromJson((j['player'] as Map).cast<String, dynamic>());
    // The list endpoint returns the player inside the template row; the
    // detail endpoint separates them, so we splice it back together for the
    // shared MarketCard shape.
    final templateJson = <String, dynamic>{
      ...tj,
      'remaining': (tj['remaining'] as num?) ?? ((tj['totalSupply'] as num) - (tj['mintedCount'] as num)),
      'ownedByMe': ((j['stats'] as Map)['ownedByMe'] as num?)?.toInt() ?? 0,
      'player': player == null ? null : {
        'id': player.id,
        'name': player.name,
        'position': player.position,
        'photoUrl': player.photoUrl,
        'country': player.country,
        'team': player.team == null ? null : {
          'id': player.team!.id,
          'name': player.team!.name,
          'shortName': player.team!.shortName,
          'crestUrl': player.team!.crestUrl,
          'countryCode': player.team!.countryCode,
        },
      },
    };

    // Parse player form data if present.
    final formJson = j['playerForm'] as Map<String, dynamic>?;
    MarketFormStats? formStats;
    List<MarketPlayerScore> lastScores = const [];
    if (formJson != null) {
      if (formJson['formStats'] != null) {
        formStats = MarketFormStats.fromJson((formJson['formStats'] as Map).cast<String, dynamic>());
      }
      lastScores = ((formJson['lastScores'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(MarketPlayerScore.fromJson)
          .toList();
    }

    return MarketTemplateDetail(
      template: MarketCard.fromJson(templateJson),
      stats: MarketTemplateStats.fromJson((j['stats'] as Map).cast<String, dynamic>()),
      sets: ((j['sets'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(MarketSetRef.fromJson)
          .toList(),
      myCopies: ((j['myCopies'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(MarketOwnedCopy.fromJson)
          .toList(),
      player: player,
      formStats: formStats,
      lastScores: lastScores,
    );
  }
}

class MarketTemplateStats {
  const MarketTemplateStats({
    required this.totalSupply,
    required this.mintedCount,
    required this.remaining,
    required this.uniqueOwners,
    required this.ownedByMe,
    this.lowestSerial,
    this.highestSerial,
    this.firstMintedAt,
    this.lastMintedAt,
  });
  final int totalSupply;
  final int mintedCount;
  final int remaining;
  final int uniqueOwners;
  final int ownedByMe;
  final int? lowestSerial;
  final int? highestSerial;
  final DateTime? firstMintedAt;
  final DateTime? lastMintedAt;

  factory MarketTemplateStats.fromJson(Map<String, dynamic> j) => MarketTemplateStats(
        totalSupply: (j['totalSupply'] as num).toInt(),
        mintedCount: (j['mintedCount'] as num).toInt(),
        remaining:   (j['remaining']   as num).toInt(),
        uniqueOwners:(j['uniqueOwners']as num).toInt(),
        ownedByMe:   (j['ownedByMe']   as num?)?.toInt() ?? 0,
        lowestSerial:(j['lowestSerial']as num?)?.toInt(),
        highestSerial:(j['highestSerial']as num?)?.toInt(),
        firstMintedAt: j['firstMintedAt'] == null ? null : DateTime.parse(j['firstMintedAt'] as String),
        lastMintedAt:  j['lastMintedAt']  == null ? null : DateTime.parse(j['lastMintedAt']  as String),
      );
}

class MarketSetRef {
  const MarketSetRef({required this.id, required this.name});
  final String id;
  final String name;
  factory MarketSetRef.fromJson(Map<String, dynamic> j) =>
      MarketSetRef(id: j['id'] as String, name: j['name'] as String);
}

class MarketOwnedCopy {
  const MarketOwnedCopy({
    required this.id,
    required this.serialNumber,
    required this.acquiredVia,
    required this.mintedAt,
  });
  final String id;
  final int serialNumber;
  final String acquiredVia;
  final DateTime mintedAt;
  factory MarketOwnedCopy.fromJson(Map<String, dynamic> j) => MarketOwnedCopy(
        id: j['id'] as String,
        serialNumber: (j['serialNumber'] as num).toInt(),
        acquiredVia: j['acquiredVia'] as String,
        mintedAt: DateTime.parse(j['mintedAt'] as String),
      );
}

// ─── History ──────────────────────────────────────────────────────────────

enum MarketEventType { mint, trade }

class MarketEventActor {
  const MarketEventActor({
    required this.id,
    this.userTag,
    this.displayName,
    this.photoUrl,
  });
  final String id;
  final String? userTag;
  final String? displayName;
  final String? photoUrl;
  String get handle => userTag != null ? '@$userTag' : (displayName ?? id.substring(0, 6));
  factory MarketEventActor.fromJson(Map<String, dynamic> j) => MarketEventActor(
        id: j['id'] as String,
        userTag: j['userTag'] as String?,
        displayName: j['displayName'] as String?,
        photoUrl: j['photoUrl'] as String?,
      );
}

class MarketHistoryEvent {
  const MarketHistoryEvent({
    required this.type,
    required this.at,
    this.serialNumber,
    this.serialNumbers,
    this.acquiredVia,
    this.actor,
    this.fromUser,
    this.toUser,
    this.tradeId,
  });
  final MarketEventType type;
  final DateTime at;
  final int? serialNumber;
  final List<int>? serialNumbers;
  final String? acquiredVia;
  final MarketEventActor? actor;
  final MarketEventActor? fromUser;
  final MarketEventActor? toUser;
  final String? tradeId;

  factory MarketHistoryEvent.fromJson(Map<String, dynamic> j) {
    final type = (j['type'] as String) == 'TRADE' ? MarketEventType.trade : MarketEventType.mint;
    return MarketHistoryEvent(
      type: type,
      at: DateTime.parse(j['at'] as String),
      serialNumber: (j['serialNumber'] as num?)?.toInt(),
      serialNumbers: (j['serialNumbers'] as List?)?.map((x) => (x as num).toInt()).toList(),
      acquiredVia: j['acquiredVia'] as String?,
      actor:    j['actor']    == null ? null : MarketEventActor.fromJson((j['actor']    as Map).cast<String, dynamic>()),
      fromUser: j['fromUser'] == null ? null : MarketEventActor.fromJson((j['fromUser'] as Map).cast<String, dynamic>()),
      toUser:   j['toUser']   == null ? null : MarketEventActor.fromJson((j['toUser']   as Map).cast<String, dynamic>()),
      tradeId: j['tradeId'] as String?,
    );
  }
}

class MarketHistoryPage {
  const MarketHistoryPage({required this.events, this.nextCursor, this.total = 0});
  final List<MarketHistoryEvent> events;
  final String? nextCursor;
  final int total;
  factory MarketHistoryPage.fromJson(Map<String, dynamic> j) => MarketHistoryPage(
        events: ((j['events'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(MarketHistoryEvent.fromJson)
            .toList(),
        nextCursor: j['nextCursor'] as String?,
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}
