import 'package:freezed_annotation/freezed_annotation.dart';

part 'card_models.freezed.dart';
part 'card_models.g.dart';

enum CardRarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, ICONIC }

@freezed
abstract class CardTemplateDto with _$CardTemplateDto {
  const factory CardTemplateDto({
    required String id,
    required String edition,
    required CardRarity rarity,
    required int totalSupply,
    required int mintedCount,
    required String artUrl,
    @Default('base') String frameStyle,
    String? playerName,
    String? teamName,
    String? teamCrestUrl,
  }) = _CardTemplateDto;

  factory CardTemplateDto.fromJson(Map<String, dynamic> json) => _$CardTemplateDtoFromJson(json);
}

@freezed
abstract class AlbumEntryDto with _$AlbumEntryDto {
  const factory AlbumEntryDto({
    required String templateId,
    required CardTemplateDto template,
    required int owned,
    String? firstOwnedCardId,
  }) = _AlbumEntryDto;

  factory AlbumEntryDto.fromJson(Map<String, dynamic> json) => _$AlbumEntryDtoFromJson(json);
}

@freezed
abstract class AlbumSetDto with _$AlbumSetDto {
  const factory AlbumSetDto({
    required String id,
    required String name,
    required String description,
    required int total,
    required int completedCount,
    required List<AlbumEntryDto> entries,
  }) = _AlbumSetDto;

  factory AlbumSetDto.fromJson(Map<String, dynamic> json) => _$AlbumSetDtoFromJson(json);
}

@freezed
abstract class OwnedCardDto with _$OwnedCardDto {
  const factory OwnedCardDto({
    required String id,
    required String templateId,
    required int serialNumber,
    required CardTemplateDto template,
    required DateTime mintedAt,
  }) = _OwnedCardDto;

  factory OwnedCardDto.fromJson(Map<String, dynamic> json) => _$OwnedCardDtoFromJson(json);
}
