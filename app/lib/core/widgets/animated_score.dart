import 'package:flutter/material.dart';

/// Number-flip animation when a score changes. Uses AnimatedSwitcher with a
/// vertical slide+fade — feels like the digit rolls over.
class AnimatedScore extends StatelessWidget {
  const AnimatedScore({super.key, required this.value, this.style});
  final int value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(begin: const Offset(0, 0.45), end: Offset.zero)
            .animate(animation);
        return ClipRect(
          child: FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          ),
        );
      },
      child: Text(
        '$value',
        key: ValueKey(value),
        style: style,
      ),
    );
  }
}
