import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import '../models/news_article.dart';

class NewsRepository {
  NewsRepository(this._dio);
  final Dio _dio;

  /// List news articles. Pass either:
  ///   - `teamId` for a single-team filter (legacy home use)
  ///   - `teamIds` for a "any of these teams" filter (Following tab)
  /// When both are passed the backend OR-joins them into a single set.
  /// Empty `teamIds` is silently dropped so callers don't need to guard.
  Future<NewsPage> list({
    String? cursor,
    String? teamId,
    List<String>? teamIds,
    int limit = 20,
  }) async {
    final csv = (teamIds == null || teamIds.isEmpty)
        ? null
        : teamIds.where((t) => t.trim().isNotEmpty).join(',');
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/news',
      queryParameters: {
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
        if (teamId != null) 'teamId': teamId,
        if (csv != null && csv.isNotEmpty) 'teamIds': csv,
      },
    );
    return NewsPage.fromJson(res.data!);
  }

  Future<NewsArticleDto> byId(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/news/$id');
    return NewsArticleDto.fromJson(res.data!);
  }
}

final newsRepositoryProvider = Provider<NewsRepository>((ref) => NewsRepository(ref.read(dioProvider)));
