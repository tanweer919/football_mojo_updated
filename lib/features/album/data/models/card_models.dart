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
    // Scarcity primitives. All optional + defaulted so older payloads parse.
    DateTime? dropOpensAt,
    DateTime? dropClosesAt,
    int? maxPerUser,
    @Default(0) int uniqueOwners,
  }) = _CardTemplateDto;

  factory CardTemplateDto.fromJson(Map<String, dynamic> json) => _$CardTemplateDtoFromJson(json);
}

/// Helpers that don't require regenerated freezed plumbing.
extension CardTemplateScarcity on CardTemplateDto {
  bool get hasMintCap => totalSupply > 0;
  double get mintFraction =>
      totalSupply <= 0 ? 0 : (mintedCount / totalSupply).clamp(0, 1).toDouble();
  int get remaining => (totalSupply - mintedCount).clamp(0, 1 << 30).toInt();
  bool get isSoldOut => totalSupply > 0 && mintedCount >= totalSupply;

  bool get hasDropWindow => dropOpensAt != null || dropClosesAt != null;
  bool get dropOpen {
    final now = DateTime.now();
    if (dropOpensAt != null && now.isBefore(dropOpensAt!)) return false;
    if (dropClosesAt != null && !now.isBefore(dropClosesAt!)) return false;
    return true;
  }
  Duration? get untilOpen {
    if (dropOpensAt == null) return null;
    final d = dropOpensAt!.difference(DateTime.now());
    return d.isNegative ? null : d;
  }
  Duration? get untilClose {
    if (dropClosesAt == null) return null;
    final d = dropClosesAt!.difference(DateTime.now());
    return d.isNegative ? null : d;
  }
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
    /// Identity & progression — populated server-side. Defaulted so older
    /// /v1/cards/owned responses still parse.
    @Default(null) String? mintReason,
    @Default('SIGNUP_GIFT') String acquiredVia,
    @Default(0) int lifetimeGoals,
    @Default(0) int lifetimeAssists,
    @Default(0) int lifetimeMinutes,
    @Default(0) int lifetimeApps,
    @Default(0) int xp,
    @Default(0) int level,
    @Default(<String>[]) List<String> trophies,
  }) = _OwnedCardDto;

  factory OwnedCardDto.fromJson(Map<String, dynamic> json) => _$OwnedCardDtoFromJson(json);
}
