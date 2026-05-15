import 'package:flutter/material.dart';

import '../design/app_gradients.dart';
import '../design/rarity_theme.dart';
import '../../features/album/data/models/card_models.dart';
import 'rarity_chip.dart';

/// `.pcard` from `components.css`. NFT-style player card.
///
/// Layered (back → front):
///   1. `pcard__bg`     — per-rarity gradient (animated for Iconic)
///   2. (player photo) — optional cached image, fitted contain
///   3. `pcard__glow`   — soft white radial top-center, blend screen
///   4. `pcard__shine`  — diagonal specular sweep
///   5. `pcard__chrome` — bottom scrim + chrome (rating top-left, chip top-right,
///      name + meta bottom)
///
/// Aspect ratio is fixed at 0.66 by the spec.
class PCard extends StatelessWidget {
  const PCard({
    super.key,
    required this.rarity,
    required this.rating,
    required this.name,
    required this.position,
    required this.country,
    this.photoUrl,
    this.width,
    this.onTap,
    this.heroTag,
  });

  final CardRarity rarity;

  /// 2-3 digit rating (89, 95, etc).
  final int rating;
  final String name;

  /// Position abbreviation (CM / ST / GK …).
  final String position;

  /// Country code abbreviation (ESP / ENG / ARG …).
  final String country;
  final String? photoUrl;
  final double? width;
  final VoidCallback? onTap;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = RarityTheme.of(rarity);

    Widget core = AspectRatio(
      aspectRatio: 0.66,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. bg — per-rarity gradient.
            DecoratedBox(decoration: BoxDecoration(gradient: theme.cardGradient)),

            // 2. player photo (optional)
            if (photoUrl != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 60),
                child: Image.network(
                  photoUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),

            // 3. glow — soft white radial, mix-blend-mode: screen approximated
            //    via low-alpha overlay.
            const DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.pcardHeadGlow)),

            // 4. shine — diagonal specular sweep.
            const DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.pcardShine)),

            // 5. bottom scrim
            const DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.pcardScrim)),

            // 6. chrome
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rating + rarity chip row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rating.toString(),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.84,
                          height: 1.0,
                          color: theme.ratingColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const Spacer(),
                      RarityChip(rarity: rarity),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    position.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                      color: theme.ratingColor.withValues(alpha: 0.7),
                    ),
                  ),
                  const Spacer(),
                  // Name (bottom)
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        position.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.08,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        country.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.08,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (heroTag != null) {
      core = Hero(tag: heroTag!, child: Material(color: Colors.transparent, child: core));
    }
    if (width != null) {
      core = SizedBox(width: width, child: core);
    }
    if (onTap == null) return core;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: core);
  }
}
