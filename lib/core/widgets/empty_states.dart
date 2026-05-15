import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import 'eyebrow.dart';

/// Animated empty-state primitive used across the app.
///
/// Hero element is a custom-painted glyph with a slow pulse + soft glow ring,
/// not a bare Material icon. Matches the spec's gold-tinted aesthetic and
/// makes the surface feel "alive" instead of broken.
class PitchEmptyState extends StatelessWidget {
  const PitchEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.glyph = EmptyGlyph.football,
    this.action,
    this.actionLabel,
    this.padding = const EdgeInsets.all(28),
  });

  final String? eyebrow;
  final String title;
  final String subtitle;
  final EmptyGlyph glyph;
  final VoidCallback? action;
  final String? actionLabel;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnimatedGlyph(glyph: glyph),
          const SizedBox(height: 20),
          if (eyebrow != null) ...[
            Eyebrow(eyebrow!, gold: true),
            const SizedBox(height: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.44,
              color: AppColors.fg,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.muted,
              height: 1.5,
            ),
          ),
          if (action != null && actionLabel != null) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: action,
              icon: const Icon(Icons.arrow_forward, size: 14, color: AppColors.gold),
              label: Text(
                actionLabel!,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: AppColors.gold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Available glyphs. Each is painted procedurally — no asset bundling needed.
enum EmptyGlyph {
  /// Football resting on a pitch line — for empty match lists.
  football,
  /// Stack of 3 cards — for empty collection.
  cards,
  /// Newspaper with masthead — for empty news.
  paper,
  /// Trophy silhouette — for fantasy / tournament empty state.
  trophy,
}

class _AnimatedGlyph extends StatefulWidget {
  const _AnimatedGlyph({required this.glyph});
  final EmptyGlyph glyph;
  @override
  State<_AnimatedGlyph> createState() => _AnimatedGlyphState();
}

class _AnimatedGlyphState extends State<_AnimatedGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value;
          // Sine-eased pulse for the glow ring (0.25 → 0.55 → 0.25).
          final pulse = 0.25 + 0.30 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));
          // Slow Y bob for the glyph.
          final dy = math.sin(t * 2 * math.pi) * 4;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Glow ring.
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: pulse * 0.45),
                      AppColors.gold.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
              // Inner disc.
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.goldHairline),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1F1814), Color(0xFF110C09)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              // The glyph itself.
              Transform.translate(
                offset: Offset(0, dy),
                child: SizedBox(
                  width: 32, height: 32,
                  child: CustomPaint(painter: _GlyphPainter(widget.glyph)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph);
  final EmptyGlyph glyph;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    switch (glyph) {
      case EmptyGlyph.football:
        _football(canvas, c, size.width / 2);
      case EmptyGlyph.cards:
        _cards(canvas, size);
      case EmptyGlyph.paper:
        _paper(canvas, size);
      case EmptyGlyph.trophy:
        _trophy(canvas, size);
    }
  }

  void _football(Canvas c, Offset center, double r) {
    final fill = Paint()..color = AppColors.gold;
    final stroke = Paint()
      ..color = const Color(0xFF1E1810)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    c.drawCircle(center, r, fill);
    // Pentagon hint
    final p = Path();
    final inner = r * 0.5;
    for (int i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      final x = center.dx + inner * math.cos(a);
      final y = center.dy + inner * math.sin(a);
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    p.close();
    c.drawPath(p, Paint()..color = const Color(0xFF1E1810));
    c.drawPath(p, stroke);
  }

  void _cards(Canvas c, Size s) {
    final w = s.width * 0.45;
    final h = s.height * 0.7;
    void card(Offset o, double rot, Color color) {
      final r = Paint()..color = color;
      final stroke = Paint()
        ..color = AppColors.goldHairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(rot);
      final rect = RRect.fromLTRBR(-w / 2, -h / 2, w / 2, h / 2, const Radius.circular(3));
      c.drawRRect(rect, r);
      c.drawRRect(rect, stroke);
      c.restore();
    }
    card(Offset(s.width * 0.32, s.height * 0.5), -0.35, const Color(0xFF1A1714));
    card(Offset(s.width * 0.68, s.height * 0.5),  0.35, const Color(0xFF1A1714));
    card(Offset(s.width * 0.50, s.height * 0.45), 0.0,  AppColors.gold);
  }

  void _paper(Canvas c, Size s) {
    final fill = Paint()..color = AppColors.gold;
    final stroke = Paint()
      ..color = const Color(0xFF1E1810)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rect = RRect.fromLTRBR(s.width * 0.15, s.height * 0.18, s.width * 0.85, s.height * 0.86, const Radius.circular(3));
    c.drawRRect(rect, fill);
    // headline lines
    final line = Paint()
      ..color = const Color(0xFF1E1810)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(s.width * 0.22, s.height * 0.32), Offset(s.width * 0.78, s.height * 0.32), line);
    c.drawLine(Offset(s.width * 0.22, s.height * 0.46), Offset(s.width * 0.62, s.height * 0.46), line);
    c.drawLine(Offset(s.width * 0.22, s.height * 0.58), Offset(s.width * 0.74, s.height * 0.58), line);
    c.drawLine(Offset(s.width * 0.22, s.height * 0.70), Offset(s.width * 0.55, s.height * 0.70), line);
    c.drawRRect(rect, stroke);
  }

  void _trophy(Canvas c, Size s) {
    final fill = Paint()..color = AppColors.gold;
    // Cup body
    final body = Path()
      ..moveTo(s.width * 0.30, s.height * 0.20)
      ..lineTo(s.width * 0.70, s.height * 0.20)
      ..quadraticBezierTo(s.width * 0.85, s.height * 0.30, s.width * 0.62, s.height * 0.62)
      ..lineTo(s.width * 0.38, s.height * 0.62)
      ..quadraticBezierTo(s.width * 0.15, s.height * 0.30, s.width * 0.30, s.height * 0.20)
      ..close();
    c.drawPath(body, fill);
    // Stem + base
    c.drawRect(Rect.fromLTWH(s.width * 0.45, s.height * 0.62, s.width * 0.10, s.height * 0.12), fill);
    c.drawRRect(
      RRect.fromLTRBR(s.width * 0.30, s.height * 0.74, s.width * 0.70, s.height * 0.84, const Radius.circular(2)),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
