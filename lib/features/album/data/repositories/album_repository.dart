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
}

final albumRepositoryProvider = Provider<AlbumRepository>((ref) => AlbumRepository(ref.read(dioProvider)));

final albumProvider = FutureProvider<List<AlbumSetDto>>((ref) async {
  return ref.read(albumRepositoryProvider).fetchAlbum();
});
