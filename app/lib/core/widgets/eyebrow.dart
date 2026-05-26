import 'package:flutter/material.dart';

import '../design/app_colors.dart';

/// `.eyebrow` from `components.css` — small uppercase mono label with wide tracking.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.gold = false, this.color, this.size = 10});
  final String text;
  final bool gold;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'JetBrainsMono',
        fontFamilyFallback: const ['SF Mono', 'Menlo', 'Roboto Mono', 'monospace'],
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: size * 0.16, // matches CSS letter-spacing: 0.16em
        color: color ?? (gold ? AppColors.gold : AppColors.muted),
        height: 1.2,
      ),
    );
  }
}

/// Mono numeric label — used wherever the spec uses `data-num` with tabular nums.
class MonoNum extends StatelessWidget {
  const MonoNum(
    this.text, {
    super.key,
    this.size = 14,
    this.weight = FontWeight.w700,
    this.color,
    this.letterSpacing,
  });
  final String text;
  final double size;
  final FontWeight weight;
  final Color? color;
  final double? letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'JetBrainsMono',
        fontFamilyFallback: const ['SF Mono', 'Menlo', 'Roboto Mono', 'monospace'],
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.fg,
        letterSpacing: letterSpacing,
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1.0,
      ),
    );
  }
}

/// Inline serif italic accent — `<em>` in the spec, used inside display titles.
class SerifItalic extends StatelessWidget {
  const SerifItalic(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style.copyWith(
        fontFamily: 'IowanOldStyle',
        fontFamilyFallback: const ['Charter', 'Georgia', 'Times New Roman', 'serif'],
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
        color: AppColors.gold,
      ),
    );
  }
}
