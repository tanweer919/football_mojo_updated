import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/team_crest.dart';
import '../../data/standings_repository.dart';

class GroupStandings extends ConsumerWidget {
  const GroupStandings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(standingsProvider);
    return async.when(
      loading: () => const SkeletonList(itemHeight: 240, count: 3),
      error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(standingsProvider)),
      data: (groups) {
        if (groups.isEmpty) {
          return const EmptyState(
            icon: Icons.table_chart_outlined,
            title: 'Standings not available yet',
            subtitle: 'Group tables populate once group stage starts.',
          );
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          itemCount: groups.length,
          itemBuilder: (_, i) => _Group(group: groups[i], indexInList: i),
        );
      },
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.group, required this.indexInList});
  final StandingsGroup group;
  final int indexInList;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(group.name,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              _Header(),
              const Divider(height: 12),
              ...group.rows.map((r) => _Row(row: r)),
              const SizedBox(height: 8),
              _LegendStrip(),
            ],
          ),
        ),
      ),
    ).animate().fade(duration: 320.ms, delay: (80 * indexInList).ms).slideY(begin: 0.04, end: 0);
  }
}

class _LegendStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _LegendDot(color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text('Auto qualify', style: theme.textTheme.labelSmall),
        const SizedBox(width: 14),
        _LegendDot(color: theme.colorScheme.tertiaryContainer),
        const SizedBox(width: 6),
        Text('Best 3rd contender', style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(width: 10, height: 10,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)));
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700);
    return Row(
      children: [
        SizedBox(width: 24, child: Text('#', style: style, textAlign: TextAlign.center)),
        const SizedBox(width: 6),
        Expanded(child: Text('Team', style: style)),
        SizedBox(width: 28, child: Text('P',  style: style, textAlign: TextAlign.right)),
        SizedBox(width: 28, child: Text('GD', style: style, textAlign: TextAlign.right)),
        SizedBox(width: 32, child: Text('Pts', style: style, textAlign: TextAlign.right)),
      ],
    );
  }
}

enum _Qualification { auto, potential, out }

class _Row extends StatelessWidget {
  const _Row({required this.row});
  final StandingRow row;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = row.position <= 2
        ? _Qualification.auto
        : row.position == 3
            ? _Qualification.potential
            : _Qualification.out;
    final (bgColor, fgColor) = switch (q) {
      _Qualification.auto      => (theme.colorScheme.primary,              theme.colorScheme.onPrimary),
      _Qualification.potential => (theme.colorScheme.tertiaryContainer,    theme.colorScheme.onTertiaryContainer),
      _Qualification.out       => (Colors.transparent,                     theme.colorScheme.onSurface),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 1),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${row.position}',
                  style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: fgColor)),
            ),
          ),
          const SizedBox(width: 8),
          TeamCrest(url: row.teamLogo, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(row.teamName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
          SizedBox(width: 28, child: Text('${row.played}', textAlign: TextAlign.right)),
          SizedBox(width: 28, child: Text(row.gd > 0 ? '+${row.gd}' : '${row.gd}', textAlign: TextAlign.right)),
          SizedBox(
            width: 32,
            child: Text('${row.points}',
                textAlign: TextAlign.right,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800, color: theme.colorScheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ),
        ],
      ),
    );
  }
}
