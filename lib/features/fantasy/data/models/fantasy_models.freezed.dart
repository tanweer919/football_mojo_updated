// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fantasy_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FantasyTournamentDto {

 String get id; String get slug; String get name; FantasyFormat get format; double get budget; String? get description; String? get emblemUrl; DateTime get startsAt; DateTime get endsAt; List<FantasyGameweekDto> get gameweeks;
/// Create a copy of FantasyTournamentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FantasyTournamentDtoCopyWith<FantasyTournamentDto> get copyWith => _$FantasyTournamentDtoCopyWithImpl<FantasyTournamentDto>(this as FantasyTournamentDto, _$identity);

  /// Serializes this FantasyTournamentDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FantasyTournamentDto&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.format, format) || other.format == format)&&(identical(other.budget, budget) || other.budget == budget)&&(identical(other.description, description) || other.description == description)&&(identical(other.emblemUrl, emblemUrl) || other.emblemUrl == emblemUrl)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&const DeepCollectionEquality().equals(other.gameweeks, gameweeks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,slug,name,format,budget,description,emblemUrl,startsAt,endsAt,const DeepCollectionEquality().hash(gameweeks));

@override
String toString() {
  return 'FantasyTournamentDto(id: $id, slug: $slug, name: $name, format: $format, budget: $budget, description: $description, emblemUrl: $emblemUrl, startsAt: $startsAt, endsAt: $endsAt, gameweeks: $gameweeks)';
}


}

/// @nodoc
abstract mixin class $FantasyTournamentDtoCopyWith<$Res>  {
  factory $FantasyTournamentDtoCopyWith(FantasyTournamentDto value, $Res Function(FantasyTournamentDto) _then) = _$FantasyTournamentDtoCopyWithImpl;
@useResult
$Res call({
 String id, String slug, String name, FantasyFormat format, double budget, String? description, String? emblemUrl, DateTime startsAt, DateTime endsAt, List<FantasyGameweekDto> gameweeks
});




}
/// @nodoc
class _$FantasyTournamentDtoCopyWithImpl<$Res>
    implements $FantasyTournamentDtoCopyWith<$Res> {
  _$FantasyTournamentDtoCopyWithImpl(this._self, this._then);

  final FantasyTournamentDto _self;
  final $Res Function(FantasyTournamentDto) _then;

/// Create a copy of FantasyTournamentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? slug = null,Object? name = null,Object? format = null,Object? budget = null,Object? description = freezed,Object? emblemUrl = freezed,Object? startsAt = null,Object? endsAt = null,Object? gameweeks = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as FantasyFormat,budget: null == budget ? _self.budget : budget // ignore: cast_nullable_to_non_nullable
as double,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,emblemUrl: freezed == emblemUrl ? _self.emblemUrl : emblemUrl // ignore: cast_nullable_to_non_nullable
as String?,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,gameweeks: null == gameweeks ? _self.gameweeks : gameweeks // ignore: cast_nullable_to_non_nullable
as List<FantasyGameweekDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [FantasyTournamentDto].
extension FantasyTournamentDtoPatterns on FantasyTournamentDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FantasyTournamentDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FantasyTournamentDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FantasyTournamentDto value)  $default,){
final _that = this;
switch (_that) {
case _FantasyTournamentDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FantasyTournamentDto value)?  $default,){
final _that = this;
switch (_that) {
case _FantasyTournamentDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String slug,  String name,  FantasyFormat format,  double budget,  String? description,  String? emblemUrl,  DateTime startsAt,  DateTime endsAt,  List<FantasyGameweekDto> gameweeks)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FantasyTournamentDto() when $default != null:
return $default(_that.id,_that.slug,_that.name,_that.format,_that.budget,_that.description,_that.emblemUrl,_that.startsAt,_that.endsAt,_that.gameweeks);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String slug,  String name,  FantasyFormat format,  double budget,  String? description,  String? emblemUrl,  DateTime startsAt,  DateTime endsAt,  List<FantasyGameweekDto> gameweeks)  $default,) {final _that = this;
switch (_that) {
case _FantasyTournamentDto():
return $default(_that.id,_that.slug,_that.name,_that.format,_that.budget,_that.description,_that.emblemUrl,_that.startsAt,_that.endsAt,_that.gameweeks);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String slug,  String name,  FantasyFormat format,  double budget,  String? description,  String? emblemUrl,  DateTime startsAt,  DateTime endsAt,  List<FantasyGameweekDto> gameweeks)?  $default,) {final _that = this;
switch (_that) {
case _FantasyTournamentDto() when $default != null:
return $default(_that.id,_that.slug,_that.name,_that.format,_that.budget,_that.description,_that.emblemUrl,_that.startsAt,_that.endsAt,_that.gameweeks);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FantasyTournamentDto implements FantasyTournamentDto {
  const _FantasyTournamentDto({required this.id, required this.slug, required this.name, required this.format, required this.budget, this.description, this.emblemUrl, required this.startsAt, required this.endsAt, final  List<FantasyGameweekDto> gameweeks = const <FantasyGameweekDto>[]}): _gameweeks = gameweeks;
  factory _FantasyTournamentDto.fromJson(Map<String, dynamic> json) => _$FantasyTournamentDtoFromJson(json);

@override final  String id;
@override final  String slug;
@override final  String name;
@override final  FantasyFormat format;
@override final  double budget;
@override final  String? description;
@override final  String? emblemUrl;
@override final  DateTime startsAt;
@override final  DateTime endsAt;
 final  List<FantasyGameweekDto> _gameweeks;
@override@JsonKey() List<FantasyGameweekDto> get gameweeks {
  if (_gameweeks is EqualUnmodifiableListView) return _gameweeks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_gameweeks);
}


/// Create a copy of FantasyTournamentDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FantasyTournamentDtoCopyWith<_FantasyTournamentDto> get copyWith => __$FantasyTournamentDtoCopyWithImpl<_FantasyTournamentDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FantasyTournamentDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FantasyTournamentDto&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.format, format) || other.format == format)&&(identical(other.budget, budget) || other.budget == budget)&&(identical(other.description, description) || other.description == description)&&(identical(other.emblemUrl, emblemUrl) || other.emblemUrl == emblemUrl)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&const DeepCollectionEquality().equals(other._gameweeks, _gameweeks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,slug,name,format,budget,description,emblemUrl,startsAt,endsAt,const DeepCollectionEquality().hash(_gameweeks));

@override
String toString() {
  return 'FantasyTournamentDto(id: $id, slug: $slug, name: $name, format: $format, budget: $budget, description: $description, emblemUrl: $emblemUrl, startsAt: $startsAt, endsAt: $endsAt, gameweeks: $gameweeks)';
}


}

/// @nodoc
abstract mixin class _$FantasyTournamentDtoCopyWith<$Res> implements $FantasyTournamentDtoCopyWith<$Res> {
  factory _$FantasyTournamentDtoCopyWith(_FantasyTournamentDto value, $Res Function(_FantasyTournamentDto) _then) = __$FantasyTournamentDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String slug, String name, FantasyFormat format, double budget, String? description, String? emblemUrl, DateTime startsAt, DateTime endsAt, List<FantasyGameweekDto> gameweeks
});




}
/// @nodoc
class __$FantasyTournamentDtoCopyWithImpl<$Res>
    implements _$FantasyTournamentDtoCopyWith<$Res> {
  __$FantasyTournamentDtoCopyWithImpl(this._self, this._then);

  final _FantasyTournamentDto _self;
  final $Res Function(_FantasyTournamentDto) _then;

/// Create a copy of FantasyTournamentDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? slug = null,Object? name = null,Object? format = null,Object? budget = null,Object? description = freezed,Object? emblemUrl = freezed,Object? startsAt = null,Object? endsAt = null,Object? gameweeks = null,}) {
  return _then(_FantasyTournamentDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as FantasyFormat,budget: null == budget ? _self.budget : budget // ignore: cast_nullable_to_non_nullable
as double,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,emblemUrl: freezed == emblemUrl ? _self.emblemUrl : emblemUrl // ignore: cast_nullable_to_non_nullable
as String?,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,gameweeks: null == gameweeks ? _self._gameweeks : gameweeks // ignore: cast_nullable_to_non_nullable
as List<FantasyGameweekDto>,
  ));
}


}


