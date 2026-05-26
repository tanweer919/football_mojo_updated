import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../design/app_spacing.dart';
import '../design/motion.dart';
import '../design/rarity_theme.dart';
import '../../features/album/data/models/card_models.dart';
import 'foil_overlay.dart';
import 'premium_image.dart';

/// The canonical NFT-style player card. One widget, six rarity faces.
///
/// Composition:
///   ┌───────────────────────────┐
///   │   [rarity tier]   [serial]│
///   │                           │
///   │     <player photo>        │
///   │     (transparent PNG      │
///   │      from api-football)   │
///   │                           │
///   │ ─────────────────────────│
///   │ <FIRST NAME>              │
///   │ <LAST NAME>               │
///   │ <team crest>  <pos> <pts> │
///   └───────────────────────────┘
///
/// The frame, surface gradient, accent colour, and foil overlay are all
/// driven by [RarityTheme.of].
class PlayerCard extends StatelessWidget {
  const PlayerCard({
    super.key,
    required this.rarity,
    required this.firstName,
    required this.lastName,
    this.teamName,
    this.teamCrestUrl,
    this.photoUrl,
    this.serialLabel,
    this.positionLabel,
    this.pointsLabel,
    this.size = PlayerCardSize.md,
    this.onTap,
    this.heroTag,
    this.indexInList = 0,
  });

  final CardRarity rarity;
  final String firstName;
  final String lastName;
  final String? teamName;
  final String? teamCrestUrl;
  final String? photoUrl;
  final String? serialLabel;
  final String? positionLabel;
  final String? pointsLabel;
  final PlayerCardSize size;
  final VoidCallback? onTap;
  final Object? heroTag;
  final int indexInList;

  @override
  Widget build(BuildContext context) {
    final theme = RarityTheme.of(rarity);
    final dim = size.dimensions;

    Widget card = AspectRatio(
      aspectRatio: 0.68,
      child: SizedBox(
        width: dim.width,
        child: _CardBody(
          theme: theme,
          firstName: firstName,
          lastName: lastName,
          teamName: teamName,
          teamCrestUrl: teamCrestUrl,
          photoUrl: photoUrl,
          serialLabel: serialLabel,
          positionLabel: positionLabel,
          pointsLabel: pointsLabel,
          size: size,
        ),
      ),
    );

    card = FoilOverlay(rarity: theme, child: card);

    if (heroTag != null) {
      card = Hero(tag: heroTag!, child: Material(color: Colors.transparent, child: card));
    }

    if (onTap != null) {
      card = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: card,
      );
    }

    return card
        .animate()
        .fade(duration: AppMotion.md, delay: (40 * indexInList).ms, curve: AppMotion.enter)
        .slideY(
          begin: 0.06,
          end: 0,
          duration: AppMotion.md,
          delay: (40 * indexInList).ms,
          curve: AppMotion.enter,
        );
  }
}

enum PlayerCardSize {
  xs, // 64w — pitch slot
  sm, // 96w — picker grid
  md, // 160w — album tile
  lg, // 240w — fantasy hero
  xl; // 320w — full detail screen

  _Dim get dimensions => switch (this) {
        PlayerCardSize.xs => const _Dim(64, 8),
        PlayerCardSize.sm => const _Dim(96, 10),
        PlayerCardSize.md => const _Dim(160, 14),
        PlayerCardSize.lg => const _Dim(240, 18),
        PlayerCardSize.xl => const _Dim(320, 24),
      };
}

