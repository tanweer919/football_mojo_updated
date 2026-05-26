import 'package:flutter/material.dart';

import '../design/motion.dart';

/// Flip-clock style numeric score. Each digit slides up when its value
/// changes — feels like an old stadium scoreboard.
class ScoreFlip extends StatelessWidget {
  const ScoreFlip({
    super.key,
    required this.value,
    this.style,
    this.minDigits = 1,
  });

  final int value;
  final TextStyle? style;
  final int minDigits;

  @override
  Widget build(BuildContext context) {
    final str = value.toString().padLeft(minDigits, '0');
    final s = (style ?? Theme.of(context).textTheme.displayMedium)?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w900,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < str.length; i++) _Digit(digit: str[i], style: s),
      ],
    );
  }
}

class _Digit extends StatelessWidget {
  const _Digit({required this.digit, required this.style});
  final String digit;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final width = (style?.fontSize ?? 32) * 0.62;
    return SizedBox(
      width: width,
      child: AnimatedSwitcher(
        duration: AppMotion.md,
        switchInCurve: AppMotion.pop,
        switchOutCurve: AppMotion.exit,
        transitionBuilder: (child, anim) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.6),
            end: Offset.zero,
          ).animate(anim);
          return ClipRect(
            child: SlideTransition(
              position: slide,
              child: FadeTransition(opacity: anim, child: child),
            ),
          );
        },
        child: Text(
          digit,
          key: ValueKey(digit),
          textAlign: TextAlign.center,
          style: style,
        ),
      ),
    );
  }
}
