// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'card_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CardTemplateDto {

 String get id; String get edition; CardRarity get rarity; int get totalSupply; int get mintedCount; String get artUrl; String get frameStyle; String? get playerName; String? get teamName; String? get teamCrestUrl; String? get position;// Scarcity primitives. All optional + defaulted so older payloads parse.
 DateTime? get dropOpensAt; DateTime? get dropClosesAt; int? get maxPerUser; int get uniqueOwners;
/// Create a copy of CardTemplateDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CardTemplateDtoCopyWith<CardTemplateDto> get copyWith => _$CardTemplateDtoCopyWithImpl<CardTemplateDto>(this as CardTemplateDto, _$identity);

  /// Serializes this CardTemplateDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CardTemplateDto&&(identical(other.id, id) || other.id == id)&&(identical(other.edition, edition) || other.edition == edition)&&(identical(other.rarity, rarity) || other.rarity == rarity)&&(identical(other.totalSupply, totalSupply) || other.totalSupply == totalSupply)&&(identical(other.mintedCount, mintedCount) || other.mintedCount == mintedCount)&&(identical(other.artUrl, artUrl) || other.artUrl == artUrl)&&(identical(other.frameStyle, frameStyle) || other.frameStyle == frameStyle)&&(identical(other.playerName, playerName) || other.playerName == playerName)&&(identical(other.teamName, teamName) || other.teamName == teamName)&&(identical(other.teamCrestUrl, teamCrestUrl) || other.teamCrestUrl == teamCrestUrl)&&(identical(other.position, position) || other.position == position)&&(identical(other.dropOpensAt, dropOpensAt) || other.dropOpensAt == dropOpensAt)&&(identical(other.dropClosesAt, dropClosesAt) || other.dropClosesAt == dropClosesAt)&&(identical(other.maxPerUser, maxPerUser) || other.maxPerUser == maxPerUser)&&(identical(other.uniqueOwners, uniqueOwners) || other.uniqueOwners == uniqueOwners));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,edition,rarity,totalSupply,mintedCount,artUrl,frameStyle,playerName,teamName,teamCrestUrl,position,dropOpensAt,dropClosesAt,maxPerUser,uniqueOwners);

@override
String toString() {
  return 'CardTemplateDto(id: $id, edition: $edition, rarity: $rarity, totalSupply: $totalSupply, mintedCount: $mintedCount, artUrl: $artUrl, frameStyle: $frameStyle, playerName: $playerName, teamName: $teamName, teamCrestUrl: $teamCrestUrl, position: $position, dropOpensAt: $dropOpensAt, dropClosesAt: $dropClosesAt, maxPerUser: $maxPerUser, uniqueOwners: $uniqueOwners)';
}


}

