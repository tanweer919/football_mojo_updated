import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'market_models.dart';

/// Thin Dio wrapper for the cards marketplace API. Endpoints are open to
/// anonymous browsing — the optional bearer interceptor will attach the
/// Firebase token when available so responses enrich with "owned by me".
class MarketRepository {
  MarketRepository(this._dio);
  final Dio _dio;

  Future<MarketPage> list(MarketFilters filters, {String? cursor, int limit = 24}) async {
    final qp = <String, dynamic>{
      ...filters.toQuery(),
      'limit': limit,
      if (cursor != null) 'cursor': cursor,
    };
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/cards/market',
      queryParameters: qp,
    );
    return MarketPage.fromJson(res.data!);
  }

  Future<MarketFacets> facets() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/cards/market/facets');
    return MarketFacets.fromJson(res.data!);
  }

  Future<MarketTemplateDetail> detail(String templateId) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/cards/market/$templateId');
    return MarketTemplateDetail.fromJson(res.data!);
  }

  Future<MarketHistoryPage> history(String templateId, {String? cursor, int limit = 50}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/cards/market/$templateId/history',
      queryParameters: {
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
    );
    return MarketHistoryPage.fromJson(res.data!);
  }
}

final marketRepositoryProvider = Provider<MarketRepository>(
  (ref) => MarketRepository(ref.read(dioProvider)),
);

/// First-page fetch keyed by filter state. Pagination is handled in-screen
/// (AsyncNotifier) so we don't fire one provider per cursor.
final marketFirstPageProvider =
    FutureProvider.family<MarketPage, MarketFilters>((ref, filters) {
  return ref.read(marketRepositoryProvider).list(filters);
});

/// Facet buckets — cached for the session; the catalogue grows slowly so
/// a stale-while-revalidate behaviour is acceptable.
final marketFacetsProvider = FutureProvider<MarketFacets>((ref) {
  return ref.read(marketRepositoryProvider).facets();
});

final marketTemplateProvider =
    FutureProvider.family<MarketTemplateDetail, String>((ref, templateId) {
  return ref.read(marketRepositoryProvider).detail(templateId);
});

final marketHistoryProvider =
    FutureProvider.family<MarketHistoryPage, String>((ref, templateId) {
  return ref.read(marketRepositoryProvider).history(templateId);
});
