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
  });

  /// User-facing label.
  final String label;

  /// Background gradient applied to `.pcard__bg`.
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

  static RarityTheme of(CardRarity r) => switch (r) {
        CardRarity.COMMON => const RarityTheme(
            label: 'Common',
            cardGradient: LinearGradient(
              colors: [Color(0xFF4F5460), Color(0xFF1F2228)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            ratingColor: Color(0xFFD7D9DD),
            chipFg: Color(0xFFD7D9DD),
            chipBg: Color(0x80383C45),
            chipBorder: Color(0xFF4D525C),
            iconic: false,
          ),
        CardRarity.UNCOMMON => const RarityTheme(
            label: 'Uncommon',
            cardGradient: LinearGradient(
              colors: [Color(0xFF3F4D44), Color(0xFF1B221E)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            ratingColor: Color(0xFFCFE8D7),
            chipFg: Color(0xFFCFE8D7),
            chipBg: Color(0x803F4D44),
            chipBorder: Color(0xFF587A66),
            iconic: false,
          ),
        CardRarity.RARE => const RarityTheme(
            label: 'Rare',
            cardGradient: LinearGradient(
              colors: [Color(0xFF2D6CA0), Color(0xFF132540)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            ratingColor: Color(0xFFAFD8F0),
            chipFg: Color(0xFFAFD8F0),
            chipBg: Color(0x66285E91),
            chipBorder: Color(0xFF3F8AC9),
            iconic: false,
          ),
        CardRarity.EPIC => const RarityTheme(
            label: 'Epic',
            cardGradient: LinearGradient(
              colors: [Color(0xFF6533A8), Color(0xFF1F1138)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            ratingColor: Color(0xFFD2B0F0),
            chipFg: Color(0xFFD2B0F0),
            chipBg: Color(0x803A1A65),
            chipBorder: Color(0xFF6B3CB2),
            iconic: false,
          ),
        CardRarity.LEGENDARY => const RarityTheme(
            label: 'Legendary',
            cardGradient: LinearGradient(
              colors: [Color(0xFFA77F36), Color(0xFF3B2C12)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            ratingColor: Color(0xFFF6E5B5),
            chipFg: Color(0xFF1E1810),
            chipBg: null, // chip uses buttonGold gradient
            chipBorder: AppColors.goldDeep,
            iconic: false,
          ),
        CardRarity.ICONIC => const RarityTheme(
            label: 'Iconic',
            cardGradient: LinearGradient(
              colors: [
                AppColors.rIconicA,
                AppColors.rIconicB,
                AppColors.rIconicC,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0, 0.5, 1.0],
            ),
            ratingColor: Color(0xFFFAEDD3),
            chipFg: Color(0xFF1E1810),
            chipBg: null, // chip uses iconic animated gradient
            chipBorder: Color(0xFFD66BB5),
            iconic: true,
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