/// @nodoc
abstract mixin class $CardTemplateDtoCopyWith<$Res>  {
  factory $CardTemplateDtoCopyWith(CardTemplateDto value, $Res Function(CardTemplateDto) _then) = _$CardTemplateDtoCopyWithImpl;
@useResult
$Res call({
 String id, String edition, CardRarity rarity, int totalSupply, int mintedCount, String artUrl, String frameStyle, String? playerName, String? teamName, String? teamCrestUrl, String? position, DateTime? dropOpensAt, DateTime? dropClosesAt, int? maxPerUser, int uniqueOwners
});




}
/// @nodoc
class _$CardTemplateDtoCopyWithImpl<$Res>
    implements $CardTemplateDtoCopyWith<$Res> {
  _$CardTemplateDtoCopyWithImpl(this._self, this._then);

  final CardTemplateDto _self;
  final $Res Function(CardTemplateDto) _then;

/// Create a copy of CardTemplateDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? edition = null,Object? rarity = null,Object? totalSupply = null,Object? mintedCount = null,Object? artUrl = null,Object? frameStyle = null,Object? playerName = freezed,Object? teamName = freezed,Object? teamCrestUrl = freezed,Object? position = freezed,Object? dropOpensAt = freezed,Object? dropClosesAt = freezed,Object? maxPerUser = freezed,Object? uniqueOwners = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,edition: null == edition ? _self.edition : edition // ignore: cast_nullable_to_non_nullable
as String,rarity: null == rarity ? _self.rarity : rarity // ignore: cast_nullable_to_non_nullable
as CardRarity,totalSupply: null == totalSupply ? _self.totalSupply : totalSupply // ignore: cast_nullable_to_non_nullable
as int,mintedCount: null == mintedCount ? _self.mintedCount : mintedCount // ignore: cast_nullable_to_non_nullable
as int,artUrl: null == artUrl ? _self.artUrl : artUrl // ignore: cast_nullable_to_non_nullable
as String,frameStyle: null == frameStyle ? _self.frameStyle : frameStyle // ignore: cast_nullable_to_non_nullable
as String,playerName: freezed == playerName ? _self.playerName : playerName // ignore: cast_nullable_to_non_nullable
as String?,teamName: freezed == teamName ? _self.teamName : teamName // ignore: cast_nullable_to_non_nullable
as String?,teamCrestUrl: freezed == teamCrestUrl ? _self.teamCrestUrl : teamCrestUrl // ignore: cast_nullable_to_non_nullable
as String?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as String?,dropOpensAt: freezed == dropOpensAt ? _self.dropOpensAt : dropOpensAt // ignore: cast_nullable_to_non_nullable
as DateTime?,dropClosesAt: freezed == dropClosesAt ? _self.dropClosesAt : dropClosesAt // ignore: cast_nullable_to_non_nullable
as DateTime?,maxPerUser: freezed == maxPerUser ? _self.maxPerUser : maxPerUser // ignore: cast_nullable_to_non_nullable
as int?,uniqueOwners: null == uniqueOwners ? _self.uniqueOwners : uniqueOwners // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CardTemplateDto].
extension CardTemplateDtoPatterns on CardTemplateDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CardTemplateDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CardTemplateDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CardTemplateDto value)  $default,){
final _that = this;
switch (_that) {
case _CardTemplateDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CardTemplateDto value)?  $default,){
final _that = this;
switch (_that) {
case _CardTemplateDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String edition,  CardRarity rarity,  int totalSupply,  int mintedCount,  String artUrl,  String frameStyle,  String? playerName,  String? teamName,  String? teamCrestUrl,  String? position,  DateTime? dropOpensAt,  DateTime? dropClosesAt,  int? maxPerUser,  int uniqueOwners)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CardTemplateDto() when $default != null:
return $default(_that.id,_that.edition,_that.rarity,_that.totalSupply,_that.mintedCount,_that.artUrl,_that.frameStyle,_that.playerName,_that.teamName,_that.teamCrestUrl,_that.position,_that.dropOpensAt,_that.dropClosesAt,_that.maxPerUser,_that.uniqueOwners);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String edition,  CardRarity rarity,  int totalSupply,  int mintedCount,  String artUrl,  String frameStyle,  String? playerName,  String? teamName,  String? teamCrestUrl,  String? position,  DateTime? dropOpensAt,  DateTime? dropClosesAt,  int? maxPerUser,  int uniqueOwners)  $default,) {final _that = this;
switch (_that) {
case _CardTemplateDto():
return $default(_that.id,_that.edition,_that.rarity,_that.totalSupply,_that.mintedCount,_that.artUrl,_that.frameStyle,_that.playerName,_that.teamName,_that.teamCrestUrl,_that.position,_that.dropOpensAt,_that.dropClosesAt,_that.maxPerUser,_that.uniqueOwners);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String edition,  CardRarity rarity,  int totalSupply,  int mintedCount,  String artUrl,  String frameStyle,  String? playerName,  String? teamName,  String? teamCrestUrl,  String? position,  DateTime? dropOpensAt,  DateTime? dropClosesAt,  int? maxPerUser,  int uniqueOwners)?  $default,) {final _that = this;
switch (_that) {
case _CardTemplateDto() when $default != null:
return $default(_that.id,_that.edition,_that.rarity,_that.totalSupply,_that.mintedCount,_that.artUrl,_that.frameStyle,_that.playerName,_that.teamName,_that.teamCrestUrl,_that.position,_that.dropOpensAt,_that.dropClosesAt,_that.maxPerUser,_that.uniqueOwners);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CardTemplateDto implements CardTemplateDto {
  const _CardTemplateDto({required this.id, required this.edition, required this.rarity, required this.totalSupply, required this.mintedCount, required this.artUrl, this.frameStyle = 'base', this.playerName, this.teamName, this.teamCrestUrl, this.position, this.dropOpensAt, this.dropClosesAt, this.maxPerUser, this.uniqueOwners = 0});
  factory _CardTemplateDto.fromJson(Map<String, dynamic> json) => _$CardTemplateDtoFromJson(json);

@override final  String id;
@override final  String edition;
@override final  CardRarity rarity;
@override final  int totalSupply;
@override final  int mintedCount;
@override final  String artUrl;
@override@JsonKey() final  String frameStyle;
@override final  String? playerName;
@override final  String? teamName;
@override final  String? teamCrestUrl;
@override final  String? position;
// Scarcity primitives. All optional + defaulted so older payloads parse.
@override final  DateTime? dropOpensAt;
@override final  DateTime? dropClosesAt;
@override final  int? maxPerUser;
@override@JsonKey() final  int uniqueOwners;

/// Create a copy of CardTemplateDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CardTemplateDtoCopyWith<_CardTemplateDto> get copyWith => __$CardTemplateDtoCopyWithImpl<_CardTemplateDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CardTemplateDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CardTemplateDto&&(identical(other.id, id) || other.id == id)&&(identical(other.edition, edition) || other.edition == edition)&&(identical(other.rarity, rarity) || other.rarity == rarity)&&(identical(other.totalSupply, totalSupply) || other.totalSupply == totalSupply)&&(identical(other.mintedCount, mintedCount) || other.mintedCount == mintedCount)&&(identical(other.artUrl, artUrl) || other.artUrl == artUrl)&&(identical(other.frameStyle, frameStyle) || other.frameStyle == frameStyle)&&(identical(other.playerName, playerName) || other.playerName == playerName)&&(identical(other.teamName, teamName) || other.teamName == teamName)&&(identical(other.teamCrestUrl, teamCrestUrl) || other.teamCrestUrl == teamCrestUrl)&&(identical(other.position, position) || other.position == position)&&(identical(other.dropOpensAt, dropOpensAt) || other.dropOpensAt == dropOpensAt)&&(identical(other.dropClosesAt, dropClosesAt) || other.dropClosesAt == dropClosesAt)&&(identical(other.maxPerUser, maxPerUser) || other.maxPerUser == maxPerUser)&&(identical(other.uniqueOwners, uniqueOwners) || other.uniqueOwners == uniqueOwners));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,edition,rarity,totalSupply,mintedCount,artUrl,frameStyle,playerName,teamName,teamCrestUrl,position,dropOpensAt,dropClosesAt,maxPerUser,uniqueOwners);

@override
String toString() {
  return 'CardTemplateDto(id: $id, edition: $edition, rarity: $rarity, totalSupply: $totalSupply, mintedCount: $mintedCount, artUrl: $artUrl, frameStyle: $frameStyle, playerName: $playerName, teamName: $teamName, teamCrestUrl: $teamCrestUrl, position: $position, dropOpensAt: $dropOpensAt, dropClosesAt: $dropClosesAt, maxPerUser: $maxPerUser, uniqueOwners: $uniqueOwners)';
}


}

/// @nodoc
abstract mixin class _$CardTemplateDtoCopyWith<$Res> implements $CardTemplateDtoCopyWith<$Res> {
  factory _$CardTemplateDtoCopyWith(_CardTemplateDto value, $Res Function(_CardTemplateDto) _then) = __$CardTemplateDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String edition, CardRarity rarity, int totalSupply, int mintedCount, String artUrl, String frameStyle, String? playerName, String? teamName, String? teamCrestUrl, String? position, DateTime? dropOpensAt, DateTime? dropClosesAt, int? maxPerUser, int uniqueOwners
});




}
/// @nodoc
class __$CardTemplateDtoCopyWithImpl<$Res>
    implements _$CardTemplateDtoCopyWith<$Res> {
  __$CardTemplateDtoCopyWithImpl(this._self, this._then);

  final _CardTemplateDto _self;
  final $Res Function(_CardTemplateDto) _then;

/// Create a copy of CardTemplateDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? edition = null,Object? rarity = null,Object? totalSupply = null,Object? mintedCount = null,Object? artUrl = null,Object? frameStyle = null,Object? playerName = freezed,Object? teamName = freezed,Object? teamCrestUrl = freezed,Object? position = freezed,Object? dropOpensAt = freezed,Object? dropClosesAt = freezed,Object? maxPerUser = freezed,Object? uniqueOwners = null,}) {
  return _then(_CardTemplateDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,edition: null == edition ? _self.edition : edition // ignore: cast_nullable_to_non_nullable
as String,rarity: null == rarity ? _self.rarity : rarity // ignore: cast_nullable_to_non_nullable
as CardRarity,totalSupply: null == totalSupply ? _self.totalSupply : totalSupply // ignore: cast_nullable_to_non_nullable
as int,mintedCount: null == mintedCount ? _self.mintedCount : mintedCount // ignore: cast_nullable_to_non_nullable
as int,artUrl: null == artUrl ? _self.artUrl : artUrl // ignore: cast_nullable_to_non_nullable
as String,frameStyle: null == frameStyle ? _self.frameStyle : frameStyle // ignore: cast_nullable_to_non_nullable
as String,playerName: freezed == playerName ? _self.playerName : playerName // ignore: cast_nullable_to_non_nullable
as String?,teamName: freezed == teamName ? _self.teamName : teamName // ignore: cast_nullable_to_non_nullable
as String?,teamCrestUrl: freezed == teamCrestUrl ? _self.teamCrestUrl : teamCrestUrl // ignore: cast_nullable_to_non_nullable
as String?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as String?,dropOpensAt: freezed == dropOpensAt ? _self.dropOpensAt : dropOpensAt // ignore: cast_nullable_to_non_nullable
as DateTime?,dropClosesAt: freezed == dropClosesAt ? _self.dropClosesAt : dropClosesAt // ignore: cast_nullable_to_non_nullable
as DateTime?,maxPerUser: freezed == maxPerUser ? _self.maxPerUser : maxPerUser // ignore: cast_nullable_to_non_nullable
as int?,uniqueOwners: null == uniqueOwners ? _self.uniqueOwners : uniqueOwners // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$AlbumEntryDto {

 String get templateId; CardTemplateDto get template; int get owned; String? get firstOwnedCardId;
/// Create a copy of AlbumEntryDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AlbumEntryDtoCopyWith<AlbumEntryDto> get copyWith => _$AlbumEntryDtoCopyWithImpl<AlbumEntryDto>(this as AlbumEntryDto, _$identity);

  /// Serializes this AlbumEntryDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AlbumEntryDto&&(identical(other.templateId, templateId) || other.templateId == templateId)&&(identical(other.template, template) || other.template == template)&&(identical(other.owned, owned) || other.owned == owned)&&(identical(other.firstOwnedCardId, firstOwnedCardId) || other.firstOwnedCardId == firstOwnedCardId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,templateId,template,owned,firstOwnedCardId);

@override
String toString() {
  return 'AlbumEntryDto(templateId: $templateId, template: $template, owned: $owned, firstOwnedCardId: $firstOwnedCardId)';
}


}

/// @nodoc
abstract mixin class $AlbumEntryDtoCopyWith<$Res>  {
  factory $AlbumEntryDtoCopyWith(AlbumEntryDto value, $Res Function(AlbumEntryDto) _then) = _$AlbumEntryDtoCopyWithImpl;
@useResult
$Res call({
 String templateId, CardTemplateDto template, int owned, String? firstOwnedCardId
});


$CardTemplateDtoCopyWith<$Res> get template;

}
/// @nodoc
class _$AlbumEntryDtoCopyWithImpl<$Res>
    implements $AlbumEntryDtoCopyWith<$Res> {
  _$AlbumEntryDtoCopyWithImpl(this._self, this._then);

  final AlbumEntryDto _self;
  final $Res Function(AlbumEntryDto) _then;

/// Create a copy of AlbumEntryDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? templateId = null,Object? template = null,Object? owned = null,Object? firstOwnedCardId = freezed,}) {
  return _then(_self.copyWith(
templateId: null == templateId ? _self.templateId : templateId // ignore: cast_nullable_to_non_nullable
as String,template: null == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as CardTemplateDto,owned: null == owned ? _self.owned : owned // ignore: cast_nullable_to_non_nullable
as int,firstOwnedCardId: freezed == firstOwnedCardId ? _self.firstOwnedCardId : firstOwnedCardId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of AlbumEntryDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CardTemplateDtoCopyWith<$Res> get template {
  
  return $CardTemplateDtoCopyWith<$Res>(_self.template, (value) {
    return _then(_self.copyWith(template: value));
  });
}
}


/// Adds pattern-matching-related methods to [AlbumEntryDto].
extension AlbumEntryDtoPatterns on AlbumEntryDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AlbumEntryDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AlbumEntryDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AlbumEntryDto value)  $default,){
final _that = this;
switch (_that) {
case _AlbumEntryDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AlbumEntryDto value)?  $default,){
final _that = this;
switch (_that) {
case _AlbumEntryDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String templateId,  CardTemplateDto template,  int owned,  String? firstOwnedCardId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AlbumEntryDto() when $default != null:
return $default(_that.templateId,_that.template,_that.owned,_that.firstOwnedCardId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String templateId,  CardTemplateDto template,  int owned,  String? firstOwnedCardId)  $default,) {final _that = this;
switch (_that) {
case _AlbumEntryDto():
return $default(_that.templateId,_that.template,_that.owned,_that.firstOwnedCardId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String templateId,  CardTemplateDto template,  int owned,  String? firstOwnedCardId)?  $default,) {final _that = this;
switch (_that) {
case _AlbumEntryDto() when $default != null:
return $default(_that.templateId,_that.template,_that.owned,_that.firstOwnedCardId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AlbumEntryDto implements AlbumEntryDto {
  const _AlbumEntryDto({required this.templateId, required this.template, required this.owned, this.firstOwnedCardId});
  factory _AlbumEntryDto.fromJson(Map<String, dynamic> json) => _$AlbumEntryDtoFromJson(json);

@override final  String templateId;
@override final  CardTemplateDto template;
@override final  int owned;
@override final  String? firstOwnedCardId;

/// Create a copy of AlbumEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AlbumEntryDtoCopyWith<_AlbumEntryDto> get copyWith => __$AlbumEntryDtoCopyWithImpl<_AlbumEntryDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AlbumEntryDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AlbumEntryDto&&(identical(other.templateId, templateId) || other.templateId == templateId)&&(identical(other.template, template) || other.template == template)&&(identical(other.owned, owned) || other.owned == owned)&&(identical(other.firstOwnedCardId, firstOwnedCardId) || other.firstOwnedCardId == firstOwnedCardId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,templateId,template,owned,firstOwnedCardId);

@override
String toString() {
  return 'AlbumEntryDto(templateId: $templateId, template: $template, owned: $owned, firstOwnedCardId: $firstOwnedCardId)';
}


}

/// @nodoc
abstract mixin class _$AlbumEntryDtoCopyWith<$Res> implements $AlbumEntryDtoCopyWith<$Res> {
  factory _$AlbumEntryDtoCopyWith(_AlbumEntryDto value, $Res Function(_AlbumEntryDto) _then) = __$AlbumEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String templateId, CardTemplateDto template, int owned, String? firstOwnedCardId
});


@override $CardTemplateDtoCopyWith<$Res> get template;

}
/// @nodoc
class __$AlbumEntryDtoCopyWithImpl<$Res>
    implements _$AlbumEntryDtoCopyWith<$Res> {
  __$AlbumEntryDtoCopyWithImpl(this._self, this._then);

  final _AlbumEntryDto _self;
  final $Res Function(_AlbumEntryDto) _then;

/// Create a copy of AlbumEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? templateId = null,Object? template = null,Object? owned = null,Object? firstOwnedCardId = freezed,}) {
  return _then(_AlbumEntryDto(
templateId: null == templateId ? _self.templateId : templateId // ignore: cast_nullable_to_non_nullable
as String,template: null == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as CardTemplateDto,owned: null == owned ? _self.owned : owned // ignore: cast_nullable_to_non_nullable
as int,firstOwnedCardId: freezed == firstOwnedCardId ? _self.firstOwnedCardId : firstOwnedCardId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of AlbumEntryDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CardTemplateDtoCopyWith<$Res> get template {
  
  return $CardTemplateDtoCopyWith<$Res>(_self.template, (value) {
    return _then(_self.copyWith(template: value));
  });
}
}


/// @nodoc
mixin _$AlbumSetDto {

 String get id; String get name; String get description; int get total; int get completedCount; List<AlbumEntryDto> get entries;
/// Create a copy of AlbumSetDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AlbumSetDtoCopyWith<AlbumSetDto> get copyWith => _$AlbumSetDtoCopyWithImpl<AlbumSetDto>(this as AlbumSetDto, _$identity);

  /// Serializes this AlbumSetDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AlbumSetDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.total, total) || other.total == total)&&(identical(other.completedCount, completedCount) || other.completedCount == completedCount)&&const DeepCollectionEquality().equals(other.entries, entries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,total,completedCount,const DeepCollectionEquality().hash(entries));

@override
String toString() {
  return 'AlbumSetDto(id: $id, name: $name, description: $description, total: $total, completedCount: $completedCount, entries: $entries)';
}


}

/// @nodoc
abstract mixin class $AlbumSetDtoCopyWith<$Res>  {
  factory $AlbumSetDtoCopyWith(AlbumSetDto value, $Res Function(AlbumSetDto) _then) = _$AlbumSetDtoCopyWithImpl;
@useResult
$Res call({
 String id, String name, String description, int total, int completedCount, List<AlbumEntryDto> entries
});




}
/// @nodoc
class _$AlbumSetDtoCopyWithImpl<$Res>
    implements $AlbumSetDtoCopyWith<$Res> {
  _$AlbumSetDtoCopyWithImpl(this._self, this._then);

  final AlbumSetDto _self;
  final $Res Function(AlbumSetDto) _then;

/// Create a copy of AlbumSetDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = null,Object? total = null,Object? completedCount = null,Object? entries = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,completedCount: null == completedCount ? _self.completedCount : completedCount // ignore: cast_nullable_to_non_nullable
as int,entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as List<AlbumEntryDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [AlbumSetDto].
extension AlbumSetDtoPatterns on AlbumSetDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AlbumSetDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AlbumSetDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AlbumSetDto value)  $default,){
final _that = this;
switch (_that) {
case _AlbumSetDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AlbumSetDto value)?  $default,){
final _that = this;
switch (_that) {
case _AlbumSetDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String description,  int total,  int completedCount,  List<AlbumEntryDto> entries)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AlbumSetDto() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.total,_that.completedCount,_that.entries);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String description,  int total,  int completedCount,  List<AlbumEntryDto> entries)  $default,) {final _that = this;
switch (_that) {
case _AlbumSetDto():
return $default(_that.id,_that.name,_that.description,_that.total,_that.completedCount,_that.entries);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String description,  int total,  int completedCount,  List<AlbumEntryDto> entries)?  $default,) {final _that = this;
switch (_that) {
case _AlbumSetDto() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.total,_that.completedCount,_that.entries);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AlbumSetDto implements AlbumSetDto {
  const _AlbumSetDto({required this.id, required this.name, required this.description, required this.total, required this.completedCount, required final  List<AlbumEntryDto> entries}): _entries = entries;
  factory _AlbumSetDto.fromJson(Map<String, dynamic> json) => _$AlbumSetDtoFromJson(json);

@override final  String id;
@override final  String name;
@override final  String description;
@override final  int total;
@override final  int completedCount;
 final  List<AlbumEntryDto> _entries;
@override List<AlbumEntryDto> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}


/// Create a copy of AlbumSetDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AlbumSetDtoCopyWith<_AlbumSetDto> get copyWith => __$AlbumSetDtoCopyWithImpl<_AlbumSetDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AlbumSetDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AlbumSetDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.total, total) || other.total == total)&&(identical(other.completedCount, completedCount) || other.completedCount == completedCount)&&const DeepCollectionEquality().equals(other._entries, _entries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,total,completedCount,const DeepCollectionEquality().hash(_entries));

@override
String toString() {
  return 'AlbumSetDto(id: $id, name: $name, description: $description, total: $total, completedCount: $completedCount, entries: $entries)';
}


}

/// @nodoc
abstract mixin class _$AlbumSetDtoCopyWith<$Res> implements $AlbumSetDtoCopyWith<$Res> {
  factory _$AlbumSetDtoCopyWith(_AlbumSetDto value, $Res Function(_AlbumSetDto) _then) = __$AlbumSetDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String description, int total, int completedCount, List<AlbumEntryDto> entries
});




}
/// @nodoc
class __$AlbumSetDtoCopyWithImpl<$Res>
    implements _$AlbumSetDtoCopyWith<$Res> {
  __$AlbumSetDtoCopyWithImpl(this._self, this._then);

  final _AlbumSetDto _self;
  final $Res Function(_AlbumSetDto) _then;

/// Create a copy of AlbumSetDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = null,Object? total = null,Object? completedCount = null,Object? entries = null,}) {
  return _then(_AlbumSetDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,completedCount: null == completedCount ? _self.completedCount : completedCount // ignore: cast_nullable_to_non_nullable
as int,entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<AlbumEntryDto>,
  ));
}


}


