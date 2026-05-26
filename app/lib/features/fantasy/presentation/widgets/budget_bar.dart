import 'package:flutter/material.dart';

import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/motion.dart';

/// Sleek bottom-sheet budget summary. Three live stats with an animated bar.
class BudgetBar extends StatelessWidget {
  const BudgetBar({
    super.key,
    required this.used,
    required this.total,
    required this.squadFilled,
    required this.squadSize,
  });
  final double used;
  final double total;
  final int squadFilled;
  final int squadSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = total <= 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    final over = used > total;
    final remaining = total - used;
    final isComplete = squadFilled == squadSize;

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xxl)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, -6),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _Metric(
                label: 'Squad',
                value: '$squadFilled/$squadSize',
                emphasis: isComplete,
                color: isComplete ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
              const SizedBox(width: AppSpacing.lg),
              _Metric(
                label: 'Spent',
                value: used.toStringAsFixed(1),
                color: over ? theme.colorScheme.error : theme.colorScheme.onSurface,
              ),
              const Spacer(),
              _Metric(
                label: 'Remaining',
                value: remaining.toStringAsFixed(1),
                emphasis: !over,
                color: over ? theme.colorScheme.error : theme.colorScheme.primary,
                alignEnd: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Stack(
              children: [
                Container(
                  height: 10,
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: ratio),
                  duration: AppMotion.md,
                  curve: AppMotion.swap,
                  builder: (_, v, __) => FractionallySizedBox(
                    widthFactor: v,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: over
                              ? [theme.colorScheme.error, theme.colorScheme.errorContainer]
                              : [theme.colorScheme.primary, theme.colorScheme.tertiary],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.emphasis = false,
    this.alignEnd = false,
    this.color,
  });
  final String label;
  final String value;
  final bool emphasis;
  final bool alignEnd;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        AnimatedDefaultTextStyle(
          duration: AppMotion.sm,
          style: theme.textTheme.titleMedium!.copyWith(
            fontWeight: emphasis ? FontWeight.w900 : FontWeight.w800,
            color: color ?? theme.colorScheme.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          child: Text(value),
        ),
      ],
    );
  }
}
