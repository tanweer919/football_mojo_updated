import 'dart:ui';

import 'package:flutter/material.dart';

import '../design/app_spacing.dart';

/// Frosted-glass card. Uses BackdropFilter — only render on top of imagery
/// or gradients, otherwise it's just a tinted box.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.borderRadius,
    this.tint,
    this.borderColor,
    this.blur = 18,
  });

  final Widget child;
  final EdgeInsets padding;
  final BorderRadius? borderRadius;
  final Color? tint;
  final Color? borderColor;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadii.xl);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint ?? Colors.white.withValues(alpha: 0.10),
            borderRadius: radius,
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