/// @nodoc
mixin _$OwnedCardDto {

 String get id; String get templateId; int get serialNumber; CardTemplateDto get template; DateTime get mintedAt;/// Identity & progression — populated server-side. Defaulted so older
/// /v1/cards/owned responses still parse.
 String? get mintReason; String get acquiredVia; int get lifetimeGoals; int get lifetimeAssists; int get lifetimeMinutes; int get lifetimeApps; int get xp; int get level; List<String> get trophies;
/// Create a copy of OwnedCardDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OwnedCardDtoCopyWith<OwnedCardDto> get copyWith => _$OwnedCardDtoCopyWithImpl<OwnedCardDto>(this as OwnedCardDto, _$identity);

  /// Serializes this OwnedCardDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OwnedCardDto&&(identical(other.id, id) || other.id == id)&&(identical(other.templateId, templateId) || other.templateId == templateId)&&(identical(other.serialNumber, serialNumber) || other.serialNumber == serialNumber)&&(identical(other.template, template) || other.template == template)&&(identical(other.mintedAt, mintedAt) || other.mintedAt == mintedAt)&&(identical(other.mintReason, mintReason) || other.mintReason == mintReason)&&(identical(other.acquiredVia, acquiredVia) || other.acquiredVia == acquiredVia)&&(identical(other.lifetimeGoals, lifetimeGoals) || other.lifetimeGoals == lifetimeGoals)&&(identical(other.lifetimeAssists, lifetimeAssists) || other.lifetimeAssists == lifetimeAssists)&&(identical(other.lifetimeMinutes, lifetimeMinutes) || other.lifetimeMinutes == lifetimeMinutes)&&(identical(other.lifetimeApps, lifetimeApps) || other.lifetimeApps == lifetimeApps)&&(identical(other.xp, xp) || other.xp == xp)&&(identical(other.level, level) || other.level == level)&&const DeepCollectionEquality().equals(other.trophies, trophies));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,templateId,serialNumber,template,mintedAt,mintReason,acquiredVia,lifetimeGoals,lifetimeAssists,lifetimeMinutes,lifetimeApps,xp,level,const DeepCollectionEquality().hash(trophies));

@override
String toString() {
  return 'OwnedCardDto(id: $id, templateId: $templateId, serialNumber: $serialNumber, template: $template, mintedAt: $mintedAt, mintReason: $mintReason, acquiredVia: $acquiredVia, lifetimeGoals: $lifetimeGoals, lifetimeAssists: $lifetimeAssists, lifetimeMinutes: $lifetimeMinutes, lifetimeApps: $lifetimeApps, xp: $xp, level: $level, trophies: $trophies)';
}


}

