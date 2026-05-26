import 'package:flutter/material.dart';

import '../design/app_spacing.dart';

/// Small inline stat: icon + label + value. Used in match cards, lineup
/// summary, player profile.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: compact ? 4 : AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: c.withValues(alpha: 0.20), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: c),
          SizedBox(width: compact ? 4 : 6),
          Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: c,
              fontSize: compact ? 11 : 12,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: c.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