/// @nodoc
mixin _$FantasyGameweekDto {

 String get id; int get number; String get name; DateTime get lockAt; DateTime get endsAt; bool get scored;
/// Create a copy of FantasyGameweekDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FantasyGameweekDtoCopyWith<FantasyGameweekDto> get copyWith => _$FantasyGameweekDtoCopyWithImpl<FantasyGameweekDto>(this as FantasyGameweekDto, _$identity);

  /// Serializes this FantasyGameweekDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FantasyGameweekDto&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.name, name) || other.name == name)&&(identical(other.lockAt, lockAt) || other.lockAt == lockAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.scored, scored) || other.scored == scored));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,number,name,lockAt,endsAt,scored);

@override
String toString() {
  return 'FantasyGameweekDto(id: $id, number: $number, name: $name, lockAt: $lockAt, endsAt: $endsAt, scored: $scored)';
}


}

/// @nodoc
abstract mixin class $FantasyGameweekDtoCopyWith<$Res>  {
  factory $FantasyGameweekDtoCopyWith(FantasyGameweekDto value, $Res Function(FantasyGameweekDto) _then) = _$FantasyGameweekDtoCopyWithImpl;
@useResult
$Res call({
 String id, int number, String name, DateTime lockAt, DateTime endsAt, bool scored
});




}
/// @nodoc
class _$FantasyGameweekDtoCopyWithImpl<$Res>
    implements $FantasyGameweekDtoCopyWith<$Res> {
  _$FantasyGameweekDtoCopyWithImpl(this._self, this._then);

  final FantasyGameweekDto _self;
  final $Res Function(FantasyGameweekDto) _then;

/// Create a copy of FantasyGameweekDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? name = null,Object? lockAt = null,Object? endsAt = null,Object? scored = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,lockAt: null == lockAt ? _self.lockAt : lockAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,scored: null == scored ? _self.scored : scored // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [FantasyGameweekDto].
extension FantasyGameweekDtoPatterns on FantasyGameweekDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FantasyGameweekDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FantasyGameweekDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FantasyGameweekDto value)  $default,){
final _that = this;
switch (_that) {
case _FantasyGameweekDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FantasyGameweekDto value)?  $default,){
final _that = this;
switch (_that) {
case _FantasyGameweekDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int number,  String name,  DateTime lockAt,  DateTime endsAt,  bool scored)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FantasyGameweekDto() when $default != null:
return $default(_that.id,_that.number,_that.name,_that.lockAt,_that.endsAt,_that.scored);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int number,  String name,  DateTime lockAt,  DateTime endsAt,  bool scored)  $default,) {final _that = this;
switch (_that) {
case _FantasyGameweekDto():
return $default(_that.id,_that.number,_that.name,_that.lockAt,_that.endsAt,_that.scored);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int number,  String name,  DateTime lockAt,  DateTime endsAt,  bool scored)?  $default,) {final _that = this;
switch (_that) {
case _FantasyGameweekDto() when $default != null:
return $default(_that.id,_that.number,_that.name,_that.lockAt,_that.endsAt,_that.scored);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FantasyGameweekDto extends FantasyGameweekDto {
  const _FantasyGameweekDto({required this.id, required this.number, required this.name, required this.lockAt, required this.endsAt, this.scored = false}): super._();
  factory _FantasyGameweekDto.fromJson(Map<String, dynamic> json) => _$FantasyGameweekDtoFromJson(json);

@override final  String id;
@override final  int number;
@override final  String name;
@override final  DateTime lockAt;
@override final  DateTime endsAt;
@override@JsonKey() final  bool scored;

/// Create a copy of FantasyGameweekDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FantasyGameweekDtoCopyWith<_FantasyGameweekDto> get copyWith => __$FantasyGameweekDtoCopyWithImpl<_FantasyGameweekDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FantasyGameweekDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FantasyGameweekDto&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.name, name) || other.name == name)&&(identical(other.lockAt, lockAt) || other.lockAt == lockAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.scored, scored) || other.scored == scored));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,number,name,lockAt,endsAt,scored);

@override
String toString() {
  return 'FantasyGameweekDto(id: $id, number: $number, name: $name, lockAt: $lockAt, endsAt: $endsAt, scored: $scored)';
}


}

/// @nodoc
abstract mixin class _$FantasyGameweekDtoCopyWith<$Res> implements $FantasyGameweekDtoCopyWith<$Res> {
  factory _$FantasyGameweekDtoCopyWith(_FantasyGameweekDto value, $Res Function(_FantasyGameweekDto) _then) = __$FantasyGameweekDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, int number, String name, DateTime lockAt, DateTime endsAt, bool scored
});




}
/// @nodoc
class __$FantasyGameweekDtoCopyWithImpl<$Res>
    implements _$FantasyGameweekDtoCopyWith<$Res> {
  __$FantasyGameweekDtoCopyWithImpl(this._self, this._then);

  final _FantasyGameweekDto _self;
  final $Res Function(_FantasyGameweekDto) _then;

/// Create a copy of FantasyGameweekDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? name = null,Object? lockAt = null,Object? endsAt = null,Object? scored = null,}) {
  return _then(_FantasyGameweekDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,lockAt: null == lockAt ? _self.lockAt : lockAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,scored: null == scored ? _self.scored : scored // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$PlayerValuationDto {

 String get id; String get playerId; double get price; double get recentForm; PlayerPosition get position; PlayerSummary get player;
/// Create a copy of PlayerValuationDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerValuationDtoCopyWith<PlayerValuationDto> get copyWith => _$PlayerValuationDtoCopyWithImpl<PlayerValuationDto>(this as PlayerValuationDto, _$identity);

  /// Serializes this PlayerValuationDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerValuationDto&&(identical(other.id, id) || other.id == id)&&(identical(other.playerId, playerId) || other.playerId == playerId)&&(identical(other.price, price) || other.price == price)&&(identical(other.recentForm, recentForm) || other.recentForm == recentForm)&&(identical(other.position, position) || other.position == position)&&(identical(other.player, player) || other.player == player));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,playerId,price,recentForm,position,player);

@override
String toString() {
  return 'PlayerValuationDto(id: $id, playerId: $playerId, price: $price, recentForm: $recentForm, position: $position, player: $player)';
}


}

/// @nodoc
abstract mixin class $PlayerValuationDtoCopyWith<$Res>  {
  factory $PlayerValuationDtoCopyWith(PlayerValuationDto value, $Res Function(PlayerValuationDto) _then) = _$PlayerValuationDtoCopyWithImpl;
@useResult
$Res call({
 String id, String playerId, double price, double recentForm, PlayerPosition position, PlayerSummary player
});


$PlayerSummaryCopyWith<$Res> get player;

}
/// @nodoc
class _$PlayerValuationDtoCopyWithImpl<$Res>
    implements $PlayerValuationDtoCopyWith<$Res> {
  _$PlayerValuationDtoCopyWithImpl(this._self, this._then);

  final PlayerValuationDto _self;
  final $Res Function(PlayerValuationDto) _then;

/// Create a copy of PlayerValuationDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? playerId = null,Object? price = null,Object? recentForm = null,Object? position = null,Object? player = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,playerId: null == playerId ? _self.playerId : playerId // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,recentForm: null == recentForm ? _self.recentForm : recentForm // ignore: cast_nullable_to_non_nullable
as double,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as PlayerPosition,player: null == player ? _self.player : player // ignore: cast_nullable_to_non_nullable
as PlayerSummary,
  ));
}
/// Create a copy of PlayerValuationDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlayerSummaryCopyWith<$Res> get player {
  
  return $PlayerSummaryCopyWith<$Res>(_self.player, (value) {
    return _then(_self.copyWith(player: value));
  });
}
}


