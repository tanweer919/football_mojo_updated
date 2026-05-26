import 'package:flutter/material.dart';

import '../../features/album/data/models/card_models.dart';
import 'app_colors.dart';

/// Per-rarity visual treatment, lifted directly from `components.css`:
///   .pcard--common     → cool grey gradient
///   .pcard--rare       → blue gradient
///   .pcard--epic       → purple gradient
///   .pcard--legendary  → champagne gold gradient
///   .pcard--iconic     → animated multi-color gradient
class RarityTheme {
  const RarityTheme({
    required this.label,
    required this.cardGradient,
    required this.ratingColor,
    required this.chipFg,
    required this.chipBg,
    required this.chipBorder,
    required this.iconic,
    required this.accentTint,
  });

  /// User-facing label.
  final String label;

  /// Per-rarity background gradient — a luxe multi-stop linear sweep that
  /// reads as "tier" at a glance: gunmetal → jade → sapphire → royal purple
  /// → champagne → holographic. Paired with a radial highlight + specular
  /// sweep + (on higher tiers) a holographic sheen.
  final LinearGradient cardGradient;

  /// Color of the big rating number (`pcard__rating`).
  final Color ratingColor;

  /// `.rarity--{tier}` chip foreground.
  final Color chipFg;

  /// Chip background color or gradient (legendary/iconic use a gradient).
  final Color? chipBg;

  /// Chip border.
  final Color chipBorder;

  /// True only for Iconic — paints the animated gradient sweep on the chip
  /// and the card background.
  final bool iconic;

  /// Saturated accent colour: powers the radial highlight at the top of the
  /// card and the holographic sheen on Rare+ tiers. Picked to be a touch
  /// brighter than the base gradient so it reads as a faux light source.
  final Color accentTint;

  static RarityTheme of(CardRarity r) => switch (r) {
        // COMMON — gunmetal: cool grey-blue with a faint silver sheen. Reads
        // as "base tier" without looking cheap.
        CardRarity.COMMON => const RarityTheme(
            label: 'Common',
            cardGradient: LinearGradient(
              colors: [
                Color(0xFF3A4150),
                Color(0xFF222730),
                Color(0xFF11141A),
              ],
              stops: [0.0, 0.55, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            ratingColor: Color(0xFFD7DBE3),
            chipFg: Color(0xFFD7DBE3),
            chipBg: Color(0x80383C45),
            chipBorder: Color(0xFF555B68),
            iconic: false,
            accentTint: Color(0xFF8C97AB),
          ),
        // UNCOMMON — jade: emerald top fading to deep forest. Bright but
        // restrained, like dark malachite.
        CardRarity.UNCOMMON => const RarityTheme(
            label: 'Uncommon',
            cardGradient: LinearGradient(
              colors: [
                Color(0xFF2EA070),
                Color(0xFF155A3D),
                Color(0xFF06251A),
              ],
              stops: [0.0, 0.55, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            ratingColor: Color(0xFFB6F0CE),
            chipFg: Color(0xFFB6F0CE),
            chipBg: Color(0x803F4D44),
            chipBorder: Color(0xFF4FC489),
            iconic: false,
            accentTint: Color(0xFF7FE3B5),
          ),
        // RARE — sapphire: ocean blue with a cyan highlight at the top.
        CardRarity.RARE => const RarityTheme(
            label: 'Rare',
            cardGradient: LinearGradient(
              colors: [
                Color(0xFF3A98E5),
                Color(0xFF1E4E8E),
                Color(0xFF071735),
              ],
              stops: [0.0, 0.55, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            ratingColor: Color(0xFFCFE5FA),
            chipFg: Color(0xFFCFE5FA),
            chipBg: Color(0x66285E91),
            chipBorder: Color(0xFF4FA6E8),
            iconic: false,
            accentTint: Color(0xFF7EC8FF),
          ),
        // EPIC — royal violet: rich plum to deep purple. Magenta tint at the
        // accent for an iridescent shimmer.
        CardRarity.EPIC => const RarityTheme(
            label: 'Epic',
            cardGradient: LinearGradient(
              colors: [
                Color(0xFF9B4FE4),
                Color(0xFF4E1E94),
                Color(0xFF160534),
              ],
              stops: [0.0, 0.55, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            ratingColor: Color(0xFFE0BFFF),
            chipFg: Color(0xFFE0BFFF),
            chipBg: Color(0x803A1A65),
            chipBorder: Color(0xFF8347D6),
            iconic: false,
            accentTint: Color(0xFFC489FF),
          ),
        // LEGENDARY — champagne gold: warm honey top to chocolate base.
        CardRarity.LEGENDARY => const RarityTheme(
            label: 'Legendary',
            cardGradient: LinearGradient(
              colors: [
                Color(0xFFE8C778),
                Color(0xFF8E6422),
                Color(0xFF2D1E08),
              ],
              stops: [0.0, 0.55, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            ratingColor: Color(0xFFFFEEC8),
            chipFg: Color(0xFF1E1810),
            chipBg: null, // chip uses buttonGold gradient
            chipBorder: AppColors.goldDeep,
            iconic: false,
            accentTint: Color(0xFFFFD884),
          ),
        // ICONIC — holographic: bright magenta → cyan → amber on a near-black
        // base. The shine + holographic overlay paints the rainbow.
        CardRarity.ICONIC => const RarityTheme(
            label: 'Iconic',
            cardGradient: LinearGradient(
              colors: [
                Color(0xFFE15FB8),
                Color(0xFF7044D6),
                Color(0xFF0B0418),
              ],
              stops: [0.0, 0.45, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            ratingColor: Color(0xFFFFE3A8),
            chipFg: Color(0xFF1E1810),
            chipBg: null, // chip uses iconic animated gradient
            chipBorder: Color(0xFFD66BB5),
            iconic: true,
            accentTint: Color(0xFFFFA3DC),
          ),
      };

  /// Iconic gradient (used by chip + card bg).
  static const iconicGradient = LinearGradient(
    colors: [
      AppColors.rIconicA,
      AppColors.rIconicB,
      AppColors.rIconicC,
    ],
    stops: [0, 0.5, 1.0],
    begin: Alignment(-1, 0),
    end: Alignment(1, 0),
  );

  // ─── Legacy aliases for screens still on the previous design ─────────────
  // These let pre-existing widgets compile while they are being ported to
  // the new spec. Visual fidelity for those widgets is no longer guaranteed.

  LinearGradient get gradient => cardGradient;
  Color get frame => chipBorder;
  Color get glow => ratingColor.withValues(alpha: 0.4);
  Color get accent => ratingColor;
  Color get surface => cardGradient.colors.last;
  String? get signature => iconic ? 'Iconic' : null;
  bool get holographic => iconic || rarityIndexAtLeastRare;
  bool get particles => iconic;
  double get foilOpacity {
    if (iconic) return 1.0;
    if (label == 'Legendary') return 0.9;
    if (label == 'Epic') return 0.75;
    if (label == 'Rare') return 0.55;
    return 0.0;
  }
  LinearGradient get foilGradient => iconicGradient;

  bool get rarityIndexAtLeastRare {
    // True for Rare/Epic/Legendary/Iconic.
    return label == 'Rare' ||
        label == 'Epic' ||
        label == 'Legendary' ||
        label == 'Iconic';
  }
}
