import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/motion.dart';
import '../../../../core/design/rarity_theme.dart';
import '../../../../core/widgets/foil_overlay.dart';
import '../../../../core/widgets/premium_image.dart';
import '../../data/models/card_models.dart';

/// Album tile. Owned cards render the rarity-themed mini player card with foil
/// overlay. Unowned cards render a dimmed silhouette to tease the collection.
class StickerTile extends StatelessWidget {
  const StickerTile({super.key, required this.entry, this.indexInList = 0, this.onTap});
  final AlbumEntryDto entry;
  final int indexInList;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final owned = entry.owned > 0;
    final theme = RarityTheme.of(entry.template.rarity);

    Widget core;
    if (!owned) {
      core = _UnownedTile(theme: theme);
    } else {
      core = _OwnedTile(entry: entry, theme: theme);
    }

    Widget child = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 0.72,
          child: core,
        ),
      ),
    );

    return child
        .animate()
        .fade(duration: AppMotion.md, delay: (30 * indexInList).ms, curve: AppMotion.enter)
        .scaleXY(begin: 0.94, end: 1, duration: AppMotion.md, delay: (30 * indexInList).ms);
  }
}

class _OwnedTile extends StatelessWidget {
  const _OwnedTile({required this.entry, required this.theme});
  final AlbumEntryDto entry;
  final RarityTheme theme;
  @override
  Widget build(BuildContext context) {
    return FoilOverlay(
      rarity: theme,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: theme.gradient,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: theme.frame, width: 1.4),
          boxShadow: [
            BoxShadow(color: theme.glow, blurRadius: 16, spreadRadius: -3, offset: const Offset(0, 6)),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Inner ring
            Padding(
              padding: const EdgeInsets.all(3),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: theme.frame.withValues(alpha: 0.45)),
                ),
              ),
            ),
            // Photo + glow
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 40),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [theme.accent.withValues(alpha: 0.45), Colors.transparent],
                        radius: 0.95,
                        center: const Alignment(0, -0.1),
                      ),
                    ),
                  ),
                  PremiumImage(url: entry.template.artUrl, fit: BoxFit.contain),
                ],
              ),
            ),
            // Rarity ribbon
            Positioned(
              top: 6, left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: theme.accent.withValues(alpha: 0.5), width: 0.5),
                ),
                child: Text(
                  theme.label.toUpperCase(),
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            // Name
            Positioned(
              left: 6, right: 6, bottom: 6,
              child: Text(
                (entry.template.playerName ?? 'Player').toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            // Duplicate count badge
            if (entry.owned > 1)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.accent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '×${entry.owned}',
                    style: TextStyle(
                      color: theme.surface,
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnownedTile extends StatelessWidget {
  const _UnownedTile({required this.theme});
  final RarityTheme theme;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Faint dashed silhouette.
          Center(
            child: Icon(
              Icons.help_outline,
              size: 36,
              color: scheme.outline.withValues(alpha: 0.5),
            ),
          ),
          Positioned(
            top: 6, left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                theme.label.toUpperCase(),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          Positioned(
            left: 6, right: 6, bottom: 8,
            child: Text(
              'NOT YET OWNED',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
