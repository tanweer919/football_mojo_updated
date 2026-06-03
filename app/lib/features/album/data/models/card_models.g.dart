// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CardTemplateDto _$CardTemplateDtoFromJson(Map<String, dynamic> json) =>
    _CardTemplateDto(
      id: json['id'] as String,
      edition: json['edition'] as String,
      rarity: $enumDecode(_$CardRarityEnumMap, json['rarity']),
      totalSupply: (json['totalSupply'] as num).toInt(),
      mintedCount: (json['mintedCount'] as num).toInt(),
      artUrl: json['artUrl'] as String,
      frameStyle: json['frameStyle'] as String? ?? 'base',
      playerName: json['playerName'] as String?,
      teamName: json['teamName'] as String?,
      teamCrestUrl: json['teamCrestUrl'] as String?,
      position: json['position'] as String?,
      dropOpensAt:
          json['dropOpensAt'] == null
              ? null
              : DateTime.parse(json['dropOpensAt'] as String),
      dropClosesAt:
          json['dropClosesAt'] == null
              ? null
              : DateTime.parse(json['dropClosesAt'] as String),
      maxPerUser: (json['maxPerUser'] as num?)?.toInt(),
      uniqueOwners: (json['uniqueOwners'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$CardTemplateDtoToJson(_CardTemplateDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'edition': instance.edition,
      'rarity': _$CardRarityEnumMap[instance.rarity]!,
      'totalSupply': instance.totalSupply,
      'mintedCount': instance.mintedCount,
      'artUrl': instance.artUrl,
      'frameStyle': instance.frameStyle,
      'playerName': instance.playerName,
      'teamName': instance.teamName,
      'teamCrestUrl': instance.teamCrestUrl,
      'position': instance.position,
      'dropOpensAt': instance.dropOpensAt?.toIso8601String(),
      'dropClosesAt': instance.dropClosesAt?.toIso8601String(),
      'maxPerUser': instance.maxPerUser,
      'uniqueOwners': instance.uniqueOwners,
    };

const _$CardRarityEnumMap = {
  CardRarity.COMMON: 'COMMON',
  CardRarity.UNCOMMON: 'UNCOMMON',
  CardRarity.RARE: 'RARE',
  CardRarity.EPIC: 'EPIC',
  CardRarity.LEGENDARY: 'LEGENDARY',
  CardRarity.ICONIC: 'ICONIC',
};

_AlbumEntryDto _$AlbumEntryDtoFromJson(Map<String, dynamic> json) =>
    _AlbumEntryDto(
      templateId: json['templateId'] as String,
      template: CardTemplateDto.fromJson(
        json['template'] as Map<String, dynamic>,
      ),
      owned: (json['owned'] as num).toInt(),
      firstOwnedCardId: json['firstOwnedCardId'] as String?,
    );

Map<String, dynamic> _$AlbumEntryDtoToJson(_AlbumEntryDto instance) =>
    <String, dynamic>{
      'templateId': instance.templateId,
      'template': instance.template,
      'owned': instance.owned,
      'firstOwnedCardId': instance.firstOwnedCardId,
    };

_AlbumSetDto _$AlbumSetDtoFromJson(Map<String, dynamic> json) => _AlbumSetDto(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String,
  total: (json['total'] as num).toInt(),
  completedCount: (json['completedCount'] as num).toInt(),
  entries:
      (json['entries'] as List<dynamic>)
          .map((e) => AlbumEntryDto.fromJson(e as Map<String, dynamic>))
          .toList(),
);

Map<String, dynamic> _$AlbumSetDtoToJson(_AlbumSetDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'total': instance.total,
      'completedCount': instance.completedCount,
      'entries': instance.entries,
    };

_OwnedCardDto _$OwnedCardDtoFromJson(
  Map<String, dynamic> json,
) => _OwnedCardDto(
  id: json['id'] as String,
  templateId: json['templateId'] as String,
  serialNumber: (json['serialNumber'] as num).toInt(),
  template: CardTemplateDto.fromJson(json['template'] as Map<String, dynamic>),
  mintedAt: DateTime.parse(json['mintedAt'] as String),
  mintReason: json['mintReason'] as String? ?? null,
  acquiredVia: json['acquiredVia'] as String? ?? 'SIGNUP_GIFT',
  lifetimeGoals: (json['lifetimeGoals'] as num?)?.toInt() ?? 0,
  lifetimeAssists: (json['lifetimeAssists'] as num?)?.toInt() ?? 0,
  lifetimeMinutes: (json['lifetimeMinutes'] as num?)?.toInt() ?? 0,
  lifetimeApps: (json['lifetimeApps'] as num?)?.toInt() ?? 0,
  xp: (json['xp'] as num?)?.toInt() ?? 0,
  level: (json['level'] as num?)?.toInt() ?? 0,
  trophies:
      (json['trophies'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
);

Map<String, dynamic> _$OwnedCardDtoToJson(_OwnedCardDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'templateId': instance.templateId,
      'serialNumber': instance.serialNumber,
      'template': instance.template,
      'mintedAt': instance.mintedAt.toIso8601String(),
      'mintReason': instance.mintReason,
      'acquiredVia': instance.acquiredVia,
      'lifetimeGoals': instance.lifetimeGoals,
      'lifetimeAssists': instance.lifetimeAssists,
      'lifetimeMinutes': instance.lifetimeMinutes,
      'lifetimeApps': instance.lifetimeApps,
      'xp': instance.xp,
      'level': instance.level,
      'trophies': instance.trophies,
    };