/// Adds pattern-matching-related methods to [PlayerValuationDto].
extension PlayerValuationDtoPatterns on PlayerValuationDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlayerValuationDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlayerValuationDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlayerValuationDto value)  $default,){
final _that = this;
switch (_that) {
case _PlayerValuationDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlayerValuationDto value)?  $default,){
final _that = this;
switch (_that) {
case _PlayerValuationDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String playerId,  double price,  double recentForm,  PlayerPosition position,  PlayerSummary player)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlayerValuationDto() when $default != null:
return $default(_that.id,_that.playerId,_that.price,_that.recentForm,_that.position,_that.player);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String playerId,  double price,  double recentForm,  PlayerPosition position,  PlayerSummary player)  $default,) {final _that = this;
switch (_that) {
case _PlayerValuationDto():
return $default(_that.id,_that.playerId,_that.price,_that.recentForm,_that.position,_that.player);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String playerId,  double price,  double recentForm,  PlayerPosition position,  PlayerSummary player)?  $default,) {final _that = this;
switch (_that) {
case _PlayerValuationDto() when $default != null:
return $default(_that.id,_that.playerId,_that.price,_that.recentForm,_that.position,_that.player);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlayerValuationDto implements PlayerValuationDto {
  const _PlayerValuationDto({required this.id, required this.playerId, required this.price, required this.recentForm, required this.position, required this.player});
  factory _PlayerValuationDto.fromJson(Map<String, dynamic> json) => _$PlayerValuationDtoFromJson(json);

@override final  String id;
@override final  String playerId;
@override final  double price;
@override final  double recentForm;
@override final  PlayerPosition position;
@override final  PlayerSummary player;

/// Create a copy of PlayerValuationDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlayerValuationDtoCopyWith<_PlayerValuationDto> get copyWith => __$PlayerValuationDtoCopyWithImpl<_PlayerValuationDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlayerValuationDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlayerValuationDto&&(identical(other.id, id) || other.id == id)&&(identical(other.playerId, playerId) || other.playerId == playerId)&&(identical(other.price, price) || other.price == price)&&(identical(other.recentForm, recentForm) || other.recentForm == recentForm)&&(identical(other.position, position) || other.position == position)&&(identical(other.player, player) || other.player == player));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,playerId,price,recentForm,position,player);

@override
String toString() {
  return 'PlayerValuationDto(id: $id, playerId: $playerId, price: $price, recentForm: $recentForm, position: $position, player: $player)';
}


}

/// @nodoc
abstract mixin class _$PlayerValuationDtoCopyWith<$Res> implements $PlayerValuationDtoCopyWith<$Res> {
  factory _$PlayerValuationDtoCopyWith(_PlayerValuationDto value, $Res Function(_PlayerValuationDto) _then) = __$PlayerValuationDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String playerId, double price, double recentForm, PlayerPosition position, PlayerSummary player
});


@override $PlayerSummaryCopyWith<$Res> get player;

}
/// @nodoc
class __$PlayerValuationDtoCopyWithImpl<$Res>
    implements _$PlayerValuationDtoCopyWith<$Res> {
  __$PlayerValuationDtoCopyWithImpl(this._self, this._then);

  final _PlayerValuationDto _self;
  final $Res Function(_PlayerValuationDto) _then;

/// Create a copy of PlayerValuationDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? playerId = null,Object? price = null,Object? recentForm = null,Object? position = null,Object? player = null,}) {
  return _then(_PlayerValuationDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,playerId: null == playerId ? _self.playerId : playerId // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,recentForm: null == recentForm ? _self.recentForm : recentForm // ignore: cast_nullable_to_non_nullable
as double,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as PlayerPosition,player: null == player ? _self.player : player // ignore: cast_nullable_to_non_nullable
as PlayerSummary,
  ));
}

