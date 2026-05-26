import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/pcard.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../album/data/models/card_models.dart';
import '../../../profile/data/profile_models.dart';
import '../../../profile/data/profile_repository.dart';

/// Full-screen "your first card" reveal. Composed of three short stages
/// driven by a single [AnimationController]:
///
///   0.00 – 0.40   Background ramps up. Particle burst from centre, gold ring
///                 expands.
///   0.40 – 0.78   Card sweeps up from below, rotating + scaling into place.
///                 Foil shimmer sweeps once across the card.
///   0.78 – 1.00   Rarity badge pops in, headline + CTA fade up.
///
/// Performance:
///   - One AnimationController, evaluated at vsync. No nested controllers.
///   - Particles are CustomPaint with a single shader (cheap on Impeller).
///   - PCard underneath is the same widget the rest of the app uses, so any
///     foil/shimmer work it already does is amortised.
class WelcomeCardRevealScreen extends ConsumerStatefulWidget {
  const WelcomeCardRevealScreen({super.key, required this.card});
  final WelcomeCard card;

  @override
  ConsumerState<WelcomeCardRevealScreen> createState() => _WelcomeCardRevealScreenState();
}

class _WelcomeCardRevealScreenState extends ConsumerState<WelcomeCardRevealScreen>
    with TickerProviderStateMixin {
  late final AnimationController _master;
  /// Loops indefinitely once the master finishes — drives the idle bob +
  /// shine sweep so the card stays "alive" on screen.
  late final AnimationController _idle;

  @override
  void initState() {
    super.initState();
    _master = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..forward();
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

  CardRarity get _rarity => switch (widget.card.rarity.toUpperCase()) {
        'UNCOMMON' => CardRarity.UNCOMMON,
        'RARE' => CardRarity.RARE,
        'EPIC' => CardRarity.EPIC,
        'LEGENDARY' => CardRarity.LEGENDARY,
        'ICONIC' => CardRarity.ICONIC,
        _ => CardRarity.COMMON,
      };

  String get _rarityName => widget.card.rarity[0] + widget.card.rarity.substring(1).toLowerCase();

  Color get _rarityColor => switch (_rarity) {
        CardRarity.COMMON => const Color(0xFF8C8E91),
        CardRarity.UNCOMMON => const Color(0xFF4FB976),
        CardRarity.RARE => const Color(0xFF5BA9F7),
        CardRarity.EPIC => const Color(0xFFA268D5),
        CardRarity.LEGENDARY => AppColors.gold,
        CardRarity.ICONIC => const Color(0xFFD656B5),
      };

  Future<void> _dismiss() async {
    await ref.read(profileRepositoryProvider).dismissWelcomeCard();
    ref.invalidate(myProfileProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: AnimatedBuilder(
        animation: Listenable.merge([_master, _idle]),
        builder: (_, __) {
          final t = _master.value;
          final iT = _idle.value;
          // Stage curves.
          final bgOpacity = Curves.easeOutCubic.transform(t.clamp(0.0, 0.4) / 0.4);
          final particle = Curves.easeOutCubic.transform(t.clamp(0.0, 0.55) / 0.55);
          final cardT = Curves.easeOutCubic.transform(((t - 0.30).clamp(0.0, 0.48)) / 0.48);
          final chromeT = Curves.easeOutCubic.transform(((t - 0.78).clamp(0.0, 0.22)) / 0.22);
          final idleBob = math.sin(iT * math.pi * 2) * 6;

          return Stack(
            fit: StackFit.expand,
            children: [
              // ── Layer 1: gradient + radial wash background.
              Opacity(
                opacity: bgOpacity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        _rarityColor.withValues(alpha: 0.30),
                        AppColors.bgDeep,
                      ],
                      radius: 0.95,
                      center: const Alignment(0, -0.1),
                    ),
                  ),
                ),
              ),

              // ── Layer 2: expanding gold-rim ring + sparks.
              Center(
                child: CustomPaint(
                  size: MediaQuery.sizeOf(context),
                  painter: _BurstPainter(progress: particle, color: _rarityColor),
                ),
              ),

              // ── Layer 3: the card itself, sweeping in + idle bob.
              Center(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..translate(0.0, (1.0 - cardT) * 220.0 + idleBob)
                    ..scale(0.55 + 0.45 * cardT)
                    ..rotateY((1.0 - cardT) * math.pi)
                    ..rotateZ((1.0 - cardT) * 0.10),
                  child: Opacity(
                    opacity: cardT.clamp(0.0, 1.0),
                    child: SizedBox(
                      width: 240,
                      child: PCard(
                        rarity: _rarity,
                        rating: _ratingFromRarity(_rarity),
                        name: widget.card.playerName ?? 'Mystery',
                        position: widget.card.playerPosition ?? 'PL',
                        country: widget.card.teamName == null
                            ? '—'
                            : (widget.card.teamName!.length >= 3
                                ? widget.card.teamName!.substring(0, 3).toUpperCase()
                                : widget.card.teamName!.toUpperCase()),
                        photoUrl: widget.card.artUrl,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Layer 4: top eyebrow ("Welcome gift").
              Positioned(
                top: MediaQuery.viewPaddingOf(context).top + 36,
                left: 0, right: 0,
                child: Opacity(
                  opacity: bgOpacity,
                  child: Column(
                    children: [
                      const Eyebrow('Welcome gift', gold: true, size: 12),
                      const SizedBox(height: 6),
                      Text(
                        'A card to start your\ncollection.',
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

              // ── Layer 5: bottom rarity chip + name + CTA.
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.all(20),
                  child: Opacity(
                    opacity: chromeT,
                    child: Transform.translate(
                      offset: Offset(0, (1.0 - chromeT) * 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _RarityRibbon(label: _rarityName, color: _rarityColor),
                          const SizedBox(height: 14),
                          Text(
                            widget.card.playerName ?? 'Mystery card',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.78,
                              color: AppColors.fg,
                              height: 1.1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Serial #${widget.card.serialNumber} of ${widget.card.totalSupply}',
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
                              fontSize: 11,
                              color: AppColors.muted,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 22),
                          GoldButton(
                            label: 'Add to my collection',
                            icon: Icons.check,
                            onPressed: _dismiss,
                            expand: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _ratingFromRarity(CardRarity r) => switch (r) {
        CardRarity.COMMON => 75,
        CardRarity.UNCOMMON => 79,
        CardRarity.RARE => 84,
        CardRarity.EPIC => 88,
        CardRarity.LEGENDARY => 92,
        CardRarity.ICONIC => 95,
      };
}

/// Expanding gold-tinted ring + radial sparks. Single-pass paint, ~8 sparks
/// max — extremely cheap on Impeller.
class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  static const _sparkAngles = <double>[
    0.0, 0.785, 1.57, 2.36, 3.14, 3.93, 4.71, 5.50,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2 - 10);
    final maxR = math.min(size.width, size.height) * 0.45;
    final r = maxR * progress;

    // Expanding rim ring.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: (1.0 - progress) * 0.55);
    canvas.drawCircle(c, r, ring);

    // Soft inner glow disc.
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.22 * (1.0 - progress)), Colors.transparent],
      ).createShader(Rect.fromCircle(center: c, radius: r * 1.1));
    canvas.drawCircle(c, r * 1.1, glow);

    // Sparks — 8 short trails radiating outward.
    final sparkPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = color.withValues(alpha: (1.0 - progress) * 0.85);
    for (final a in _sparkAngles) {
      final inner = r * 0.92;
      final outer = r * 1.08;
      final x1 = c.dx + math.cos(a) * inner;
      final y1 = c.dy + math.sin(a) * inner;
      final x2 = c.dx + math.cos(a) * outer;
      final y2 = c.dy + math.sin(a) * outer;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.progress != progress;
}

class _RarityRibbon extends StatelessWidget {
  const _RarityRibbon({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}
