// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'match_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TeamDto {

 String get id; String get name; String? get shortName; String? get crestUrl;
/// Create a copy of TeamDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TeamDtoCopyWith<TeamDto> get copyWith => _$TeamDtoCopyWithImpl<TeamDto>(this as TeamDto, _$identity);

  /// Serializes this TeamDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TeamDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.shortName, shortName) || other.shortName == shortName)&&(identical(other.crestUrl, crestUrl) || other.crestUrl == crestUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,shortName,crestUrl);

@override
String toString() {
  return 'TeamDto(id: $id, name: $name, shortName: $shortName, crestUrl: $crestUrl)';
}


}

/// @nodoc
abstract mixin class $TeamDtoCopyWith<$Res>  {
  factory $TeamDtoCopyWith(TeamDto value, $Res Function(TeamDto) _then) = _$TeamDtoCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? shortName, String? crestUrl
});




}
/// @nodoc
class _$TeamDtoCopyWithImpl<$Res>
    implements $TeamDtoCopyWith<$Res> {
  _$TeamDtoCopyWithImpl(this._self, this._then);

  final TeamDto _self;
  final $Res Function(TeamDto) _then;

/// Create a copy of TeamDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? shortName = freezed,Object? crestUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,shortName: freezed == shortName ? _self.shortName : shortName // ignore: cast_nullable_to_non_nullable
as String?,crestUrl: freezed == crestUrl ? _self.crestUrl : crestUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TeamDto].
extension TeamDtoPatterns on TeamDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TeamDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TeamDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TeamDto value)  $default,){
final _that = this;
switch (_that) {
case _TeamDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TeamDto value)?  $default,){
final _that = this;
switch (_that) {
case _TeamDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? shortName,  String? crestUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TeamDto() when $default != null:
return $default(_that.id,_that.name,_that.shortName,_that.crestUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? shortName,  String? crestUrl)  $default,) {final _that = this;
switch (_that) {
case _TeamDto():
return $default(_that.id,_that.name,_that.shortName,_that.crestUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? shortName,  String? crestUrl)?  $default,) {final _that = this;
switch (_that) {
case _TeamDto() when $default != null:
return $default(_that.id,_that.name,_that.shortName,_that.crestUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TeamDto implements TeamDto {
  const _TeamDto({required this.id, required this.name, this.shortName, this.crestUrl});
  factory _TeamDto.fromJson(Map<String, dynamic> json) => _$TeamDtoFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? shortName;
@override final  String? crestUrl;

/// Create a copy of TeamDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TeamDtoCopyWith<_TeamDto> get copyWith => __$TeamDtoCopyWithImpl<_TeamDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TeamDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TeamDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.shortName, shortName) || other.shortName == shortName)&&(identical(other.crestUrl, crestUrl) || other.crestUrl == crestUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,shortName,crestUrl);

@override
String toString() {
  return 'TeamDto(id: $id, name: $name, shortName: $shortName, crestUrl: $crestUrl)';
}


}

/// @nodoc
abstract mixin class _$TeamDtoCopyWith<$Res> implements $TeamDtoCopyWith<$Res> {
  factory _$TeamDtoCopyWith(_TeamDto value, $Res Function(_TeamDto) _then) = __$TeamDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? shortName, String? crestUrl
});




}
/// @nodoc
class __$TeamDtoCopyWithImpl<$Res>
    implements _$TeamDtoCopyWith<$Res> {
  __$TeamDtoCopyWithImpl(this._self, this._then);

  final _TeamDto _self;
  final $Res Function(_TeamDto) _then;

/// Create a copy of TeamDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? shortName = freezed,Object? crestUrl = freezed,}) {
  return _then(_TeamDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,shortName: freezed == shortName ? _self.shortName : shortName // ignore: cast_nullable_to_non_nullable
as String?,crestUrl: freezed == crestUrl ? _self.crestUrl : crestUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$MatchDto {

 String get id; String get competitionId; TeamDto get homeTeam; TeamDto get awayTeam; DateTime get kickoffAt; MatchStatus get status; int? get minute; int? get minuteExtra; int get homeScore; int get awayScore; int? get homePenalties; int? get awayPenalties; String? get stage; String? get venue;
/// Create a copy of MatchDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MatchDtoCopyWith<MatchDto> get copyWith => _$MatchDtoCopyWithImpl<MatchDto>(this as MatchDto, _$identity);

  /// Serializes this MatchDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MatchDto&&(identical(other.id, id) || other.id == id)&&(identical(other.competitionId, competitionId) || other.competitionId == competitionId)&&(identical(other.homeTeam, homeTeam) || other.homeTeam == homeTeam)&&(identical(other.awayTeam, awayTeam) || other.awayTeam == awayTeam)&&(identical(other.kickoffAt, kickoffAt) || other.kickoffAt == kickoffAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.minute, minute) || other.minute == minute)&&(identical(other.minuteExtra, minuteExtra) || other.minuteExtra == minuteExtra)&&(identical(other.homeScore, homeScore) || other.homeScore == homeScore)&&(identical(other.awayScore, awayScore) || other.awayScore == awayScore)&&(identical(other.homePenalties, homePenalties) || other.homePenalties == homePenalties)&&(identical(other.awayPenalties, awayPenalties) || other.awayPenalties == awayPenalties)&&(identical(other.stage, stage) || other.stage == stage)&&(identical(other.venue, venue) || other.venue == venue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,competitionId,homeTeam,awayTeam,kickoffAt,status,minute,minuteExtra,homeScore,awayScore,homePenalties,awayPenalties,stage,venue);

@override
String toString() {
  return 'MatchDto(id: $id, competitionId: $competitionId, homeTeam: $homeTeam, awayTeam: $awayTeam, kickoffAt: $kickoffAt, status: $status, minute: $minute, minuteExtra: $minuteExtra, homeScore: $homeScore, awayScore: $awayScore, homePenalties: $homePenalties, awayPenalties: $awayPenalties, stage: $stage, venue: $venue)';
}


}

/// @nodoc
abstract mixin class $MatchDtoCopyWith<$Res>  {
  factory $MatchDtoCopyWith(MatchDto value, $Res Function(MatchDto) _then) = _$MatchDtoCopyWithImpl;
@useResult
$Res call({
 String id, String competitionId, TeamDto homeTeam, TeamDto awayTeam, DateTime kickoffAt, MatchStatus status, int? minute, int? minuteExtra, int homeScore, int awayScore, int? homePenalties, int? awayPenalties, String? stage, String? venue
});


$TeamDtoCopyWith<$Res> get homeTeam;$TeamDtoCopyWith<$Res> get awayTeam;

}
/// @nodoc
class _$MatchDtoCopyWithImpl<$Res>
    implements $MatchDtoCopyWith<$Res> {
  _$MatchDtoCopyWithImpl(this._self, this._then);

  final MatchDto _self;
  final $Res Function(MatchDto) _then;

/// Create a copy of MatchDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? competitionId = null,Object? homeTeam = null,Object? awayTeam = null,Object? kickoffAt = null,Object? status = null,Object? minute = freezed,Object? minuteExtra = freezed,Object? homeScore = null,Object? awayScore = null,Object? homePenalties = freezed,Object? awayPenalties = freezed,Object? stage = freezed,Object? venue = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,competitionId: null == competitionId ? _self.competitionId : competitionId // ignore: cast_nullable_to_non_nullable
as String,homeTeam: null == homeTeam ? _self.homeTeam : homeTeam // ignore: cast_nullable_to_non_nullable
as TeamDto,awayTeam: null == awayTeam ? _self.awayTeam : awayTeam // ignore: cast_nullable_to_non_nullable
as TeamDto,kickoffAt: null == kickoffAt ? _self.kickoffAt : kickoffAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MatchStatus,minute: freezed == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int?,minuteExtra: freezed == minuteExtra ? _self.minuteExtra : minuteExtra // ignore: cast_nullable_to_non_nullable
as int?,homeScore: null == homeScore ? _self.homeScore : homeScore // ignore: cast_nullable_to_non_nullable
as int,awayScore: null == awayScore ? _self.awayScore : awayScore // ignore: cast_nullable_to_non_nullable
as int,homePenalties: freezed == homePenalties ? _self.homePenalties : homePenalties // ignore: cast_nullable_to_non_nullable
as int?,awayPenalties: freezed == awayPenalties ? _self.awayPenalties : awayPenalties // ignore: cast_nullable_to_non_nullable
as int?,stage: freezed == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as String?,venue: freezed == venue ? _self.venue : venue // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of MatchDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamDtoCopyWith<$Res> get homeTeam {
  
  return $TeamDtoCopyWith<$Res>(_self.homeTeam, (value) {
    return _then(_self.copyWith(homeTeam: value));
  });
}/// Create a copy of MatchDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamDtoCopyWith<$Res> get awayTeam {
  
  return $TeamDtoCopyWith<$Res>(_self.awayTeam, (value) {
    return _then(_self.copyWith(awayTeam: value));
  });
}
}


/// Adds pattern-matching-related methods to [MatchDto].
extension MatchDtoPatterns on MatchDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MatchDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MatchDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MatchDto value)  $default,){
final _that = this;
switch (_that) {
case _MatchDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MatchDto value)?  $default,){
final _that = this;
switch (_that) {
case _MatchDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String competitionId,  TeamDto homeTeam,  TeamDto awayTeam,  DateTime kickoffAt,  MatchStatus status,  int? minute,  int? minuteExtra,  int homeScore,  int awayScore,  int? homePenalties,  int? awayPenalties,  String? stage,  String? venue)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MatchDto() when $default != null:
return $default(_that.id,_that.competitionId,_that.homeTeam,_that.awayTeam,_that.kickoffAt,_that.status,_that.minute,_that.minuteExtra,_that.homeScore,_that.awayScore,_that.homePenalties,_that.awayPenalties,_that.stage,_that.venue);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String competitionId,  TeamDto homeTeam,  TeamDto awayTeam,  DateTime kickoffAt,  MatchStatus status,  int? minute,  int? minuteExtra,  int homeScore,  int awayScore,  int? homePenalties,  int? awayPenalties,  String? stage,  String? venue)  $default,) {final _that = this;
switch (_that) {
case _MatchDto():
return $default(_that.id,_that.competitionId,_that.homeTeam,_that.awayTeam,_that.kickoffAt,_that.status,_that.minute,_that.minuteExtra,_that.homeScore,_that.awayScore,_that.homePenalties,_that.awayPenalties,_that.stage,_that.venue);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String competitionId,  TeamDto homeTeam,  TeamDto awayTeam,  DateTime kickoffAt,  MatchStatus status,  int? minute,  int? minuteExtra,  int homeScore,  int awayScore,  int? homePenalties,  int? awayPenalties,  String? stage,  String? venue)?  $default,) {final _that = this;
switch (_that) {
case _MatchDto() when $default != null:
return $default(_that.id,_that.competitionId,_that.homeTeam,_that.awayTeam,_that.kickoffAt,_that.status,_that.minute,_that.minuteExtra,_that.homeScore,_that.awayScore,_that.homePenalties,_that.awayPenalties,_that.stage,_that.venue);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MatchDto extends MatchDto {
  const _MatchDto({required this.id, required this.competitionId, required this.homeTeam, required this.awayTeam, required this.kickoffAt, required this.status, this.minute, this.minuteExtra, this.homeScore = 0, this.awayScore = 0, this.homePenalties, this.awayPenalties, this.stage, this.venue}): super._();
  factory _MatchDto.fromJson(Map<String, dynamic> json) => _$MatchDtoFromJson(json);

@override final  String id;
@override final  String competitionId;
@override final  TeamDto homeTeam;
@override final  TeamDto awayTeam;
@override final  DateTime kickoffAt;
@override final  MatchStatus status;
@override final  int? minute;
@override final  int? minuteExtra;
@override@JsonKey() final  int homeScore;
@override@JsonKey() final  int awayScore;
@override final  int? homePenalties;
@override final  int? awayPenalties;
@override final  String? stage;
@override final  String? venue;

/// Create a copy of MatchDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MatchDtoCopyWith<_MatchDto> get copyWith => __$MatchDtoCopyWithImpl<_MatchDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MatchDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MatchDto&&(identical(other.id, id) || other.id == id)&&(identical(other.competitionId, competitionId) || other.competitionId == competitionId)&&(identical(other.homeTeam, homeTeam) || other.homeTeam == homeTeam)&&(identical(other.awayTeam, awayTeam) || other.awayTeam == awayTeam)&&(identical(other.kickoffAt, kickoffAt) || other.kickoffAt == kickoffAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.minute, minute) || other.minute == minute)&&(identical(other.minuteExtra, minuteExtra) || other.minuteExtra == minuteExtra)&&(identical(other.homeScore, homeScore) || other.homeScore == homeScore)&&(identical(other.awayScore, awayScore) || other.awayScore == awayScore)&&(identical(other.homePenalties, homePenalties) || other.homePenalties == homePenalties)&&(identical(other.awayPenalties, awayPenalties) || other.awayPenalties == awayPenalties)&&(identical(other.stage, stage) || other.stage == stage)&&(identical(other.venue, venue) || other.venue == venue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,competitionId,homeTeam,awayTeam,kickoffAt,status,minute,minuteExtra,homeScore,awayScore,homePenalties,awayPenalties,stage,venue);

@override
String toString() {
  return 'MatchDto(id: $id, competitionId: $competitionId, homeTeam: $homeTeam, awayTeam: $awayTeam, kickoffAt: $kickoffAt, status: $status, minute: $minute, minuteExtra: $minuteExtra, homeScore: $homeScore, awayScore: $awayScore, homePenalties: $homePenalties, awayPenalties: $awayPenalties, stage: $stage, venue: $venue)';
}


}

/// @nodoc
abstract mixin class _$MatchDtoCopyWith<$Res> implements $MatchDtoCopyWith<$Res> {
  factory _$MatchDtoCopyWith(_MatchDto value, $Res Function(_MatchDto) _then) = __$MatchDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String competitionId, TeamDto homeTeam, TeamDto awayTeam, DateTime kickoffAt, MatchStatus status, int? minute, int? minuteExtra, int homeScore, int awayScore, int? homePenalties, int? awayPenalties, String? stage, String? venue
});


@override $TeamDtoCopyWith<$Res> get homeTeam;@override $TeamDtoCopyWith<$Res> get awayTeam;

}
/// @nodoc
class __$MatchDtoCopyWithImpl<$Res>
    implements _$MatchDtoCopyWith<$Res> {
  __$MatchDtoCopyWithImpl(this._self, this._then);

  final _MatchDto _self;
  final $Res Function(_MatchDto) _then;

/// Create a copy of MatchDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? competitionId = null,Object? homeTeam = null,Object? awayTeam = null,Object? kickoffAt = null,Object? status = null,Object? minute = freezed,Object? minuteExtra = freezed,Object? homeScore = null,Object? awayScore = null,Object? homePenalties = freezed,Object? awayPenalties = freezed,Object? stage = freezed,Object? venue = freezed,}) {
  return _then(_MatchDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,competitionId: null == competitionId ? _self.competitionId : competitionId // ignore: cast_nullable_to_non_nullable
as String,homeTeam: null == homeTeam ? _self.homeTeam : homeTeam // ignore: cast_nullable_to_non_nullable
as TeamDto,awayTeam: null == awayTeam ? _self.awayTeam : awayTeam // ignore: cast_nullable_to_non_nullable
as TeamDto,kickoffAt: null == kickoffAt ? _self.kickoffAt : kickoffAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MatchStatus,minute: freezed == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int?,minuteExtra: freezed == minuteExtra ? _self.minuteExtra : minuteExtra // ignore: cast_nullable_to_non_nullable
as int?,homeScore: null == homeScore ? _self.homeScore : homeScore // ignore: cast_nullable_to_non_nullable
as int,awayScore: null == awayScore ? _self.awayScore : awayScore // ignore: cast_nullable_to_non_nullable
as int,homePenalties: freezed == homePenalties ? _self.homePenalties : homePenalties // ignore: cast_nullable_to_non_nullable
as int?,awayPenalties: freezed == awayPenalties ? _self.awayPenalties : awayPenalties // ignore: cast_nullable_to_non_nullable
as int?,stage: freezed == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as String?,venue: freezed == venue ? _self.venue : venue // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of MatchDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamDtoCopyWith<$Res> get homeTeam {
  
  return $TeamDtoCopyWith<$Res>(_self.homeTeam, (value) {
    return _then(_self.copyWith(homeTeam: value));
  });
}/// Create a copy of MatchDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamDtoCopyWith<$Res> get awayTeam {
  
  return $TeamDtoCopyWith<$Res>(_self.awayTeam, (value) {
    return _then(_self.copyWith(awayTeam: value));
  });
}
}


