import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import '../models/card_models.dart';

class AlbumRepository {
  AlbumRepository(this._dio);
  final Dio _dio;

  Future<List<AlbumSetDto>> fetchAlbum() async {
    try {
      final res = await _dio.get<List<dynamic>>('/v1/cards/album');
      return (res.data ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AlbumSetDto.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      // The album is gated behind Firebase auth. When the user isn't signed
      // in (401) or hasn't been provisioned yet (404), surface an empty
      // collection rather than an error wall. The screen's empty state will
      // prompt them to sign in.
      final code = e.response?.statusCode;
      if (code == 401 || code == 404) return const <AlbumSetDto>[];
      rethrow;
    }
  }

  Future<OwnedCardDto> ownedById(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/cards/owned/$id');
    return OwnedCardDto.fromJson(res.data!);
  }

  Future<OwnedCardDto> claimDaily() async {
    final res = await _dio.post<Map<String, dynamic>>('/v1/cards/claim/daily');
    return OwnedCardDto.fromJson(res.data!);
  }

  Future<OwnedCardDto> claimRewardedAd(String ssvToken) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/cards/claim/rewarded-ad',
      data: {'ssvToken': ssvToken},
    );
    return OwnedCardDto.fromJson(res.data!);
  }

  /// Gem-store: templates currently for sale (purchasable + inside drop window).
  Future<List<StoreTemplate>> featuredForSale() async {
    final res = await _dio.get<List<dynamic>>('/v1/cards/store/featured');
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(StoreTemplate.fromJson)
        .toList(growable: false);
  }

  /// Spend gems on a specific template. Server-side debit + mint are atomic.
  Future<OwnedCardDto> purchaseTemplate(String templateId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/cards/purchase',
      data: {'templateId': templateId},
    );
    return OwnedCardDto.fromJson(res.data!);
  }

  /// Transparent bundles ("packs" with known contents) for sale with gems.
  Future<List<CardBundleDto>> listBundles() async {
    try {
      final res = await _dio.get<List<dynamic>>('/v1/cards/bundles');
      return (res.data ?? const [])
          .cast<Map<String, dynamic>>()
          .map(CardBundleDto.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      // Anonymous users get an empty shelf rather than an error wall.
      if (e.response?.statusCode == 401) return const <CardBundleDto>[];
      rethrow;
    }
  }

  /// Buy a bundle with gems. Server debits once + mints every member card
  /// atomically, returning the freshly-minted cards for the reveal.
  Future<List<OwnedCardDto>> purchaseBundle(String bundleId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/cards/bundles/$bundleId/purchase',
    );
    final cards = (res.data?['cards'] as List?) ?? const [];
    return cards
        .cast<Map<String, dynamic>>()
        .map(OwnedCardDto.fromJson)
        .toList(growable: false);
  }
}

/// One member card inside a [CardBundleDto] — enough to render its tile in
/// the transparent "here's exactly what you get" list.
class BundleCardDto {
  BundleCardDto({
    required this.templateId,
    required this.rarity,
    required this.artUrl,
    this.playerName,
    this.teamName,
    this.teamCrestUrl,
    this.singlePrice,
    this.ownedByMe = false,
    this.soldOut = false,
  });
  factory BundleCardDto.fromJson(Map<String, dynamic> j) => BundleCardDto(
        templateId: j['templateId'] as String,
        rarity: CardRarity.values.firstWhere(
          (r) => r.name == (j['rarity'] as String?),
          orElse: () => CardRarity.COMMON,
        ),
        artUrl: j['artUrl'] as String? ?? '',
        playerName: j['playerName'] as String?,
        teamName: j['teamName'] as String?,
        teamCrestUrl: j['teamCrestUrl'] as String?,
        singlePrice: (j['singlePrice'] as num?)?.toInt(),
        ownedByMe: j['ownedByMe'] as bool? ?? false,
        soldOut: j['soldOut'] as bool? ?? false,
      );
  final String templateId;
  final CardRarity rarity;
  final String artUrl;
  final String? playerName;
  final String? teamName;
  final String? teamCrestUrl;
  final int? singlePrice;
  final bool ownedByMe;
  final bool soldOut;
}

