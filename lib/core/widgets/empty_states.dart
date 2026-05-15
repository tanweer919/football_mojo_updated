import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import 'eyebrow.dart';

/// Animated empty-state primitive used across the app.
///
/// Layout: glyph centered above title/subtitle, all centered horizontally.
/// Glyph dimensions are proportional so the state feels balanced inside any
/// container — caller can override via [glyphSize] for prominent moments.
class PitchEmptyState extends StatelessWidget {
  const PitchEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.glyph = EmptyGlyph.football,
    this.action,
    this.actionLabel,
    this.padding = const EdgeInsets.fromLTRB(24, 28, 24, 28),
    this.glyphSize = 88,
  });

  final String? eyebrow;
  final String title;
  final String subtitle;
  final EmptyGlyph glyph;
  final VoidCallback? action;
  final String? actionLabel;
  final EdgeInsets padding;
  final double glyphSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _AnimatedGlyph(glyph: glyph, size: glyphSize),
          const SizedBox(height: 18),
          if (eyebrow != null) ...[
            Eyebrow(eyebrow!, gold: true),
            const SizedBox(height: 8),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.40,
              color: AppColors.fg,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.muted,
                height: 1.5,
              ),
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

enum EmptyGlyph { football, cards, paper, trophy }

class _AnimatedGlyph extends StatefulWidget {
  const _AnimatedGlyph({required this.glyph, required this.size});
  final EmptyGlyph glyph;
  final double size;
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
    final outer = widget.size;
    final disc = outer * 0.62;
    final glyph = outer * 0.36;
    return SizedBox(
      width: outer,
      height: outer,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value;
          final pulse = 0.25 + 0.30 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));
          final dy = math.sin(t * 2 * math.pi) * 4;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: outer, height: outer,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: pulse * 0.45),
                      AppColors.gold.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              Container(
                width: disc, height: disc,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.goldHairline),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1F1814), Color(0xFF110C09)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, dy),
                child: SizedBox(
                  width: glyph, height: glyph,
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
    final dark = Paint()..color = const Color(0xFF1E1810);
    final stroke = Paint()
      ..color = const Color(0xFF1E1810)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    c.drawCircle(center, r, fill);
    final p = Path();
    final inner = r * 0.55;
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
    c.drawPath(p, dark);
    c.drawPath(p, stroke);
  }
  void _cards(Canvas c, Size s) {
    final w = s.width * 0.42;
    final h = s.height * 0.66;
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
    card(Offset(s.width * 0.30, s.height * 0.55), -0.32, const Color(0xFF1A1714));
    card(Offset(s.width * 0.70, s.height * 0.55),  0.32, const Color(0xFF1A1714));
    card(Offset(s.width * 0.50, s.height * 0.46), 0.0,  AppColors.gold);
  }
  void _paper(Canvas c, Size s) {
    final fill = Paint()..color = AppColors.gold;
    final stroke = Paint()
      ..color = const Color(0xFF1E1810)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rect = RRect.fromLTRBR(s.width * 0.15, s.height * 0.18, s.width * 0.85, s.height * 0.86, const Radius.circular(3));
    c.drawRRect(rect, fill);
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
    final body = Path()
      ..moveTo(s.width * 0.30, s.height * 0.20)
      ..lineTo(s.width * 0.70, s.height * 0.20)
      ..quadraticBezierTo(s.width * 0.85, s.height * 0.30, s.width * 0.62, s.height * 0.62)
      ..lineTo(s.width * 0.38, s.height * 0.62)
      ..quadraticBezierTo(s.width * 0.15, s.height * 0.30, s.width * 0.30, s.height * 0.20)
      ..close();
    c.drawPath(body, fill);
    c.drawRect(Rect.fromLTWH(s.width * 0.45, s.height * 0.62, s.width * 0.10, s.height * 0.12), fill);
    c.drawRRect(
      RRect.fromLTRBR(s.width * 0.30, s.height * 0.74, s.width * 0.70, s.height * 0.84, const Radius.circular(2)),
      fill,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