/// @nodoc
mixin _$MatchUpdate {

 String get id; MatchStatus get status; int? get minute; int? get minuteExtra; int get homeScore; int get awayScore; int? get homePenalties; int? get awayPenalties; DateTime get updatedAt;
/// Create a copy of MatchUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MatchUpdateCopyWith<MatchUpdate> get copyWith => _$MatchUpdateCopyWithImpl<MatchUpdate>(this as MatchUpdate, _$identity);

  /// Serializes this MatchUpdate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MatchUpdate&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.minute, minute) || other.minute == minute)&&(identical(other.minuteExtra, minuteExtra) || other.minuteExtra == minuteExtra)&&(identical(other.homeScore, homeScore) || other.homeScore == homeScore)&&(identical(other.awayScore, awayScore) || other.awayScore == awayScore)&&(identical(other.homePenalties, homePenalties) || other.homePenalties == homePenalties)&&(identical(other.awayPenalties, awayPenalties) || other.awayPenalties == awayPenalties)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,status,minute,minuteExtra,homeScore,awayScore,homePenalties,awayPenalties,updatedAt);

@override
String toString() {
  return 'MatchUpdate(id: $id, status: $status, minute: $minute, minuteExtra: $minuteExtra, homeScore: $homeScore, awayScore: $awayScore, homePenalties: $homePenalties, awayPenalties: $awayPenalties, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $MatchUpdateCopyWith<$Res>  {
  factory $MatchUpdateCopyWith(MatchUpdate value, $Res Function(MatchUpdate) _then) = _$MatchUpdateCopyWithImpl;
@useResult
$Res call({
 String id, MatchStatus status, int? minute, int? minuteExtra, int homeScore, int awayScore, int? homePenalties, int? awayPenalties, DateTime updatedAt
});




}
/// @nodoc
class _$MatchUpdateCopyWithImpl<$Res>
    implements $MatchUpdateCopyWith<$Res> {
  _$MatchUpdateCopyWithImpl(this._self, this._then);

  final MatchUpdate _self;
  final $Res Function(MatchUpdate) _then;

/// Create a copy of MatchUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? status = null,Object? minute = freezed,Object? minuteExtra = freezed,Object? homeScore = null,Object? awayScore = null,Object? homePenalties = freezed,Object? awayPenalties = freezed,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MatchStatus,minute: freezed == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int?,minuteExtra: freezed == minuteExtra ? _self.minuteExtra : minuteExtra // ignore: cast_nullable_to_non_nullable
as int?,homeScore: null == homeScore ? _self.homeScore : homeScore // ignore: cast_nullable_to_non_nullable
as int,awayScore: null == awayScore ? _self.awayScore : awayScore // ignore: cast_nullable_to_non_nullable
as int,homePenalties: freezed == homePenalties ? _self.homePenalties : homePenalties // ignore: cast_nullable_to_non_nullable
as int?,awayPenalties: freezed == awayPenalties ? _self.awayPenalties : awayPenalties // ignore: cast_nullable_to_non_nullable
as int?,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [MatchUpdate].
extension MatchUpdatePatterns on MatchUpdate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MatchUpdate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MatchUpdate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MatchUpdate value)  $default,){
final _that = this;
switch (_that) {
case _MatchUpdate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MatchUpdate value)?  $default,){
final _that = this;
switch (_that) {
case _MatchUpdate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  MatchStatus status,  int? minute,  int? minuteExtra,  int homeScore,  int awayScore,  int? homePenalties,  int? awayPenalties,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MatchUpdate() when $default != null:
return $default(_that.id,_that.status,_that.minute,_that.minuteExtra,_that.homeScore,_that.awayScore,_that.homePenalties,_that.awayPenalties,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  MatchStatus status,  int? minute,  int? minuteExtra,  int homeScore,  int awayScore,  int? homePenalties,  int? awayPenalties,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _MatchUpdate():
return $default(_that.id,_that.status,_that.minute,_that.minuteExtra,_that.homeScore,_that.awayScore,_that.homePenalties,_that.awayPenalties,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  MatchStatus status,  int? minute,  int? minuteExtra,  int homeScore,  int awayScore,  int? homePenalties,  int? awayPenalties,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _MatchUpdate() when $default != null:
return $default(_that.id,_that.status,_that.minute,_that.minuteExtra,_that.homeScore,_that.awayScore,_that.homePenalties,_that.awayPenalties,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MatchUpdate implements MatchUpdate {
  const _MatchUpdate({required this.id, required this.status, this.minute, this.minuteExtra, required this.homeScore, required this.awayScore, this.homePenalties, this.awayPenalties, required this.updatedAt});
  factory _MatchUpdate.fromJson(Map<String, dynamic> json) => _$MatchUpdateFromJson(json);

@override final  String id;
@override final  MatchStatus status;
@override final  int? minute;
@override final  int? minuteExtra;
@override final  int homeScore;
@override final  int awayScore;
@override final  int? homePenalties;
@override final  int? awayPenalties;
@override final  DateTime updatedAt;

/// Create a copy of MatchUpdate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MatchUpdateCopyWith<_MatchUpdate> get copyWith => __$MatchUpdateCopyWithImpl<_MatchUpdate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MatchUpdateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MatchUpdate&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.minute, minute) || other.minute == minute)&&(identical(other.minuteExtra, minuteExtra) || other.minuteExtra == minuteExtra)&&(identical(other.homeScore, homeScore) || other.homeScore == homeScore)&&(identical(other.awayScore, awayScore) || other.awayScore == awayScore)&&(identical(other.homePenalties, homePenalties) || other.homePenalties == homePenalties)&&(identical(other.awayPenalties, awayPenalties) || other.awayPenalties == awayPenalties)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,status,minute,minuteExtra,homeScore,awayScore,homePenalties,awayPenalties,updatedAt);

@override
String toString() {
  return 'MatchUpdate(id: $id, status: $status, minute: $minute, minuteExtra: $minuteExtra, homeScore: $homeScore, awayScore: $awayScore, homePenalties: $homePenalties, awayPenalties: $awayPenalties, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$MatchUpdateCopyWith<$Res> implements $MatchUpdateCopyWith<$Res> {
  factory _$MatchUpdateCopyWith(_MatchUpdate value, $Res Function(_MatchUpdate) _then) = __$MatchUpdateCopyWithImpl;
@override @useResult
$Res call({
 String id, MatchStatus status, int? minute, int? minuteExtra, int homeScore, int awayScore, int? homePenalties, int? awayPenalties, DateTime updatedAt
});




}
/// @nodoc
class __$MatchUpdateCopyWithImpl<$Res>
    implements _$MatchUpdateCopyWith<$Res> {
  __$MatchUpdateCopyWithImpl(this._self, this._then);

  final _MatchUpdate _self;
  final $Res Function(_MatchUpdate) _then;

/// Create a copy of MatchUpdate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? status = null,Object? minute = freezed,Object? minuteExtra = freezed,Object? homeScore = null,Object? awayScore = null,Object? homePenalties = freezed,Object? awayPenalties = freezed,Object? updatedAt = null,}) {
  return _then(_MatchUpdate(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MatchStatus,minute: freezed == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int?,minuteExtra: freezed == minuteExtra ? _self.minuteExtra : minuteExtra // ignore: cast_nullable_to_non_nullable
as int?,homeScore: null == homeScore ? _self.homeScore : homeScore // ignore: cast_nullable_to_non_nullable
as int,awayScore: null == awayScore ? _self.awayScore : awayScore // ignore: cast_nullable_to_non_nullable
as int,homePenalties: freezed == homePenalties ? _self.homePenalties : homePenalties // ignore: cast_nullable_to_non_nullable
as int?,awayPenalties: freezed == awayPenalties ? _self.awayPenalties : awayPenalties // ignore: cast_nullable_to_non_nullable
as int?,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
