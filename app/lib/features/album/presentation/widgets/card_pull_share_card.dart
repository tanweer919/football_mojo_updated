import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/design/rarity_theme.dart';
import '../../../../core/share/share_card_frame.dart';
import '../../data/models/card_models.dart';

/// Share artifact for an owned card "pull". Renders the rarity-themed
/// frame with art, serial number, and player name.
class CardPullShareCard extends StatelessWidget {
  const CardPullShareCard({
    super.key,
    required this.card,
    this.userHandle,
  });
  final OwnedCardDto card;
  final String? userHandle;

  @override
  Widget build(BuildContext context) {
    final t = card.template;
    final theme = RarityTheme.of(t.rarity);
    final isIconic = t.rarity == CardRarity.ICONIC;

    return ShareCardFrame(
      title: 'I PULLED A ${theme.label.toUpperCase()}',
      subtitle: t.playerName ?? t.edition,
      userHandle: userHandle,
      child: Center(
        child: AspectRatio(
          aspectRatio: 0.72,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: theme.gradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.frame, width: 2),
              boxShadow: [
                BoxShadow(
                  color: theme.glow,
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (t.artUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 60),
                    child: CachedNetworkImage(
                      imageUrl: t.artUrl,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                Positioned(
                  top: 12,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: theme.accent.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      theme.label.toUpperCase(),
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '#${card.serialNumber} / ${t.totalSupply}',
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 16,
                  child: Column(
                    children: [
                      Text(
                        (t.playerName ?? t.edition).toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (t.teamName != null)
                        Text(
                          t.teamName!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isIconic)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              const Color(0xFFEBD9A8).withValues(alpha: 0.20),
                              Colors.transparent,
                            ],
                            begin: const Alignment(-0.6, -1),
                            end: const Alignment(0.8, 1),
                            stops: const [0.35, 0.5, 0.65],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
