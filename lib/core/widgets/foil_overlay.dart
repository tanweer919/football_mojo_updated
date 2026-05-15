import 'package:flutter/material.dart';

import '../design/rarity_theme.dart';

/// Animated foil/holographic shimmer that sweeps diagonally across the child.
/// Strength is driven by [RarityTheme.foilOpacity], so Common gets nothing
/// while Iconic gets a full-opacity rainbow sweep.
///
/// Uses a single AnimationController + a custom shader, so cost is one paint
/// per frame for the duration of the sweep — Impeller chews through this.
class FoilOverlay extends StatefulWidget {
  const FoilOverlay({
    super.key,
    required this.rarity,
    required this.child,
    this.duration = const Duration(milliseconds: 3200),
  });

  final RarityTheme rarity;
  final Widget child;
  final Duration duration;

  @override
  State<FoilOverlay> createState() => _FoilOverlayState();
}

class _FoilOverlayState extends State<FoilOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    if (widget.rarity.foilOpacity > 0) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant FoilOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rarity.foilOpacity != widget.rarity.foilOpacity) {
      if (widget.rarity.foilOpacity > 0 && !_c.isAnimating) {
        _c.repeat();
      } else if (widget.rarity.foilOpacity == 0) {
        _c.stop();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rarity.foilOpacity == 0) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        // Sweep from top-left to bottom-right, then loop. Phase shift creates
        // the illusion of foil catching the light at different angles.
        return Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: ShaderMask(
                  blendMode: BlendMode.plus,
                  shaderCallback: (rect) {
                    final dx = (t * 2 - 1) * rect.width;
                    final dy = (t * 2 - 1) * rect.height;
                    return widget.rarity.foilGradient.createShader(
                      Rect.fromLTWH(
                        rect.left + dx,
                        rect.top + dy,
                        rect.width,
                        rect.height,
                      ),
                    );
                  },
                  child: Opacity(
                    opacity: widget.rarity.foilOpacity * 0.55,
                    child: Container(color: Colors.white),
                  ),
                ),
              ),
            ),
            if (widget.rarity.holographic)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _HolographicStripes(progress: t, opacity: widget.rarity.foilOpacity),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HolographicStripes extends CustomPainter {
  _HolographicStripes({required this.progress, required this.opacity});
  final double progress;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final stripes = const [
      Color(0xFFFF6B6B),
      Color(0xFFFFD93D),
      Color(0xFF6BCB77),
      Color(0xFF4D96FF),
      Color(0xFFB57CFF),
    ];
    final h = size.height;
    final stripeHeight = h / stripes.length;
    final shift = progress * stripeHeight * 2;

    for (int i = 0; i < stripes.length; i++) {
      final paint = Paint()
        ..color = stripes[i].withValues(alpha: 0.06 * opacity)
        ..blendMode = BlendMode.plus;
      canvas.drawRect(
        Rect.fromLTWH(0, (i * stripeHeight) - shift, size.width, stripeHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HolographicStripes old) =>
      old.progress != progress || old.opacity != opacity;
}
