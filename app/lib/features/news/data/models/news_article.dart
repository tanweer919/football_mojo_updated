import 'package:freezed_annotation/freezed_annotation.dart';

part 'news_article.freezed.dart';
part 'news_article.g.dart';

@freezed
abstract class NewsArticleDto with _$NewsArticleDto {
  const factory NewsArticleDto({
    required String id,
    required String url,
    required String title,
    String? summary,
    required String source,
    String? imageUrl,
    required DateTime publishedAt,
    @Default(<String>[]) List<String> tags,
  }) = _NewsArticleDto;

  factory NewsArticleDto.fromJson(Map<String, dynamic> json) => _$NewsArticleDtoFromJson(json);
}

@freezed
abstract class NewsPage with _$NewsPage {
  const factory NewsPage({
    required List<NewsArticleDto> items,
    String? nextCursor,
  }) = _NewsPage;

  factory NewsPage.fromJson(Map<String, dynamic> json) => _$NewsPageFromJson(json);
}