/// @nodoc
abstract mixin class $OwnedCardDtoCopyWith<$Res>  {
  factory $OwnedCardDtoCopyWith(OwnedCardDto value, $Res Function(OwnedCardDto) _then) = _$OwnedCardDtoCopyWithImpl;
@useResult
$Res call({
 String id, String templateId, int serialNumber, CardTemplateDto template, DateTime mintedAt, String? mintReason, String acquiredVia, int lifetimeGoals, int lifetimeAssists, int lifetimeMinutes, int lifetimeApps, int xp, int level, List<String> trophies
});


$CardTemplateDtoCopyWith<$Res> get template;

}
/// @nodoc
class _$OwnedCardDtoCopyWithImpl<$Res>
    implements $OwnedCardDtoCopyWith<$Res> {
  _$OwnedCardDtoCopyWithImpl(this._self, this._then);

  final OwnedCardDto _self;
  final $Res Function(OwnedCardDto) _then;

/// Create a copy of OwnedCardDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? templateId = null,Object? serialNumber = null,Object? template = null,Object? mintedAt = null,Object? mintReason = freezed,Object? acquiredVia = null,Object? lifetimeGoals = null,Object? lifetimeAssists = null,Object? lifetimeMinutes = null,Object? lifetimeApps = null,Object? xp = null,Object? level = null,Object? trophies = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,templateId: null == templateId ? _self.templateId : templateId // ignore: cast_nullable_to_non_nullable
as String,serialNumber: null == serialNumber ? _self.serialNumber : serialNumber // ignore: cast_nullable_to_non_nullable
as int,template: null == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as CardTemplateDto,mintedAt: null == mintedAt ? _self.mintedAt : mintedAt // ignore: cast_nullable_to_non_nullable
as DateTime,mintReason: freezed == mintReason ? _self.mintReason : mintReason // ignore: cast_nullable_to_non_nullable
as String?,acquiredVia: null == acquiredVia ? _self.acquiredVia : acquiredVia // ignore: cast_nullable_to_non_nullable
as String,lifetimeGoals: null == lifetimeGoals ? _self.lifetimeGoals : lifetimeGoals // ignore: cast_nullable_to_non_nullable
as int,lifetimeAssists: null == lifetimeAssists ? _self.lifetimeAssists : lifetimeAssists // ignore: cast_nullable_to_non_nullable
as int,lifetimeMinutes: null == lifetimeMinutes ? _self.lifetimeMinutes : lifetimeMinutes // ignore: cast_nullable_to_non_nullable
as int,lifetimeApps: null == lifetimeApps ? _self.lifetimeApps : lifetimeApps // ignore: cast_nullable_to_non_nullable
as int,xp: null == xp ? _self.xp : xp // ignore: cast_nullable_to_non_nullable
as int,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,trophies: null == trophies ? _self.trophies : trophies // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of OwnedCardDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CardTemplateDtoCopyWith<$Res> get template {
  
  return $CardTemplateDtoCopyWith<$Res>(_self.template, (value) {
    return _then(_self.copyWith(template: value));
  });
}
}


