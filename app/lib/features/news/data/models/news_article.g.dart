// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'news_article.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NewsArticleDto _$NewsArticleDtoFromJson(Map<String, dynamic> json) =>
    _NewsArticleDto(
      id: json['id'] as String,
      url: json['url'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String?,
      source: json['source'] as String,
      imageUrl: json['imageUrl'] as String?,
      publishedAt: DateTime.parse(json['publishedAt'] as String),
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const <String>[],
    );

Map<String, dynamic> _$NewsArticleDtoToJson(_NewsArticleDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'title': instance.title,
      'summary': instance.summary,
      'source': instance.source,
      'imageUrl': instance.imageUrl,
      'publishedAt': instance.publishedAt.toIso8601String(),
      'tags': instance.tags,
    };

_NewsPage _$NewsPageFromJson(Map<String, dynamic> json) => _NewsPage(
  items:
      (json['items'] as List<dynamic>)
          .map((e) => NewsArticleDto.fromJson(e as Map<String, dynamic>))
          .toList(),
  nextCursor: json['nextCursor'] as String?,
);

Map<String, dynamic> _$NewsPageToJson(_NewsPage instance) => <String, dynamic>{
  'items': instance.items,
  'nextCursor': instance.nextCursor,
};
