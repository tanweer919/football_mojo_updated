import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../insights/data/insights_repository.dart';
import '../../../insights/data/models/match_stats_dto.dart';

/// Rendered from /v1/insights/match-statistics/:id. Rows displayed in a sensible
/// fixed order so the screen layout doesn't shuffle as values populate live.
class MatchStatsTab extends ConsumerWidget {
  const MatchStatsTab({super.key, required this.matchId});
  final String matchId;

  static const _ordered = <_Row>[
    _Row('Ball Possession',  isPercent: true),
    _Row('Total Shots'),
    _Row('Shots on Goal'),
    _Row('Shots off Goal'),
    _Row('Blocked Shots'),
    _Row('Shots insidebox',  display: 'Shots inside box'),
    _Row('Shots outsidebox', display: 'Shots outside box'),
    _Row('Corner Kicks'),
    _Row('Offsides'),
    _Row('Fouls'),
    _Row('Yellow Cards'),
    _Row('Red Cards'),
    _Row('Goalkeeper Saves', display: 'Saves'),
    _Row('Total passes',     display: 'Passes'),
    _Row('Passes accurate',  display: 'Accurate passes'),
    _Row('Passes %',         display: 'Pass accuracy', isPercent: true),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(matchStatsProvider(matchId));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(matchStatsProvider(matchId)),
      child: async.when(
        loading: () => const SkeletonList(itemHeight: 56),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(matchStatsProvider(matchId))),
        data: (teams) {
          if (teams.length != 2) {
            return const EmptyState(
              icon: Icons.bar_chart_outlined,
              title: 'Stats not available yet',
              subtitle: 'Match statistics appear shortly after kickoff.',
            );
          }
          final home = teams[0];
          final away = teams[1];
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: _ordered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) => _StatBar(home: home, away: away, row: _ordered[i], indexInList: i),
          );
        },
      ),
    );
  }
}

class _Row {
  const _Row(this.key, {this.display, this.isPercent = false});
  final String key;
  final String? display;
  final bool isPercent;
  String get label => display ?? key;
}

class _StatBar extends StatelessWidget {
  const _StatBar({required this.home, required this.away, required this.row, required this.indexInList});
  final TeamMatchStatsDto home;
  final TeamMatchStatsDto away;
  final _Row row;
  final int indexInList;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = home[row.key]?.toDouble() ?? 0;
    final a = away[row.key]?.toDouble() ?? 0;
    final total = h + a;
    final hRatio = total <= 0 ? 0.5 : h / total;

    String format(double v) => row.isPercent ? '${v.toStringAsFixed(0)}%' : v.toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(format(h),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
            Expanded(
              child: Center(
                child: Text(row.label,
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            ),
            Text(format(a),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 8,
          child: Row(
            children: [
              Expanded(
                flex: (hRatio * 1000).round().clamp(1, 999),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: 520.ms,
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => FractionallySizedBox(
                    widthFactor: v,
                    alignment: Alignment.centerRight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(99)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: ((1 - hRatio) * 1000).round().clamp(1, 999),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: 520.ms,
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => FractionallySizedBox(
                    widthFactor: v,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiary,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(99)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fade(duration: 240.ms, delay: (40 * indexInList.clamp(0, 12)).ms).slideY(begin: 0.04, end: 0);
  }
}
