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
