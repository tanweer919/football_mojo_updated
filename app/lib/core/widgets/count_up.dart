import 'package:flutter/material.dart';

import '../design/motion.dart';

/// Animates a numeric value with a count-up tween. Uses tabular figures so
/// the numbers don't jiggle while ticking.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    this.style,
    this.duration = AppMotion.lg,
    this.fractionDigits = 0,
    this.suffix,
  });

  final num value;
  final TextStyle? style;
  final Duration duration;
  final int fractionDigits;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: AppMotion.swap,
      builder: (_, v, __) {
        final s = '${v.toStringAsFixed(fractionDigits)}${suffix ?? ''}';
        return Text(
          s,
          style: (style ?? Theme.of(context).textTheme.headlineMedium)?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }
}
