import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../insights/data/insights_repository.dart';
import '../../../insights/data/models/match_event_dto.dart';

/// Centre-axis timeline. Home events appear on the left, away on the right.
class MatchEventsTab extends ConsumerWidget {
  const MatchEventsTab({super.key, required this.matchId, required this.homeTeamId});
  final String matchId;
  final String homeTeamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(matchEventsProvider(matchId));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(matchEventsProvider(matchId)),
      child: async.when(
        loading: () => const SkeletonList(itemHeight: 60),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(matchEventsProvider(matchId))),
        data: (events) {
          if (events.isEmpty) {
            return const EmptyState(
              icon: Icons.timeline_outlined,
              title: 'No events yet',
              subtitle: 'Goals, cards and subs will land here in real time.',
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) => _Row(event: events[i], isHome: events[i].teamId == homeTeamId, indexInList: i),
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.event, required this.isHome, required this.indexInList});
  final MatchEventDto event;
  final bool isHome;
  final int indexInList;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cell = _Cell(event: event, alignEnd: !isHome);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(child: isHome ? cell : const SizedBox.shrink()),
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(event.displayMinute,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ),
          Expanded(child: !isHome ? cell : const SizedBox.shrink()),
        ],
      ),
    ).animate().fade(duration: 220.ms, delay: (35 * indexInList.clamp(0, 16)).ms).slideY(begin: 0.04, end: 0);
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.event, required this.alignEnd});
  final MatchEventDto event;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ic = _iconFor(event.kind);
    final color = _colorFor(event.kind, theme);
    final main = event.playerName ?? event.detail;
    final sub = event.kind == EventKind.sub
        ? (event.assistName != null ? '↓ ${event.assistName}' : null)
        : (event.kind == EventKind.goal && event.assistName != null ? 'assist: ${event.assistName}' : null);

    final body = Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(main,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        if (sub != null)
          Text(sub,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );

    final children = <Widget>[
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(ic, size: 16, color: color),
      ),
      const SizedBox(width: 8),
      Flexible(child: body),
    ];
    return Row(
      mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignEnd ? children.reversed.toList() : children,
    );
  }

  IconData _iconFor(EventKind k) => switch (k) {
        EventKind.goal           => Icons.sports_soccer,
        EventKind.ownGoal        => Icons.replay,
        EventKind.penalty        => Icons.sports_soccer,
        EventKind.penaltyMissed  => Icons.do_disturb_alt_outlined,
        EventKind.yellow         => Icons.square,
        EventKind.red            => Icons.square,
        EventKind.sub            => Icons.swap_horiz,
        EventKind.varCheck       => Icons.tv_outlined,
        EventKind.unknown        => Icons.circle_outlined,
      };

  Color _colorFor(EventKind k, ThemeData t) => switch (k) {
        EventKind.goal          => t.colorScheme.primary,
        EventKind.ownGoal       => t.colorScheme.error,
        EventKind.penalty       => t.colorScheme.primary,
        EventKind.penaltyMissed => t.colorScheme.error,
        EventKind.yellow        => const Color(0xFFE6B800),
        EventKind.red           => t.colorScheme.error,
        EventKind.sub           => t.colorScheme.tertiary,
        EventKind.varCheck      => t.colorScheme.onSurfaceVariant,
        EventKind.unknown       => t.colorScheme.outline,
      };
}