class _Dim {
  const _Dim(this.width, this.padding);
  final double width;
  final double padding;
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.theme,
    required this.firstName,
    required this.lastName,
    required this.teamName,
    required this.teamCrestUrl,
    required this.photoUrl,
    required this.serialLabel,
    required this.positionLabel,
    required this.pointsLabel,
    required this.size,
  });

  final RarityTheme theme;
  final String firstName;
  final String lastName;
  final String? teamName;
  final String? teamCrestUrl;
  final String? photoUrl;
  final String? serialLabel;
  final String? positionLabel;
  final String? pointsLabel;
  final PlayerCardSize size;

  @override
  Widget build(BuildContext context) {
    final isCompact = size == PlayerCardSize.xs || size == PlayerCardSize.sm;
    final padding = theme.gradient.colors.isNotEmpty ? size.dimensions.padding : 0.0;
    final radius = BorderRadius.circular(AppRadii.xl);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: theme.gradient,
        border: Border.all(color: theme.frame, width: 1.5),
        boxShadow: [
          BoxShadow(color: theme.glow, blurRadius: 24, spreadRadius: -4, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Inner frame (a thin metallic ring just inside the outer border).
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: theme.frame.withValues(alpha: 0.5), width: 0.8),
                ),
              ),
            ),
          ),
          if (theme.particles)
            const Positioned.fill(child: _ConstellationLayer()),

          // Player photo — top half of the card.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                children: [
                  Expanded(
                    flex: 7,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.md)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Soft radial glow behind the photo.
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  theme.accent.withValues(alpha: 0.35),
                                  Colors.transparent,
                                ],
                                radius: 0.9,
                                center: const Alignment(0, -0.2),
                              ),
                            ),
                          ),
                          if (photoUrl != null)
                            PremiumImage(url: photoUrl, fit: BoxFit.contain)
                          else
                            Center(
                              child: Icon(
                                Icons.person,
                                color: theme.frame.withValues(alpha: 0.4),
                                size: size.dimensions.width * 0.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (!isCompact)
                    Expanded(
                      flex: 4,
                      child: _Identity(
                        firstName: firstName,
                        lastName: lastName,
                        teamName: teamName,
                        teamCrestUrl: teamCrestUrl,
                        positionLabel: positionLabel,
                        pointsLabel: pointsLabel,
                        theme: theme,
                      ),
                    )
                  else
                    Expanded(
                      flex: 3,
                      child: _CompactIdentity(
                        lastName: lastName,
                        positionLabel: positionLabel,
                        pointsLabel: pointsLabel,
                        theme: theme,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Top-left rarity ribbon.
          if (!isCompact)
            Positioned(
              top: 8,
              left: 8,
              child: _Ribbon(label: theme.label.toUpperCase(), color: theme.accent),
            ),
          // Top-right serial.
          if (serialLabel != null && !isCompact)
            Positioned(
              top: 8,
              right: 8,
              child: _Serial(label: serialLabel!, color: theme.frame),
            ),
          // Iconic signature stroke (decorative).
          if (theme.signature != null && !isCompact)
            Positioned(
              bottom: 8,
              right: 10,
              child: Text(
                theme.signature!,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.accent.withValues(alpha: 0.7),
                  letterSpacing: 1.2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Ribbon extends StatelessWidget {
  const _Ribbon({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 9,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _Serial extends StatelessWidget {
  const _Serial({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 9,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({
    required this.firstName,
    required this.lastName,
    required this.teamName,
    required this.teamCrestUrl,
    required this.positionLabel,
    required this.pointsLabel,
    required this.theme,
  });
  final String firstName;
  final String lastName;
  final String? teamName;
  final String? teamCrestUrl;
  final String? positionLabel;
  final String? pointsLabel;
  final RarityTheme theme;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (firstName.isNotEmpty)
            Text(
              firstName.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.frame.withValues(alpha: 0.7),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
          Text(
            lastName.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (teamCrestUrl != null) ...[
                ClipOval(
                  child: PremiumImage(url: teamCrestUrl, fit: BoxFit.cover),
                ).constrained(),
                const SizedBox(width: 4),
              ],
              if (positionLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    positionLabel!,
                    style: TextStyle(
                      color: theme.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              const Spacer(),
              if (pointsLabel != null)
                Text(
                  pointsLabel!,
                  style: TextStyle(
                    color: theme.accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactIdentity extends StatelessWidget {
  const _CompactIdentity({
    required this.lastName,
    required this.positionLabel,
    required this.pointsLabel,
    required this.theme,
  });
  final String lastName;
  final String? positionLabel;
  final String? pointsLabel;
  final RarityTheme theme;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            lastName.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: -0.1,
            ),
          ),
          if (pointsLabel != null)
            Text(
              pointsLabel!,
              style: TextStyle(
                color: theme.accent,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}

class _ConstellationLayer extends StatefulWidget {
  const _ConstellationLayer();
  @override
  State<_ConstellationLayer> createState() => _ConstellationLayerState();
}

class _ConstellationLayerState extends State<_ConstellationLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(painter: _StarPainter(progress: _c.value)),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter({required this.progress});
  final double progress;

  static const _seeds = <Offset>[
    Offset(0.12, 0.18),
    Offset(0.74, 0.22),
    Offset(0.38, 0.10),
    Offset(0.85, 0.55),
    Offset(0.22, 0.62),
    Offset(0.55, 0.40),
    Offset(0.62, 0.78),
    Offset(0.92, 0.92),
    Offset(0.08, 0.88),
    Offset(0.45, 0.92),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (int i = 0; i < _seeds.length; i++) {
      final s = _seeds[i];
      // Pulse each star at a different phase.
      final phase = (progress + i / _seeds.length) % 1.0;
      final pulse = 0.4 + 0.6 * (0.5 - (phase - 0.5).abs()) * 2;
      paint.color = Colors.white.withValues(alpha: 0.18 + 0.5 * pulse);
      canvas.drawCircle(
        Offset(s.dx * size.width, s.dy * size.height),
        0.7 + 1.2 * pulse,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.progress != progress;
}

extension on Widget {
  Widget constrained() => SizedBox(width: 12, height: 12, child: this);
}
