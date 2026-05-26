// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'news_article.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NewsArticleDto {

 String get id; String get url; String get title; String? get summary; String get source; String? get imageUrl; DateTime get publishedAt; List<String> get tags;
/// Create a copy of NewsArticleDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewsArticleDtoCopyWith<NewsArticleDto> get copyWith => _$NewsArticleDtoCopyWithImpl<NewsArticleDto>(this as NewsArticleDto, _$identity);

  /// Serializes this NewsArticleDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewsArticleDto&&(identical(other.id, id) || other.id == id)&&(identical(other.url, url) || other.url == url)&&(identical(other.title, title) || other.title == title)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.source, source) || other.source == source)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt)&&const DeepCollectionEquality().equals(other.tags, tags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,url,title,summary,source,imageUrl,publishedAt,const DeepCollectionEquality().hash(tags));

@override
String toString() {
  return 'NewsArticleDto(id: $id, url: $url, title: $title, summary: $summary, source: $source, imageUrl: $imageUrl, publishedAt: $publishedAt, tags: $tags)';
}


}

/// @nodoc
abstract mixin class $NewsArticleDtoCopyWith<$Res>  {
  factory $NewsArticleDtoCopyWith(NewsArticleDto value, $Res Function(NewsArticleDto) _then) = _$NewsArticleDtoCopyWithImpl;
@useResult
$Res call({
 String id, String url, String title, String? summary, String source, String? imageUrl, DateTime publishedAt, List<String> tags
});




}
/// @nodoc
class _$NewsArticleDtoCopyWithImpl<$Res>
    implements $NewsArticleDtoCopyWith<$Res> {
  _$NewsArticleDtoCopyWithImpl(this._self, this._then);

  final NewsArticleDto _self;
  final $Res Function(NewsArticleDto) _then;

/// Create a copy of NewsArticleDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? url = null,Object? title = null,Object? summary = freezed,Object? source = null,Object? imageUrl = freezed,Object? publishedAt = null,Object? tags = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String?,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,publishedAt: null == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [NewsArticleDto].
extension NewsArticleDtoPatterns on NewsArticleDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NewsArticleDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NewsArticleDto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NewsArticleDto value)  $default,){
final _that = this;
switch (_that) {
case _NewsArticleDto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NewsArticleDto value)?  $default,){
final _that = this;
switch (_that) {
case _NewsArticleDto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String url,  String title,  String? summary,  String source,  String? imageUrl,  DateTime publishedAt,  List<String> tags)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NewsArticleDto() when $default != null:
return $default(_that.id,_that.url,_that.title,_that.summary,_that.source,_that.imageUrl,_that.publishedAt,_that.tags);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String url,  String title,  String? summary,  String source,  String? imageUrl,  DateTime publishedAt,  List<String> tags)  $default,) {final _that = this;
switch (_that) {
case _NewsArticleDto():
return $default(_that.id,_that.url,_that.title,_that.summary,_that.source,_that.imageUrl,_that.publishedAt,_that.tags);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String url,  String title,  String? summary,  String source,  String? imageUrl,  DateTime publishedAt,  List<String> tags)?  $default,) {final _that = this;
switch (_that) {
case _NewsArticleDto() when $default != null:
return $default(_that.id,_that.url,_that.title,_that.summary,_that.source,_that.imageUrl,_that.publishedAt,_that.tags);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NewsArticleDto implements NewsArticleDto {
  const _NewsArticleDto({required this.id, required this.url, required this.title, this.summary, required this.source, this.imageUrl, required this.publishedAt, final  List<String> tags = const <String>[]}): _tags = tags;
  factory _NewsArticleDto.fromJson(Map<String, dynamic> json) => _$NewsArticleDtoFromJson(json);

@override final  String id;
@override final  String url;
@override final  String title;
@override final  String? summary;
@override final  String source;
@override final  String? imageUrl;
@override final  DateTime publishedAt;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}


/// Create a copy of NewsArticleDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NewsArticleDtoCopyWith<_NewsArticleDto> get copyWith => __$NewsArticleDtoCopyWithImpl<_NewsArticleDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NewsArticleDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NewsArticleDto&&(identical(other.id, id) || other.id == id)&&(identical(other.url, url) || other.url == url)&&(identical(other.title, title) || other.title == title)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.source, source) || other.source == source)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt)&&const DeepCollectionEquality().equals(other._tags, _tags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,url,title,summary,source,imageUrl,publishedAt,const DeepCollectionEquality().hash(_tags));

@override
String toString() {
  return 'NewsArticleDto(id: $id, url: $url, title: $title, summary: $summary, source: $source, imageUrl: $imageUrl, publishedAt: $publishedAt, tags: $tags)';
}


}

/// @nodoc
abstract mixin class _$NewsArticleDtoCopyWith<$Res> implements $NewsArticleDtoCopyWith<$Res> {
  factory _$NewsArticleDtoCopyWith(_NewsArticleDto value, $Res Function(_NewsArticleDto) _then) = __$NewsArticleDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String url, String title, String? summary, String source, String? imageUrl, DateTime publishedAt, List<String> tags
});




}
/// @nodoc
class __$NewsArticleDtoCopyWithImpl<$Res>
    implements _$NewsArticleDtoCopyWith<$Res> {
  __$NewsArticleDtoCopyWithImpl(this._self, this._then);

  final _NewsArticleDto _self;
  final $Res Function(_NewsArticleDto) _then;

/// Create a copy of NewsArticleDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? url = null,Object? title = null,Object? summary = freezed,Object? source = null,Object? imageUrl = freezed,Object? publishedAt = null,Object? tags = null,}) {
  return _then(_NewsArticleDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String?,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,publishedAt: null == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$NewsPage {

 List<NewsArticleDto> get items; String? get nextCursor;
/// Create a copy of NewsPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewsPageCopyWith<NewsPage> get copyWith => _$NewsPageCopyWithImpl<NewsPage>(this as NewsPage, _$identity);

  /// Serializes this NewsPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewsPage&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),nextCursor);

@override
String toString() {
  return 'NewsPage(items: $items, nextCursor: $nextCursor)';
}


}

/// @nodoc
abstract mixin class $NewsPageCopyWith<$Res>  {
  factory $NewsPageCopyWith(NewsPage value, $Res Function(NewsPage) _then) = _$NewsPageCopyWithImpl;
@useResult
$Res call({
 List<NewsArticleDto> items, String? nextCursor
});




}
/// @nodoc
class _$NewsPageCopyWithImpl<$Res>
    implements $NewsPageCopyWith<$Res> {
  _$NewsPageCopyWithImpl(this._self, this._then);

  final NewsPage _self;
  final $Res Function(NewsPage) _then;

/// Create a copy of NewsPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? nextCursor = freezed,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<NewsArticleDto>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [NewsPage].
extension NewsPagePatterns on NewsPage {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NewsPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NewsPage() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NewsPage value)  $default,){
final _that = this;
switch (_that) {
case _NewsPage():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NewsPage value)?  $default,){
final _that = this;
switch (_that) {
case _NewsPage() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<NewsArticleDto> items,  String? nextCursor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NewsPage() when $default != null:
return $default(_that.items,_that.nextCursor);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<NewsArticleDto> items,  String? nextCursor)  $default,) {final _that = this;
switch (_that) {
case _NewsPage():
return $default(_that.items,_that.nextCursor);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<NewsArticleDto> items,  String? nextCursor)?  $default,) {final _that = this;
switch (_that) {
case _NewsPage() when $default != null:
return $default(_that.items,_that.nextCursor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NewsPage implements NewsPage {
  const _NewsPage({required final  List<NewsArticleDto> items, this.nextCursor}): _items = items;
  factory _NewsPage.fromJson(Map<String, dynamic> json) => _$NewsPageFromJson(json);

 final  List<NewsArticleDto> _items;
@override List<NewsArticleDto> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  String? nextCursor;

/// Create a copy of NewsPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NewsPageCopyWith<_NewsPage> get copyWith => __$NewsPageCopyWithImpl<_NewsPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NewsPageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NewsPage&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),nextCursor);

@override
String toString() {
  return 'NewsPage(items: $items, nextCursor: $nextCursor)';
}


}

/// @nodoc
abstract mixin class _$NewsPageCopyWith<$Res> implements $NewsPageCopyWith<$Res> {
  factory _$NewsPageCopyWith(_NewsPage value, $Res Function(_NewsPage) _then) = __$NewsPageCopyWithImpl;
@override @useResult
$Res call({
 List<NewsArticleDto> items, String? nextCursor
});




}
/// @nodoc
class __$NewsPageCopyWithImpl<$Res>
    implements _$NewsPageCopyWith<$Res> {
  __$NewsPageCopyWithImpl(this._self, this._then);

  final _NewsPage _self;
  final $Res Function(_NewsPage) _then;

/// Create a copy of NewsPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? nextCursor = freezed,}) {
  return _then(_NewsPage(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<NewsArticleDto>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