/// Create a copy of PlayerValuationDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlayerSummaryCopyWith<$Res> get player {
  
  return $PlayerSummaryCopyWith<$Res>(_self.player, (value) {
    return _then(_self.copyWith(player: value));
  });
}
}


/// @nodoc
mixin _$PlayerSummary {

 String get id; String get name; int? get shirtNumber; String? get photoUrl; String? get position; TeamSummary get team;
/// Create a copy of PlayerSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerSummaryCopyWith<PlayerSummary> get copyWith => _$PlayerSummaryCopyWithImpl<PlayerSummary>(this as PlayerSummary, _$identity);

  /// Serializes this PlayerSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.shirtNumber, shirtNumber) || other.shirtNumber == shirtNumber)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.position, position) || other.position == position)&&(identical(other.team, team) || other.team == team));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,shirtNumber,photoUrl,position,team);

@override
String toString() {
  return 'PlayerSummary(id: $id, name: $name, shirtNumber: $shirtNumber, photoUrl: $photoUrl, position: $position, team: $team)';
}


}

/// @nodoc
abstract mixin class $PlayerSummaryCopyWith<$Res>  {
  factory $PlayerSummaryCopyWith(PlayerSummary value, $Res Function(PlayerSummary) _then) = _$PlayerSummaryCopyWithImpl;
@useResult
$Res call({
 String id, String name, int? shirtNumber, String? photoUrl, String? position, TeamSummary team
});


$TeamSummaryCopyWith<$Res> get team;

}
/// @nodoc
class _$PlayerSummaryCopyWithImpl<$Res>
    implements $PlayerSummaryCopyWith<$Res> {
  _$PlayerSummaryCopyWithImpl(this._self, this._then);

  final PlayerSummary _self;
  final $Res Function(PlayerSummary) _then;

/// Create a copy of PlayerSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? shirtNumber = freezed,Object? photoUrl = freezed,Object? position = freezed,Object? team = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,shirtNumber: freezed == shirtNumber ? _self.shirtNumber : shirtNumber // ignore: cast_nullable_to_non_nullable
as int?,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as String?,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamSummary,
  ));
}
/// Create a copy of PlayerSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamSummaryCopyWith<$Res> get team {
  
  return $TeamSummaryCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}
}


/// Adds pattern-matching-related methods to [PlayerSummary].
extension PlayerSummaryPatterns on PlayerSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlayerSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlayerSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlayerSummary value)  $default,){
final _that = this;
switch (_that) {
case _PlayerSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlayerSummary value)?  $default,){
final _that = this;
switch (_that) {
case _PlayerSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  int? shirtNumber,  String? photoUrl,  String? position,  TeamSummary team)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlayerSummary() when $default != null:
return $default(_that.id,_that.name,_that.shirtNumber,_that.photoUrl,_that.position,_that.team);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  int? shirtNumber,  String? photoUrl,  String? position,  TeamSummary team)  $default,) {final _that = this;
switch (_that) {
case _PlayerSummary():
return $default(_that.id,_that.name,_that.shirtNumber,_that.photoUrl,_that.position,_that.team);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  int? shirtNumber,  String? photoUrl,  String? position,  TeamSummary team)?  $default,) {final _that = this;
switch (_that) {
case _PlayerSummary() when $default != null:
return $default(_that.id,_that.name,_that.shirtNumber,_that.photoUrl,_that.position,_that.team);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlayerSummary implements PlayerSummary {
  const _PlayerSummary({required this.id, required this.name, this.shirtNumber, this.photoUrl, this.position, required this.team});
  factory _PlayerSummary.fromJson(Map<String, dynamic> json) => _$PlayerSummaryFromJson(json);

@override final  String id;
@override final  String name;
@override final  int? shirtNumber;
@override final  String? photoUrl;
@override final  String? position;
@override final  TeamSummary team;

/// Create a copy of PlayerSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlayerSummaryCopyWith<_PlayerSummary> get copyWith => __$PlayerSummaryCopyWithImpl<_PlayerSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlayerSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlayerSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.shirtNumber, shirtNumber) || other.shirtNumber == shirtNumber)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.position, position) || other.position == position)&&(identical(other.team, team) || other.team == team));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,shirtNumber,photoUrl,position,team);

@override
String toString() {
  return 'PlayerSummary(id: $id, name: $name, shirtNumber: $shirtNumber, photoUrl: $photoUrl, position: $position, team: $team)';
}


}

/// @nodoc
abstract mixin class _$PlayerSummaryCopyWith<$Res> implements $PlayerSummaryCopyWith<$Res> {
  factory _$PlayerSummaryCopyWith(_PlayerSummary value, $Res Function(_PlayerSummary) _then) = __$PlayerSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, int? shirtNumber, String? photoUrl, String? position, TeamSummary team
});


@override $TeamSummaryCopyWith<$Res> get team;

}
/// @nodoc
class __$PlayerSummaryCopyWithImpl<$Res>
    implements _$PlayerSummaryCopyWith<$Res> {
  __$PlayerSummaryCopyWithImpl(this._self, this._then);

  final _PlayerSummary _self;
  final $Res Function(_PlayerSummary) _then;

/// Create a copy of PlayerSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? shirtNumber = freezed,Object? photoUrl = freezed,Object? position = freezed,Object? team = null,}) {
  return _then(_PlayerSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,shirtNumber: freezed == shirtNumber ? _self.shirtNumber : shirtNumber // ignore: cast_nullable_to_non_nullable
as int?,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as String?,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamSummary,
  ));
}