/// Adds pattern-matching-related methods to [OwnedCardDto].
extension OwnedCardDtoPatterns on OwnedCardDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OwnedCardDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OwnedCardDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OwnedCardDto value)  $default,){
final _that = this;
switch (_that) {
case _OwnedCardDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OwnedCardDto value)?  $default,){
final _that = this;
switch (_that) {
case _OwnedCardDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String templateId,  int serialNumber,  CardTemplateDto template,  DateTime mintedAt,  String? mintReason,  String acquiredVia,  int lifetimeGoals,  int lifetimeAssists,  int lifetimeMinutes,  int lifetimeApps,  int xp,  int level,  List<String> trophies)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OwnedCardDto() when $default != null:
return $default(_that.id,_that.templateId,_that.serialNumber,_that.template,_that.mintedAt,_that.mintReason,_that.acquiredVia,_that.lifetimeGoals,_that.lifetimeAssists,_that.lifetimeMinutes,_that.lifetimeApps,_that.xp,_that.level,_that.trophies);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String templateId,  int serialNumber,  CardTemplateDto template,  DateTime mintedAt,  String? mintReason,  String acquiredVia,  int lifetimeGoals,  int lifetimeAssists,  int lifetimeMinutes,  int lifetimeApps,  int xp,  int level,  List<String> trophies)  $default,) {final _that = this;
switch (_that) {
case _OwnedCardDto():
return $default(_that.id,_that.templateId,_that.serialNumber,_that.template,_that.mintedAt,_that.mintReason,_that.acquiredVia,_that.lifetimeGoals,_that.lifetimeAssists,_that.lifetimeMinutes,_that.lifetimeApps,_that.xp,_that.level,_that.trophies);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String templateId,  int serialNumber,  CardTemplateDto template,  DateTime mintedAt,  String? mintReason,  String acquiredVia,  int lifetimeGoals,  int lifetimeAssists,  int lifetimeMinutes,  int lifetimeApps,  int xp,  int level,  List<String> trophies)?  $default,) {final _that = this;
switch (_that) {
case _OwnedCardDto() when $default != null:
return $default(_that.id,_that.templateId,_that.serialNumber,_that.template,_that.mintedAt,_that.mintReason,_that.acquiredVia,_that.lifetimeGoals,_that.lifetimeAssists,_that.lifetimeMinutes,_that.lifetimeApps,_that.xp,_that.level,_that.trophies);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OwnedCardDto implements OwnedCardDto {
  const _OwnedCardDto({required this.id, required this.templateId, required this.serialNumber, required this.template, required this.mintedAt, this.mintReason = null, this.acquiredVia = 'SIGNUP_GIFT', this.lifetimeGoals = 0, this.lifetimeAssists = 0, this.lifetimeMinutes = 0, this.lifetimeApps = 0, this.xp = 0, this.level = 0, final  List<String> trophies = const <String>[]}): _trophies = trophies;
  factory _OwnedCardDto.fromJson(Map<String, dynamic> json) => _$OwnedCardDtoFromJson(json);

@override final  String id;
@override final  String templateId;
@override final  int serialNumber;
@override final  CardTemplateDto template;
@override final  DateTime mintedAt;
/// Identity & progression — populated server-side. Defaulted so older
/// /v1/cards/owned responses still parse.
@override@JsonKey() final  String? mintReason;
@override@JsonKey() final  String acquiredVia;
@override@JsonKey() final  int lifetimeGoals;
@override@JsonKey() final  int lifetimeAssists;
@override@JsonKey() final  int lifetimeMinutes;
@override@JsonKey() final  int lifetimeApps;
@override@JsonKey() final  int xp;
@override@JsonKey() final  int level;
 final  List<String> _trophies;
@override@JsonKey() List<String> get trophies {
  if (_trophies is EqualUnmodifiableListView) return _trophies;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_trophies);
}


/// Create a copy of OwnedCardDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OwnedCardDtoCopyWith<_OwnedCardDto> get copyWith => __$OwnedCardDtoCopyWithImpl<_OwnedCardDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OwnedCardDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OwnedCardDto&&(identical(other.id, id) || other.id == id)&&(identical(other.templateId, templateId) || other.templateId == templateId)&&(identical(other.serialNumber, serialNumber) || other.serialNumber == serialNumber)&&(identical(other.template, template) || other.template == template)&&(identical(other.mintedAt, mintedAt) || other.mintedAt == mintedAt)&&(identical(other.mintReason, mintReason) || other.mintReason == mintReason)&&(identical(other.acquiredVia, acquiredVia) || other.acquiredVia == acquiredVia)&&(identical(other.lifetimeGoals, lifetimeGoals) || other.lifetimeGoals == lifetimeGoals)&&(identical(other.lifetimeAssists, lifetimeAssists) || other.lifetimeAssists == lifetimeAssists)&&(identical(other.lifetimeMinutes, lifetimeMinutes) || other.lifetimeMinutes == lifetimeMinutes)&&(identical(other.lifetimeApps, lifetimeApps) || other.lifetimeApps == lifetimeApps)&&(identical(other.xp, xp) || other.xp == xp)&&(identical(other.level, level) || other.level == level)&&const DeepCollectionEquality().equals(other._trophies, _trophies));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,templateId,serialNumber,template,mintedAt,mintReason,acquiredVia,lifetimeGoals,lifetimeAssists,lifetimeMinutes,lifetimeApps,xp,level,const DeepCollectionEquality().hash(_trophies));

@override
String toString() {
  return 'OwnedCardDto(id: $id, templateId: $templateId, serialNumber: $serialNumber, template: $template, mintedAt: $mintedAt, mintReason: $mintReason, acquiredVia: $acquiredVia, lifetimeGoals: $lifetimeGoals, lifetimeAssists: $lifetimeAssists, lifetimeMinutes: $lifetimeMinutes, lifetimeApps: $lifetimeApps, xp: $xp, level: $level, trophies: $trophies)';
}


}

/// @nodoc
abstract mixin class _$OwnedCardDtoCopyWith<$Res> implements $OwnedCardDtoCopyWith<$Res> {
  factory _$OwnedCardDtoCopyWith(_OwnedCardDto value, $Res Function(_OwnedCardDto) _then) = __$OwnedCardDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String templateId, int serialNumber, CardTemplateDto template, DateTime mintedAt, String? mintReason, String acquiredVia, int lifetimeGoals, int lifetimeAssists, int lifetimeMinutes, int lifetimeApps, int xp, int level, List<String> trophies
});


