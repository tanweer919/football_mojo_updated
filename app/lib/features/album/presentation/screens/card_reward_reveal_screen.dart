import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/pcard.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../data/models/card_models.dart';

/// Full-screen reward reveal for a freshly-claimed card — the same
/// celebratory beat as the signup welcome card, reused for rewarded-ad
/// drops. A burst + the card sweeping/scaling in, then a CTA to view it.
class CardRewardRevealScreen extends StatefulWidget {
  const CardRewardRevealScreen({
    super.key,
    required this.card,
    this.eyebrow = 'Reward unlocked',
    this.title = 'A new card for\nyour collection.',
  });

  final OwnedCardDto card;
  final String eyebrow;
  final String title;

  @override
  State<CardRewardRevealScreen> createState() => _CardRewardRevealScreenState();
}

class _CardRewardRevealScreenState extends State<CardRewardRevealScreen>
    with TickerProviderStateMixin {
  late final AnimationController _master;
  late final AnimationController _idle;

  @override
  void initState() {
    super.initState();
    _master = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..forward();
    _idle = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _master.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) _idle.repeat();
    });
  }

  @override
  void dispose() {
    _master.dispose();
    _idle.dispose();
    super.dispose();
  }

  CardRarity get _rarity => widget.card.template.rarity;

  Color get _rarityColor => switch (_rarity) {
        CardRarity.COMMON => const Color(0xFF8C8E91),
        CardRarity.UNCOMMON => const Color(0xFF4FB976),
        CardRarity.RARE => const Color(0xFF5BA9F7),
        CardRarity.EPIC => const Color(0xFFA268D5),
        CardRarity.LEGENDARY => AppColors.gold,
        CardRarity.ICONIC => const Color(0xFFD656B5),
      };

  int get _rating => switch (_rarity) {
        CardRarity.COMMON => 75,
        CardRarity.UNCOMMON => 79,
        CardRarity.RARE => 84,
        CardRarity.EPIC => 88,
        CardRarity.LEGENDARY => 92,
        CardRarity.ICONIC => 95,
      };

  @override
  Widget build(BuildContext context) {
    final t = widget.card.template;
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: AnimatedBuilder(
        animation: Listenable.merge([_master, _idle]),
        builder: (_, __) {
          final p = _master.value;
          final iT = _idle.value;
          final bgOpacity = Curves.easeOutCubic.transform((p.clamp(0.0, 0.4)) / 0.4);
          final particle = Curves.easeOutCubic.transform((p.clamp(0.0, 0.55)) / 0.55);
          final cardT = Curves.easeOutCubic.transform(((p - 0.30).clamp(0.0, 0.48)) / 0.48);
          final chromeT = Curves.easeOutCubic.transform(((p - 0.78).clamp(0.0, 0.22)) / 0.22);
          final idleBob = math.sin(iT * math.pi * 2) * 6;

          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: bgOpacity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [_rarityColor.withValues(alpha: 0.30), AppColors.bgDeep],
                      radius: 0.95,
                      center: const Alignment(0, -0.1),
                    ),
                  ),
                ),
              ),
              Center(
                child: CustomPaint(
                  size: MediaQuery.sizeOf(context),
                  painter: _BurstPainter(progress: particle, color: _rarityColor),
                ),
              ),
              // Card sweeps up + spins in, then idles with a gentle bob.
              Center(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..translate(0.0, (1.0 - cardT) * 220.0 + idleBob)
                    ..scale(0.55 + 0.45 * cardT)
                    ..rotateY((1.0 - cardT) * math.pi),
                  child: Opacity(
                    opacity: cardT.clamp(0.0, 1.0),
                    child: SizedBox(
                      width: 240,
                      child: PCard(
                        rarity: _rarity,
                        rating: _rating,
                        name: t.playerName ?? 'Mystery',
                        position: 'PL',
                        country: (t.teamName != null && t.teamName!.length >= 3)
                            ? t.teamName!.substring(0, 3).toUpperCase()
                            : (t.teamName?.toUpperCase() ?? '—'),
                        photoUrl: t.artUrl,
                        serialNumber: widget.card.serialNumber,
                        totalSupply: t.totalSupply,
                      ),
                    ),
                  ),
                ),
              ),
              // Headline.
              Positioned(
                top: MediaQuery.viewPaddingOf(context).top + 36,
                left: 0, right: 0,
                child: Opacity(
                  opacity: bgOpacity,
                  child: Column(
                    children: [
                      Eyebrow(widget.eyebrow, gold: true, size: 12),
                      const SizedBox(height: 6),
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.44,
                          color: AppColors.fg,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // CTAs.
              Positioned(
                left: 24, right: 24,
                bottom: MediaQuery.viewPaddingOf(context).bottom + 28,
                child: Opacity(
                  opacity: chromeT,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GoldButton(
                        label: 'View in collection',
                        expand: true,
                        // Pop true → caller opens the card detail.
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Done',
                            style: TextStyle(color: Colors.white54, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Expanding gold-rim ring + radiating sparks behind the card.
class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height * 0.46);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * (1 - progress)
      ..color = color.withValues(alpha: (1 - progress) * 0.7);
    canvas.drawCircle(center, progress * size.width * 0.42, ring);

    final spark = Paint()..color = color.withValues(alpha: (1 - progress));
    const n = 12;
    final r = progress * size.width * 0.46;
    for (var i = 0; i < n; i++) {
      final a = (i / n) * math.pi * 2;
      final p = center + Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawCircle(p, 3.0 * (1 - progress), spark);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}
