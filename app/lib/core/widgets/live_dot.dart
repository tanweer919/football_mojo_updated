import 'package:flutter/material.dart';

import '../design/app_colors.dart';

/// `.live-dot` from `components.css`. Pulsing red dot + uppercase mono "LIVE"
/// label with 0.1em tracking.
class LiveDot extends StatefulWidget {
  const LiveDot({
    super.key,
    this.size = 6,
    this.label = 'LIVE',
    this.showLabel = true,
    this.color,
  });
  final double size;
  final String label;
  final bool showLabel;
  final Color? color;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.live;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = Curves.easeInOut.transform(_c.value);
            // Pulse: opacity 1 → 0.35.
            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.35 + 0.65 * (1 - t)),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.18),
                    blurRadius: 0,
                    spreadRadius: 4,
                  ),
                ],
              ),
            );
          },
        ),
        if (widget.showLabel) ...[
          const SizedBox(width: 6),
          Text(
            widget.label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: const ['SF Mono', 'Menlo', 'Roboto Mono', 'monospace'],
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: color,
            ),
          ),
        ],
      ],
    );
  }
}
