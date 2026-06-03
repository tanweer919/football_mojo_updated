import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../data/repositories/fantasy_repository.dart' show CardBoost;

/// "Owned card" boost pill — surfaces the passive fantasy multiplier a user
/// gets for owning a player's collectible card (COMMON +10% … ICONIC +60%).
/// The rarity tints the pill so higher tiers read hotter.
///
/// [compact] drops the rarity word and shrinks the pill so it fits on the
/// 76px-wide pitch tiles; the full form ("+60% · ICONIC") is used in the
/// roomier player-picker rows.
class CardBoostBadge extends StatelessWidget {
  const CardBoostBadge({super.key, required this.boost, this.compact = false});
  final CardBoost boost;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = _rarityColor(boost.rarity);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 1.5 : 3,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: compact ? 8 : 10, color: c),
          SizedBox(width: compact ? 2 : 4),
          Text(
            compact ? boost.pctLabel : '${boost.pctLabel} · ${_rarityWord(boost.rarity)}',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
              fontSize: compact ? 8 : 9.5,
              fontWeight: FontWeight.w800,
              color: c,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  static Color _rarityColor(String rarity) => switch (rarity.toUpperCase()) {
        'ICONIC' => const Color(0xFFD2B0F0),
        'LEGENDARY' => AppColors.gold,
        'EPIC' => const Color(0xFFB06FE0),
        'RARE' => const Color(0xFF5AA9E2),
        'UNCOMMON' => AppColors.pitch,
        _ => AppColors.fgSoft,
      };

  static String _rarityWord(String rarity) =>
      rarity.isEmpty ? 'CARD' : rarity.toUpperCase();
}
