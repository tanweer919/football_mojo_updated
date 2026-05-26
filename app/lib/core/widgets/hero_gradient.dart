import 'package:flutter/material.dart';

import '../design/app_gradients.dart';
import '../design/app_spacing.dart';

/// Full-bleed hero container with a curated gradient + soft floodlight overlay.
/// Used on the home dashboard hero strip and the fantasy tournament hero.
class HeroGradientCard extends StatelessWidget {
  const HeroGradientCard({
    super.key,
    required this.child,
    this.gradient,
    this.padding = const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xl),
    this.borderRadius,
    this.height,
    this.useFloodlight = true,
  });

  final Widget child;
  final LinearGradient? gradient;
  final EdgeInsets padding;
  final BorderRadius? borderRadius;
  final double? height;
  final bool useFloodlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(AppRadii.xxl);
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: gradient ?? AppGradients.hero(scheme),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (useFloodlight)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppGradients.floodlight),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
