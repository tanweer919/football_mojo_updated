import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import '../models/news_article.dart';

class NewsRepository {
  NewsRepository(this._dio);
  final Dio _dio;

  Future<NewsPage> list({String? cursor, String? teamId, int limit = 20}) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/news', queryParameters: {
      'limit': limit,
      if (cursor != null) 'cursor': cursor,
      if (teamId != null) 'teamId': teamId,
    });
    return NewsPage.fromJson(res.data!);
  }

  Future<NewsArticleDto> byId(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/news/$id');
    return NewsArticleDto.fromJson(res.data!);
  }
}

final newsRepositoryProvider = Provider<NewsRepository>((ref) => NewsRepository(ref.read(dioProvider)));
