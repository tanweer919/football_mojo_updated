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
            // Mint scarcity badge — "247 / 500" along the bottom-right.
            // Only shown when a real cap exists.
            if (entry.template.hasMintCap)
              Positioned(
                right: 6, bottom: 26,
                child: _MintBadge(
                  minted: entry.template.mintedCount,
                  total: entry.template.totalSupply,
                  accent: theme.accent,
                ),
              ),
            // Drop window countdown chip — only when the window matters.
            if (entry.template.hasDropWindow)
              Positioned(
                left: 6, bottom: 26,
                child: _DropChip(template: entry.template, accent: theme.accent),
              ),
            // Iconic shimmer sweep — single subtle pass every few seconds.
            // The rarity theme exposes a holographic flag we previously didn't honour.
            if (theme.label.toUpperCase() == 'ICONIC')
              const Positioned.fill(child: _IconicShimmer()),
          ],
        ),
      ),
    );
  }
}

class _MintBadge extends StatelessWidget {
  const _MintBadge({required this.minted, required this.total, required this.accent});
  final int minted;
  final int total;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final remaining = (total - minted).clamp(0, 1 << 30);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 0.5),
      ),
      child: Text(
        remaining == 0 ? 'SOLD OUT' : '$minted / $total',
        style: TextStyle(
          color: remaining == 0 ? Colors.redAccent.shade100 : accent,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _DropChip extends StatelessWidget {
  const _DropChip({required this.template, required this.accent});
  final CardTemplateDto template;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final untilOpen = template.untilOpen;
    final untilClose = template.untilClose;
    final label = untilOpen != null
        ? 'OPENS ${_short(untilOpen)}'
        : untilClose != null
            ? 'CLOSES ${_short(untilClose)}'
            : 'CLOSED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static String _short(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}d';
    if (d.inHours >= 1) return '${d.inHours}h';
    return '${d.inMinutes}m';
  }
}

class _IconicShimmer extends StatefulWidget {
  const _IconicShimmer();
  @override
  State<_IconicShimmer> createState() => _IconicShimmerState();
}

class _IconicShimmerState extends State<_IconicShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => ShaderMask(
          blendMode: BlendMode.plus,
          shaderCallback: (rect) {
            final t = _c.value;
            return LinearGradient(
              begin: Alignment(-1 + 2 * t, -1),
              end: Alignment(1 + 2 * t, 1),
              colors: const [
                Color(0x00FFFFFF),
                Color(0x33FFEED4),
                Color(0x88FFE6A2),
                Color(0x33FFEED4),
                Color(0x00FFFFFF),
              ],
              stops: const [0.30, 0.45, 0.50, 0.55, 0.70],
            ).createShader(rect);
          },
          child: Container(color: Colors.white.withValues(alpha: 0.05)),
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
