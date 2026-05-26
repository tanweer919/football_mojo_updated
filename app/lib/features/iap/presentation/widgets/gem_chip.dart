import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../data/gems_repository.dart';

/// Compact gem balance chip — drop into app bars / home top strip.
/// Tap routes to the wallet screen.
class GemChip extends ConsumerWidget {
  const GemChip({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bal = ref.watch(gemBalanceProvider);
    final amount = bal.maybeWhen(data: (b) => b.balance, orElse: () => null);
    final canClaim = bal.maybeWhen(data: (b) => b.canClaimDaily, orElse: () => false);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => context.push(RoutePaths.wallet),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.diamond_rounded,
                  size: compact ? 14 : 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                amount == null ? '—' : '$amount',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (canClaim) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