/// A transparent bundle: a fixed list of cards for a fixed gem price, with
/// the "save vs buying singly" delta. No randomness — the buyer sees [cards]
/// before paying.
class CardBundleDto {
  CardBundleDto({
    required this.id,
    required this.name,
    required this.gemPrice,
    required this.cards,
    this.description,
    this.artUrl,
    this.singleTotal = 0,
    this.saving = 0,
    this.soldOut = false,
    this.dropClosesAt,
  });
  factory CardBundleDto.fromJson(Map<String, dynamic> j) => CardBundleDto(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        gemPrice: (j['gemPrice'] as num).toInt(),
        artUrl: j['artUrl'] as String?,
        cards: ((j['cards'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(BundleCardDto.fromJson)
            .toList(growable: false),
        singleTotal: (j['singleTotal'] as num?)?.toInt() ?? 0,
        saving: (j['saving'] as num?)?.toInt() ?? 0,
        soldOut: j['soldOut'] as bool? ?? false,
        dropClosesAt: j['dropClosesAt'] == null
            ? null
            : DateTime.parse(j['dropClosesAt'] as String),
      );
  final String id;
  final String name;
  final String? description;
  final int gemPrice;
  final String? artUrl;
  final List<BundleCardDto> cards;
  final int singleTotal;
  final int saving;
  final bool soldOut;
  final DateTime? dropClosesAt;

  int get cardCount => cards.length;
}

/// Minimal DTO for the store listing — separate from `CardTemplateDto`
/// because the freezed model doesn't carry `gemPrice` and the wallet
/// store only needs a few fields to render.
class StoreTemplate {
  StoreTemplate({
    required this.id,
    required this.edition,
    required this.rarity,
    required this.totalSupply,
    required this.mintedCount,
    required this.artUrl,
    required this.gemPrice,
    this.playerName,
    this.teamName,
    this.teamCrestUrl,
    this.maxPerUser,
    this.dropClosesAt,
  });
  factory StoreTemplate.fromJson(Map<String, dynamic> j) => StoreTemplate(
        id: j['id'] as String,
        edition: j['edition'] as String,
        rarity: CardRarity.values.firstWhere(
          (r) => r.name == (j['rarity'] as String),
          orElse: () => CardRarity.COMMON,
        ),
        totalSupply: (j['totalSupply'] as num?)?.toInt() ?? 0,
        mintedCount: (j['mintedCount'] as num?)?.toInt() ?? 0,
        artUrl: j['artUrl'] as String,
        gemPrice: (j['gemPrice'] as num).toInt(),
        playerName: j['playerName'] as String?,
        teamName: j['teamName'] as String?,
        teamCrestUrl: j['teamCrestUrl'] as String?,
        maxPerUser: (j['maxPerUser'] as num?)?.toInt(),
        dropClosesAt: j['dropClosesAt'] == null
            ? null
            : DateTime.parse(j['dropClosesAt'] as String),
      );
  final String id;
  final String edition;
  final CardRarity rarity;
  final int totalSupply;
  final int mintedCount;
  final String artUrl;
  final int gemPrice;
  final String? playerName;
  final String? teamName;
  final String? teamCrestUrl;
  final int? maxPerUser;
  final DateTime? dropClosesAt;

  int get remaining => (totalSupply - mintedCount).clamp(0, 1 << 30);
  bool get isSoldOut => totalSupply > 0 && mintedCount >= totalSupply;
}

final albumRepositoryProvider = Provider<AlbumRepository>((ref) => AlbumRepository(ref.read(dioProvider)));

final albumProvider = FutureProvider<List<AlbumSetDto>>((ref) async {
  return ref.read(albumRepositoryProvider).fetchAlbum();
});

final storeFeaturedProvider = FutureProvider<List<StoreTemplate>>(
  (ref) => ref.read(albumRepositoryProvider).featuredForSale(),
);

final cardBundlesProvider = FutureProvider<List<CardBundleDto>>(
  (ref) => ref.read(albumRepositoryProvider).listBundles(),
);
