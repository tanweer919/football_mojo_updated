import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/design/motion.dart';
import '../../../../core/widgets/premium_image.dart';
import '../../data/models/fantasy_models.dart';

/// Mini player card pinned to a pitch slot. Filled state is a glassy badge with
/// jersey-style framing; empty state is a dashed circle prompting "+ Add".
class PlayerSlot extends StatelessWidget {
  const PlayerSlot({
    super.key,
    required this.position,
    required this.player,
    required this.isCaptain,
    required this.onTap,
    this.onLongPress,
    this.indexInRow = 0,
  });

  final PlayerPosition position;
  final PlayerValuationDto? player;
  final bool isCaptain;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final int indexInRow;

  static const _positionLabel = {
    PlayerPosition.GK: 'GK',
    PlayerPosition.DEF: 'DEF',
    PlayerPosition.MID: 'MID',
    PlayerPosition.FWD: 'FWD',
  };

  static const _positionColor = {
    PlayerPosition.GK: Color(0xFFFFD93D),
    PlayerPosition.DEF: Color(0xFF60A5FA),
    PlayerPosition.MID: Color(0xFF34D399),
    PlayerPosition.FWD: Color(0xFFF87171),
  };

  @override
  Widget build(BuildContext context) {
    final filled = player != null;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: filled ? 1.0 : 0.95,
        duration: AppMotion.sm,
        curve: AppMotion.swap,
        child: SizedBox(
          width: 86,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Avatar(
                player: player,
                position: position,
                isCaptain: isCaptain,
                accent: _positionColor[position]!,
              ),
              const SizedBox(height: 6),
              _NamePill(
                player: player,
                positionLabel: _positionLabel[position]!,
                accent: _positionColor[position]!,
              ),
            ],
          ),
        ),
      ),
    ).animate(target: filled ? 1 : 0).scaleXY(
          begin: 0.7,
          end: 1,
          duration: AppMotion.md,
          curve: AppMotion.pop,
        );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.player,
    required this.position,
    required this.isCaptain,
    required this.accent,
  });
  final PlayerValuationDto? player;
  final PlayerPosition position;
  final bool isCaptain;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final filled = player != null;

    final core = Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: filled
            ? LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.85),
                  accent.withValues(alpha: 0.35),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: filled ? null : Colors.black.withValues(alpha: 0.35),
        border: Border.all(
          color: filled ? Colors.white.withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.45),
          width: filled ? 2 : 1.4,
        ),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.55),
                  blurRadius: 14,
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: filled && player!.player.photoUrl != null
            ? PremiumImage(url: player!.player.photoUrl, fit: BoxFit.cover)
            : Center(
                child: Icon(
                  filled ? Icons.person : Icons.add,
                  color: Colors.white,
                  size: filled ? 28 : 24,
                ),
              ),
      ),
    );

    if (!isCaptain) return core;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        core,
        Positioned(
          top: -4, right: -4,
          child: Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFCD34D), Color(0xFFFBBF24)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.6),
              boxShadow: [
                BoxShadow(color: const Color(0xFFFBBF24).withValues(alpha: 0.55), blurRadius: 10),
              ],
            ),
            child: const Center(
              child: Text(
                'C',
                style: TextStyle(
                  color: Color(0xFF7C2D12),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ).animate().scaleXY(begin: 0.4, end: 1, duration: AppMotion.md, curve: AppMotion.pop),
        ),
      ],
    );
  }
}

class _NamePill extends StatelessWidget {
  const _NamePill({
    required this.player,
    required this.positionLabel,
    required this.accent,
  });
  final PlayerValuationDto? player;
  final String positionLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final filled = player != null;
    final lastName = filled ? player!.player.name.split(' ').last : positionLabel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: filled
              ? accent.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            lastName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.1,
            ),
          ),
          if (filled)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                player!.price.toStringAsFixed(1),
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
