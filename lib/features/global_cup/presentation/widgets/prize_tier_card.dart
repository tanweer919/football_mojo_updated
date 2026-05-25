import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/repositories/global_cup_repository.dart';

class PrizeTierCard extends StatelessWidget {
  const PrizeTierCard({super.key, required this.prize, this.indexInList = 0});
  final GlobalCupPrize prize;
  final int indexInList;

  static const _rarityGradient = <String, List<Color>>{
    'COMMON':    [Color(0xFF374151), Color(0xFF1F2937)],
    'UNCOMMON':  [Color(0xFF14532D), Color(0xFF052E16)],
    'RARE':      [Color(0xFF1E3A8A), Color(0xFF0B1F5C)],
    'EPIC':      [Color(0xFF581C87), Color(0xFF2E1065)],
    'LEGENDARY': [Color(0xFFB45309), Color(0xFF7C2D12)],
    'ICONIC':    [Color(0xFFBE123C), Color(0xFF4C0519)],
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _rarityGradient[prize.cardRarity] ?? _rarityGradient['COMMON']!;
    final isElite = prize.cardRarity == 'ICONIC' || prize.cardRarity == 'LEGENDARY';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: palette, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: prize.artUrl,
              width: 64, height: 88, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(width: 64, height: 88, color: Colors.white12),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        prize.cardRarity,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(prize.description,
                    style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  prize.rankFrom == prize.rankTo
                      ? 'Rank #${prize.rankFrom}'
                      : 'Ranks ${prize.rankFrom} – ${prize.rankTo}',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 4),
                Text(
                  '${prize.supply} card${prize.supply == 1 ? '' : 's'} · ${prize.cardEdition}',
                  style: theme.textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate(onPlay: isElite ? (c) => c.repeat(reverse: true) : null)
        .shimmer(duration: isElite ? 2400.ms : 0.ms, color: Colors.white.withValues(alpha: 0.18));
  }
}