/// Create a copy of PlayerSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamSummaryCopyWith<$Res> get team {
  
  return $TeamSummaryCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}
}


/// @nodoc
mixin _$TeamSummary {

 String get id; String get name; String? get shortName; String? get crestUrl;
/// Create a copy of TeamSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TeamSummaryCopyWith<TeamSummary> get copyWith => _$TeamSummaryCopyWithImpl<TeamSummary>(this as TeamSummary, _$identity);

  /// Serializes this TeamSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TeamSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.shortName, shortName) || other.shortName == shortName)&&(identical(other.crestUrl, crestUrl) || other.crestUrl == crestUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,shortName,crestUrl);

@override
String toString() {
  return 'TeamSummary(id: $id, name: $name, shortName: $shortName, crestUrl: $crestUrl)';
}


}

/// @nodoc
abstract mixin class $TeamSummaryCopyWith<$Res>  {
  factory $TeamSummaryCopyWith(TeamSummary value, $Res Function(TeamSummary) _then) = _$TeamSummaryCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? shortName, String? crestUrl
});




}
/// @nodoc
class _$TeamSummaryCopyWithImpl<$Res>
    implements $TeamSummaryCopyWith<$Res> {
  _$TeamSummaryCopyWithImpl(this._self, this._then);

  final TeamSummary _self;
  final $Res Function(TeamSummary) _then;

/// Create a copy of TeamSummary
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


/// Adds pattern-matching-related methods to [TeamSummary].
extension TeamSummaryPatterns on TeamSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TeamSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TeamSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TeamSummary value)  $default,){
final _that = this;
switch (_that) {
case _TeamSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TeamSummary value)?  $default,){
final _that = this;
switch (_that) {
case _TeamSummary() when $default != null:
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
case _TeamSummary() when $default != null:
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
case _TeamSummary():
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
case _TeamSummary() when $default != null:
return $default(_that.id,_that.name,_that.shortName,_that.crestUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TeamSummary implements TeamSummary {
  const _TeamSummary({required this.id, required this.name, this.shortName, this.crestUrl});
  factory _TeamSummary.fromJson(Map<String, dynamic> json) => _$TeamSummaryFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? shortName;
@override final  String? crestUrl;

/// Create a copy of TeamSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TeamSummaryCopyWith<_TeamSummary> get copyWith => __$TeamSummaryCopyWithImpl<_TeamSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TeamSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TeamSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.shortName, shortName) || other.shortName == shortName)&&(identical(other.crestUrl, crestUrl) || other.crestUrl == crestUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,shortName,crestUrl);

@override
String toString() {
  return 'TeamSummary(id: $id, name: $name, shortName: $shortName, crestUrl: $crestUrl)';
}


}

/// @nodoc
abstract mixin class _$TeamSummaryCopyWith<$Res> implements $TeamSummaryCopyWith<$Res> {
  factory _$TeamSummaryCopyWith(_TeamSummary value, $Res Function(_TeamSummary) _then) = __$TeamSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? shortName, String? crestUrl
});




}
/// @nodoc
class __$TeamSummaryCopyWithImpl<$Res>
    implements _$TeamSummaryCopyWith<$Res> {
  __$TeamSummaryCopyWithImpl(this._self, this._then);

  final _TeamSummary _self;
  final $Res Function(_TeamSummary) _then;

/// Create a copy of TeamSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? shortName = freezed,Object? crestUrl = freezed,}) {
  return _then(_TeamSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,shortName: freezed == shortName ? _self.shortName : shortName // ignore: cast_nullable_to_non_nullable
as String?,crestUrl: freezed == crestUrl ? _self.crestUrl : crestUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$LineupPick {

 String get playerId; PlayerPosition get position; bool get isCaptain;
/// Create a copy of LineupPick
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LineupPickCopyWith<LineupPick> get copyWith => _$LineupPickCopyWithImpl<LineupPick>(this as LineupPick, _$identity);

  /// Serializes this LineupPick to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LineupPick&&(identical(other.playerId, playerId) || other.playerId == playerId)&&(identical(other.position, position) || other.position == position)&&(identical(other.isCaptain, isCaptain) || other.isCaptain == isCaptain));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,playerId,position,isCaptain);

@override
String toString() {
  return 'LineupPick(playerId: $playerId, position: $position, isCaptain: $isCaptain)';
}


}

/// @nodoc
abstract mixin class $LineupPickCopyWith<$Res>  {
  factory $LineupPickCopyWith(LineupPick value, $Res Function(LineupPick) _then) = _$LineupPickCopyWithImpl;
@useResult
$Res call({
 String playerId, PlayerPosition position, bool isCaptain
});




}
/// @nodoc
class _$LineupPickCopyWithImpl<$Res>
    implements $LineupPickCopyWith<$Res> {
  _$LineupPickCopyWithImpl(this._self, this._then);

  final LineupPick _self;
  final $Res Function(LineupPick) _then;

/// Create a copy of LineupPick
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? playerId = null,Object? position = null,Object? isCaptain = null,}) {
  return _then(_self.copyWith(
playerId: null == playerId ? _self.playerId : playerId // ignore: cast_nullable_to_non_nullable
as String,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as PlayerPosition,isCaptain: null == isCaptain ? _self.isCaptain : isCaptain // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LineupPick].
extension LineupPickPatterns on LineupPick {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LineupPick value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LineupPick() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LineupPick value)  $default,){
final _that = this;
switch (_that) {
case _LineupPick():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LineupPick value)?  $default,){
final _that = this;
switch (_that) {
case _LineupPick() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String playerId,  PlayerPosition position,  bool isCaptain)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LineupPick() when $default != null:
return $default(_that.playerId,_that.position,_that.isCaptain);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String playerId,  PlayerPosition position,  bool isCaptain)  $default,) {final _that = this;
switch (_that) {
case _LineupPick():
return $default(_that.playerId,_that.position,_that.isCaptain);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String playerId,  PlayerPosition position,  bool isCaptain)?  $default,) {final _that = this;
switch (_that) {
case _LineupPick() when $default != null:
return $default(_that.playerId,_that.position,_that.isCaptain);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LineupPick implements LineupPick {
  const _LineupPick({required this.playerId, required this.position, this.isCaptain = false});
  factory _LineupPick.fromJson(Map<String, dynamic> json) => _$LineupPickFromJson(json);

@override final  String playerId;
@override final  PlayerPosition position;
@override@JsonKey() final  bool isCaptain;

/// Create a copy of LineupPick
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LineupPickCopyWith<_LineupPick> get copyWith => __$LineupPickCopyWithImpl<_LineupPick>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LineupPickToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LineupPick&&(identical(other.playerId, playerId) || other.playerId == playerId)&&(identical(other.position, position) || other.position == position)&&(identical(other.isCaptain, isCaptain) || other.isCaptain == isCaptain));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,playerId,position,isCaptain);

@override
String toString() {
  return 'LineupPick(playerId: $playerId, position: $position, isCaptain: $isCaptain)';
}


}

/// @nodoc
abstract mixin class _$LineupPickCopyWith<$Res> implements $LineupPickCopyWith<$Res> {
  factory _$LineupPickCopyWith(_LineupPick value, $Res Function(_LineupPick) _then) = __$LineupPickCopyWithImpl;
@override @useResult
$Res call({
 String playerId, PlayerPosition position, bool isCaptain
});




}
/// @nodoc
class __$LineupPickCopyWithImpl<$Res>
    implements _$LineupPickCopyWith<$Res> {
  __$LineupPickCopyWithImpl(this._self, this._then);

  final _LineupPick _self;
  final $Res Function(_LineupPick) _then;

/// Create a copy of LineupPick
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? playerId = null,Object? position = null,Object? isCaptain = null,}) {
  return _then(_LineupPick(
playerId: null == playerId ? _self.playerId : playerId // ignore: cast_nullable_to_non_nullable
as String,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as PlayerPosition,isCaptain: null == isCaptain ? _self.isCaptain : isCaptain // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$FantasyLineupDto {

 String get id; String get userId; String get gameweekId; List<LineupPick> get picks; String get captainId; double get budgetUsed; bool get locked; double get totalPoints; int? get rank;
/// Create a copy of FantasyLineupDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FantasyLineupDtoCopyWith<FantasyLineupDto> get copyWith => _$FantasyLineupDtoCopyWithImpl<FantasyLineupDto>(this as FantasyLineupDto, _$identity);

  /// Serializes this FantasyLineupDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FantasyLineupDto&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.gameweekId, gameweekId) || other.gameweekId == gameweekId)&&const DeepCollectionEquality().equals(other.picks, picks)&&(identical(other.captainId, captainId) || other.captainId == captainId)&&(identical(other.budgetUsed, budgetUsed) || other.budgetUsed == budgetUsed)&&(identical(other.locked, locked) || other.locked == locked)&&(identical(other.totalPoints, totalPoints) || other.totalPoints == totalPoints)&&(identical(other.rank, rank) || other.rank == rank));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,gameweekId,const DeepCollectionEquality().hash(picks),captainId,budgetUsed,locked,totalPoints,rank);

@override
String toString() {
  return 'FantasyLineupDto(id: $id, userId: $userId, gameweekId: $gameweekId, picks: $picks, captainId: $captainId, budgetUsed: $budgetUsed, locked: $locked, totalPoints: $totalPoints, rank: $rank)';
}


}

/// @nodoc
abstract mixin class $FantasyLineupDtoCopyWith<$Res>  {
  factory $FantasyLineupDtoCopyWith(FantasyLineupDto value, $Res Function(FantasyLineupDto) _then) = _$FantasyLineupDtoCopyWithImpl;
@useResult
$Res call({
 String id, String userId, String gameweekId, List<LineupPick> picks, String captainId, double budgetUsed, bool locked, double totalPoints, int? rank
});




}
/// @nodoc
class _$FantasyLineupDtoCopyWithImpl<$Res>
    implements $FantasyLineupDtoCopyWith<$Res> {
  _$FantasyLineupDtoCopyWithImpl(this._self, this._then);

  final FantasyLineupDto _self;
  final $Res Function(FantasyLineupDto) _then;

/// Create a copy of FantasyLineupDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? gameweekId = null,Object? picks = null,Object? captainId = null,Object? budgetUsed = null,Object? locked = null,Object? totalPoints = null,Object? rank = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,gameweekId: null == gameweekId ? _self.gameweekId : gameweekId // ignore: cast_nullable_to_non_nullable
as String,picks: null == picks ? _self.picks : picks // ignore: cast_nullable_to_non_nullable
as List<LineupPick>,captainId: null == captainId ? _self.captainId : captainId // ignore: cast_nullable_to_non_nullable
as String,budgetUsed: null == budgetUsed ? _self.budgetUsed : budgetUsed // ignore: cast_nullable_to_non_nullable
as double,locked: null == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as bool,totalPoints: null == totalPoints ? _self.totalPoints : totalPoints // ignore: cast_nullable_to_non_nullable
as double,rank: freezed == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [FantasyLineupDto].
extension FantasyLineupDtoPatterns on FantasyLineupDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FantasyLineupDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FantasyLineupDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FantasyLineupDto value)  $default,){
final _that = this;
switch (_that) {
case _FantasyLineupDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FantasyLineupDto value)?  $default,){
final _that = this;
switch (_that) {
case _FantasyLineupDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  String gameweekId,  List<LineupPick> picks,  String captainId,  double budgetUsed,  bool locked,  double totalPoints,  int? rank)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FantasyLineupDto() when $default != null:
return $default(_that.id,_that.userId,_that.gameweekId,_that.picks,_that.captainId,_that.budgetUsed,_that.locked,_that.totalPoints,_that.rank);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  String gameweekId,  List<LineupPick> picks,  String captainId,  double budgetUsed,  bool locked,  double totalPoints,  int? rank)  $default,) {final _that = this;
switch (_that) {
case _FantasyLineupDto():
return $default(_that.id,_that.userId,_that.gameweekId,_that.picks,_that.captainId,_that.budgetUsed,_that.locked,_that.totalPoints,_that.rank);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  String gameweekId,  List<LineupPick> picks,  String captainId,  double budgetUsed,  bool locked,  double totalPoints,  int? rank)?  $default,) {final _that = this;
switch (_that) {
case _FantasyLineupDto() when $default != null:
return $default(_that.id,_that.userId,_that.gameweekId,_that.picks,_that.captainId,_that.budgetUsed,_that.locked,_that.totalPoints,_that.rank);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FantasyLineupDto implements FantasyLineupDto {
  const _FantasyLineupDto({required this.id, required this.userId, required this.gameweekId, required final  List<LineupPick> picks, required this.captainId, required this.budgetUsed, this.locked = false, this.totalPoints = 0, this.rank}): _picks = picks;
  factory _FantasyLineupDto.fromJson(Map<String, dynamic> json) => _$FantasyLineupDtoFromJson(json);

@override final  String id;
@override final  String userId;
@override final  String gameweekId;
 final  List<LineupPick> _picks;
@override List<LineupPick> get picks {
  if (_picks is EqualUnmodifiableListView) return _picks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_picks);
}

@override final  String captainId;
@override final  double budgetUsed;
@override@JsonKey() final  bool locked;
@override@JsonKey() final  double totalPoints;
@override final  int? rank;

/// Create a copy of FantasyLineupDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FantasyLineupDtoCopyWith<_FantasyLineupDto> get copyWith => __$FantasyLineupDtoCopyWithImpl<_FantasyLineupDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FantasyLineupDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FantasyLineupDto&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.gameweekId, gameweekId) || other.gameweekId == gameweekId)&&const DeepCollectionEquality().equals(other._picks, _picks)&&(identical(other.captainId, captainId) || other.captainId == captainId)&&(identical(other.budgetUsed, budgetUsed) || other.budgetUsed == budgetUsed)&&(identical(other.locked, locked) || other.locked == locked)&&(identical(other.totalPoints, totalPoints) || other.totalPoints == totalPoints)&&(identical(other.rank, rank) || other.rank == rank));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,gameweekId,const DeepCollectionEquality().hash(_picks),captainId,budgetUsed,locked,totalPoints,rank);

@override
String toString() {
  return 'FantasyLineupDto(id: $id, userId: $userId, gameweekId: $gameweekId, picks: $picks, captainId: $captainId, budgetUsed: $budgetUsed, locked: $locked, totalPoints: $totalPoints, rank: $rank)';
}


}

/// @nodoc
abstract mixin class _$FantasyLineupDtoCopyWith<$Res> implements $FantasyLineupDtoCopyWith<$Res> {
  factory _$FantasyLineupDtoCopyWith(_FantasyLineupDto value, $Res Function(_FantasyLineupDto) _then) = __$FantasyLineupDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, String gameweekId, List<LineupPick> picks, String captainId, double budgetUsed, bool locked, double totalPoints, int? rank
});




}
/// @nodoc
class __$FantasyLineupDtoCopyWithImpl<$Res>
    implements _$FantasyLineupDtoCopyWith<$Res> {
  __$FantasyLineupDtoCopyWithImpl(this._self, this._then);

  final _FantasyLineupDto _self;
  final $Res Function(_FantasyLineupDto) _then;

/// Create a copy of FantasyLineupDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? gameweekId = null,Object? picks = null,Object? captainId = null,Object? budgetUsed = null,Object? locked = null,Object? totalPoints = null,Object? rank = freezed,}) {
  return _then(_FantasyLineupDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,gameweekId: null == gameweekId ? _self.gameweekId : gameweekId // ignore: cast_nullable_to_non_nullable
as String,picks: null == picks ? _self._picks : picks // ignore: cast_nullable_to_non_nullable
as List<LineupPick>,captainId: null == captainId ? _self.captainId : captainId // ignore: cast_nullable_to_non_nullable
as String,budgetUsed: null == budgetUsed ? _self.budgetUsed : budgetUsed // ignore: cast_nullable_to_non_nullable
as double,locked: null == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as bool,totalPoints: null == totalPoints ? _self.totalPoints : totalPoints // ignore: cast_nullable_to_non_nullable
as double,rank: freezed == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$LeaderboardEntry {

 int get rank; String get userId; String? get displayName; String? get photoUrl; double get points; double? get budgetUsed; int? get lineups;
/// Create a copy of LeaderboardEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LeaderboardEntryCopyWith<LeaderboardEntry> get copyWith => _$LeaderboardEntryCopyWithImpl<LeaderboardEntry>(this as LeaderboardEntry, _$identity);

  /// Serializes this LeaderboardEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LeaderboardEntry&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.points, points) || other.points == points)&&(identical(other.budgetUsed, budgetUsed) || other.budgetUsed == budgetUsed)&&(identical(other.lineups, lineups) || other.lineups == lineups));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,rank,userId,displayName,photoUrl,points,budgetUsed,lineups);

@override
String toString() {
  return 'LeaderboardEntry(rank: $rank, userId: $userId, displayName: $displayName, photoUrl: $photoUrl, points: $points, budgetUsed: $budgetUsed, lineups: $lineups)';
}


}

/// @nodoc
abstract mixin class $LeaderboardEntryCopyWith<$Res>  {
  factory $LeaderboardEntryCopyWith(LeaderboardEntry value, $Res Function(LeaderboardEntry) _then) = _$LeaderboardEntryCopyWithImpl;
@useResult
$Res call({
 int rank, String userId, String? displayName, String? photoUrl, double points, double? budgetUsed, int? lineups
});




}
/// @nodoc
class _$LeaderboardEntryCopyWithImpl<$Res>
    implements $LeaderboardEntryCopyWith<$Res> {
  _$LeaderboardEntryCopyWithImpl(this._self, this._then);

  final LeaderboardEntry _self;
  final $Res Function(LeaderboardEntry) _then;

/// Create a copy of LeaderboardEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rank = null,Object? userId = null,Object? displayName = freezed,Object? photoUrl = freezed,Object? points = null,Object? budgetUsed = freezed,Object? lineups = freezed,}) {
  return _then(_self.copyWith(
rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as double,budgetUsed: freezed == budgetUsed ? _self.budgetUsed : budgetUsed // ignore: cast_nullable_to_non_nullable
as double?,lineups: freezed == lineups ? _self.lineups : lineups // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [LeaderboardEntry].
extension LeaderboardEntryPatterns on LeaderboardEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LeaderboardEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LeaderboardEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LeaderboardEntry value)  $default,){
final _that = this;
switch (_that) {
case _LeaderboardEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LeaderboardEntry value)?  $default,){
final _that = this;
switch (_that) {
case _LeaderboardEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int rank,  String userId,  String? displayName,  String? photoUrl,  double points,  double? budgetUsed,  int? lineups)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LeaderboardEntry() when $default != null:
return $default(_that.rank,_that.userId,_that.displayName,_that.photoUrl,_that.points,_that.budgetUsed,_that.lineups);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int rank,  String userId,  String? displayName,  String? photoUrl,  double points,  double? budgetUsed,  int? lineups)  $default,) {final _that = this;
switch (_that) {
case _LeaderboardEntry():
return $default(_that.rank,_that.userId,_that.displayName,_that.photoUrl,_that.points,_that.budgetUsed,_that.lineups);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int rank,  String userId,  String? displayName,  String? photoUrl,  double points,  double? budgetUsed,  int? lineups)?  $default,) {final _that = this;
switch (_that) {
case _LeaderboardEntry() when $default != null:
return $default(_that.rank,_that.userId,_that.displayName,_that.photoUrl,_that.points,_that.budgetUsed,_that.lineups);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LeaderboardEntry implements LeaderboardEntry {
  const _LeaderboardEntry({required this.rank, required this.userId, this.displayName, this.photoUrl, required this.points, this.budgetUsed, this.lineups});
  factory _LeaderboardEntry.fromJson(Map<String, dynamic> json) => _$LeaderboardEntryFromJson(json);

@override final  int rank;
@override final  String userId;
@override final  String? displayName;
@override final  String? photoUrl;
@override final  double points;
@override final  double? budgetUsed;
@override final  int? lineups;

/// Create a copy of LeaderboardEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LeaderboardEntryCopyWith<_LeaderboardEntry> get copyWith => __$LeaderboardEntryCopyWithImpl<_LeaderboardEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LeaderboardEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LeaderboardEntry&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.points, points) || other.points == points)&&(identical(other.budgetUsed, budgetUsed) || other.budgetUsed == budgetUsed)&&(identical(other.lineups, lineups) || other.lineups == lineups));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,rank,userId,displayName,photoUrl,points,budgetUsed,lineups);

@override
String toString() {
  return 'LeaderboardEntry(rank: $rank, userId: $userId, displayName: $displayName, photoUrl: $photoUrl, points: $points, budgetUsed: $budgetUsed, lineups: $lineups)';
}


}

/// @nodoc
abstract mixin class _$LeaderboardEntryCopyWith<$Res> implements $LeaderboardEntryCopyWith<$Res> {
  factory _$LeaderboardEntryCopyWith(_LeaderboardEntry value, $Res Function(_LeaderboardEntry) _then) = __$LeaderboardEntryCopyWithImpl;
@override @useResult
$Res call({
 int rank, String userId, String? displayName, String? photoUrl, double points, double? budgetUsed, int? lineups
});




}
/// @nodoc
class __$LeaderboardEntryCopyWithImpl<$Res>
    implements _$LeaderboardEntryCopyWith<$Res> {
  __$LeaderboardEntryCopyWithImpl(this._self, this._then);

  final _LeaderboardEntry _self;
  final $Res Function(_LeaderboardEntry) _then;

/// Create a copy of LeaderboardEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rank = null,Object? userId = null,Object? displayName = freezed,Object? photoUrl = freezed,Object? points = null,Object? budgetUsed = freezed,Object? lineups = freezed,}) {
  return _then(_LeaderboardEntry(
rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as double,budgetUsed: freezed == budgetUsed ? _self.budgetUsed : budgetUsed // ignore: cast_nullable_to_non_nullable
as double?,lineups: freezed == lineups ? _self.lineups : lineups // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
