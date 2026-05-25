import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/repositories/scoring_repository.dart';

/// Shows exactly how a player earned (or lost) points in a gameweek.
/// Maps 1:1 to the backend audit trail — bucket → entries → points.
class PlayerBreakdownScreen extends ConsumerWidget {
  const PlayerBreakdownScreen({super.key, required this.gameweekId, required this.playerId});
  final String gameweekId;
  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(playerBreakdownProvider((gameweekId: gameweekId, playerId: playerId)));
    return Scaffold(
      appBar: AppBar(title: const Text('Score breakdown')),
      body: CenteredContent(
        child: async.when(
          loading: () => const SkeletonList(itemHeight: 64),
          error: (e, _) => ErrorView(
            message: '$e',
            onRetry: () => ref.invalidate(playerBreakdownProvider((gameweekId: gameweekId, playerId: playerId))),
          ),
          data: (b) {
            if (b == null) {
              return const EmptyState(
                icon: Icons.hourglass_empty,
                title: 'Not scored yet',
                subtitle: 'Points appear within minutes after the final whistle.',
              );
            }
            final byBucket = <String, List<PlayerBreakdownEntry>>{};
            for (final e in b.entries) (byBucket[e.bucket] ??= []).add(e);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Hero(breakdown: b),
                const SizedBox(height: 16),
                for (final bucket in const ['allAround', 'decisive', 'position'])
                  if (byBucket[bucket] != null) _BucketSection(
                    title: _bucketName(bucket),
                    total: b.bucketTotals[bucket] ?? 0,
                    entries: byBucket[bucket]!,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _bucketName(String id) => switch (id) {
        'allAround' => 'All-Around',
        'decisive'  => 'Decisive',
        'position'  => 'Position',
        _           => id,
      };
}

class _Hero extends StatelessWidget {
  const _Hero({required this.breakdown});
  final PlayerBreakdown breakdown;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(breakdown.playerName,
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w900)),
                Text('${breakdown.teamName} · ${breakdown.position} · ${breakdown.minutes}\'',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onPrimary.withValues(alpha: 0.85))),
              ],
            ),
          ),
          Text(breakdown.total.toStringAsFixed(1),
              style: theme.textTheme.displaySmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    ).animate().fade(duration: 320.ms).slideY(begin: 0.04, end: 0);
  }
}

class _BucketSection extends StatelessWidget {
  const _BucketSection({required this.title, required this.total, required this.entries});
  final String title;
  final double total;
  final List<PlayerBreakdownEntry> entries;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            Row(
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                Text(
                  total >= 0 ? '+${total.toStringAsFixed(1)}' : total.toStringAsFixed(1),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: total >= 0 ? theme.colorScheme.primary : theme.colorScheme.error,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...entries.asMap().entries.map((mapEntry) {
              final i = mapEntry.key;
              final e = mapEntry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.count > 1 ? '${e.label} (×${e.count})' : e.label,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      e.points >= 0
                          ? '+${e.points.toStringAsFixed(e.points == e.points.roundToDouble() ? 0 : 1)}'
                          : e.points.toStringAsFixed(e.points == e.points.roundToDouble() ? 0 : 1),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w700,
                        color: e.points >= 0 ? theme.colorScheme.primary : theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ).animate().fade(duration: 200.ms, delay: (40 * i.clamp(0, 12)).ms);
            }),
          ],
        ),
      ),
    );
  }
}
