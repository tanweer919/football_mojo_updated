import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/album/data/models/card_models.dart';
import '../design/app_colors.dart';
import 'pcard.dart';

/// `.stage-3d` from the onboarding/sign-in spec — three PCards arranged in
/// 3D perspective: legendary back-left, epic back-right, iconic front-floating.
///
/// Front card has a continuous Y-translate + slight rotateY so it reads as
/// "alive". Back cards are static. A gold radial floor-glow sits underneath.
class PitchHeroStack extends StatefulWidget {
  const PitchHeroStack({super.key, this.height = 380, this.cardWidth = 180});
  final double height;
  final double cardWidth;

  @override
  State<PitchHeroStack> createState() => _PitchHeroStackState();
}

class _PitchHeroStackState extends State<PitchHeroStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))
        ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Floor glow (under the cards).
          Positioned(
            bottom: widget.height * 0.12,
            child: IgnorePointer(
              child: Container(
                width: widget.cardWidth * 1.55,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x73C99A3D), Color(0x00C99A3D)],
                  ),
                ),
              ),
            ),
          ),

          // Back-left card — legendary, slight back rotation.
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..translate(-widget.cardWidth * 0.4, 0.0, -100.0)
              ..rotateZ(-0.21),
            child: Opacity(
              opacity: 0.85,
              child: SizedBox(
                width: widget.cardWidth,
                child: PCard(
                  rarity: CardRarity.LEGENDARY,
                  rating: 93,
                  name: 'MBAPPÉ',
                  position: 'ST',
                  country: 'FRA',
                  // TheSportsDB cutout (transparent PNG) — PCard auto-detects
                  // the thesportsdb.com host and uses its alpha-clean render
                  // path. Reliable + crisp, unlike the api-sports headshots.
                  photoUrl: 'https://r2.thesportsdb.com/images/media/player/cutout/h9u9vz1733653583.png',
                  clubCrestUrl: 'https://media.api-sports.io/football/teams/541.png',
                ),
              ),
            ),
          ),

          // Back-right card — epic.
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..translate(widget.cardWidth * 0.4, 0.0, -100.0)
              ..rotateZ(0.21),
            child: Opacity(
              opacity: 0.85,
              child: SizedBox(
                width: widget.cardWidth,
                child: PCard(
                  rarity: CardRarity.EPIC,
                  rating: 89,
                  name: 'BELLINGHAM',
                  position: 'AM',
                  country: 'ENG',
                  photoUrl: 'https://r2.thesportsdb.com/images/media/player/cutout/trk5271750271712.png',
                  clubCrestUrl: 'https://media.api-sports.io/football/teams/541.png',
                ),
              ),
            ),
          ),

          // Front card — iconic, floats with sine wave + rotateY.
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = _ctrl.value * math.pi * 2;
              final dy = math.sin(t) * -12;       // ±12px vertical
              final ry = math.sin(t) * 0.10;       // ±~6° rotation
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..translate(0.0, dy, 0.0)
                  ..rotateY(ry),
                child: SizedBox(
                  width: widget.cardWidth,
                  child: PCard(
                    rarity: CardRarity.ICONIC,
                    rating: 95,
                    name: 'YAMAL',
                    position: 'RW',
                    country: 'ESP',
                    photoUrl: 'https://r2.thesportsdb.com/images/media/player/cutout/m9n4ja1761512633.png',
                    clubCrestUrl: 'https://media.api-sports.io/football/teams/529.png',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// `--bg`-style grid pattern painter used on the onboarding/sign-in surfaces.
/// Two intersecting hairline grids (24px) over the dark luxury background.
class PitchGridBackground extends StatelessWidget {
  const PitchGridBackground({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A0907), Color(0xFF050402)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        // Three radial color washes per spec.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [Color(0x80372B17), Colors.transparent],
              center: Alignment(0, -1),
              radius: 0.7,
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [Color(0x66442566), Colors.transparent],
              center: Alignment(1, 1),
              radius: 0.7,
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [Color(0x4D1F4769), Colors.transparent],
              center: Alignment(-1, 1),
              radius: 0.7,
            ),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _GridPainter())),
        if (child != null) Positioned.fill(child: child!),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 1;
    final v = AppColors.gold.withValues(alpha: 0.025);
    final h = AppColors.gold.withValues(alpha: 0.020);
    paint.color = v;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    paint.color = h;
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