@override $CardTemplateDtoCopyWith<$Res> get template;

}
/// @nodoc
class __$OwnedCardDtoCopyWithImpl<$Res>
    implements _$OwnedCardDtoCopyWith<$Res> {
  __$OwnedCardDtoCopyWithImpl(this._self, this._then);

  final _OwnedCardDto _self;
  final $Res Function(_OwnedCardDto) _then;

/// Create a copy of OwnedCardDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? templateId = null,Object? serialNumber = null,Object? template = null,Object? mintedAt = null,Object? mintReason = freezed,Object? acquiredVia = null,Object? lifetimeGoals = null,Object? lifetimeAssists = null,Object? lifetimeMinutes = null,Object? lifetimeApps = null,Object? xp = null,Object? level = null,Object? trophies = null,}) {
  return _then(_OwnedCardDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,templateId: null == templateId ? _self.templateId : templateId // ignore: cast_nullable_to_non_nullable
as String,serialNumber: null == serialNumber ? _self.serialNumber : serialNumber // ignore: cast_nullable_to_non_nullable
as int,template: null == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as CardTemplateDto,mintedAt: null == mintedAt ? _self.mintedAt : mintedAt // ignore: cast_nullable_to_non_nullable
as DateTime,mintReason: freezed == mintReason ? _self.mintReason : mintReason // ignore: cast_nullable_to_non_nullable
as String?,acquiredVia: null == acquiredVia ? _self.acquiredVia : acquiredVia // ignore: cast_nullable_to_non_nullable
as String,lifetimeGoals: null == lifetimeGoals ? _self.lifetimeGoals : lifetimeGoals // ignore: cast_nullable_to_non_nullable
as int,lifetimeAssists: null == lifetimeAssists ? _self.lifetimeAssists : lifetimeAssists // ignore: cast_nullable_to_non_nullable
as int,lifetimeMinutes: null == lifetimeMinutes ? _self.lifetimeMinutes : lifetimeMinutes // ignore: cast_nullable_to_non_nullable
as int,lifetimeApps: null == lifetimeApps ? _self.lifetimeApps : lifetimeApps // ignore: cast_nullable_to_non_nullable
as int,xp: null == xp ? _self.xp : xp // ignore: cast_nullable_to_non_nullable
as int,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,trophies: null == trophies ? _self._trophies : trophies // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of OwnedCardDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CardTemplateDtoCopyWith<$Res> get template {
  
  return $CardTemplateDtoCopyWith<$Res>(_self.template, (value) {
    return _then(_self.copyWith(template: value));
  });
}
}

// dart format on
