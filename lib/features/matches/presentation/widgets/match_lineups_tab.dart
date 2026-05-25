import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../insights/data/insights_repository.dart';
import '../../../insights/data/models/lineup_dto.dart';

/// Renders each team's lineup as a painted pitch positioned by api-football's
/// "row:col" grid. Substitutes listed as chips below the pitch.
class MatchLineupsTab extends ConsumerWidget {
  const MatchLineupsTab({super.key, required this.matchId});
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(matchLineupsProvider(matchId));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(matchLineupsProvider(matchId)),
      child: async.when(
        loading: () => const SkeletonList(itemHeight: 280),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(matchLineupsProvider(matchId))),
        data: (lineups) {
          if (lineups.isEmpty) {
            return const EmptyState(
              icon: Icons.group_outlined,
              title: 'Line-ups not announced',
              subtitle: 'Confirmed teams appear about an hour before kickoff.',
            );
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            children: [
              for (int i = 0; i < lineups.length; i++) _LineupBlock(lineup: lineups[i], indexInList: i),
            ],
          );
        },
      ),
    );
  }
}

class _LineupBlock extends StatelessWidget {
  const _LineupBlock({required this.lineup, required this.indexInList});
  final LineupDto lineup;
  final int indexInList;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(lineup.teamName,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              if (lineup.formation.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(lineup.formation,
                      style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800, color: theme.colorScheme.onPrimaryContainer)),
                ),
            ],
          ),
          if (lineup.coachName != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Coach: ${lineup.coachName}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          const SizedBox(height: 10),
          _Pitch(players: lineup.startXI),
          if (lineup.substitutes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Bench', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8, runSpacing: 6,
              children: [for (final p in lineup.substitutes) _SubChip(player: p)],
            ),
          ],
        ],
      ),
    ).animate().fade(duration: 320.ms, delay: (140 * indexInList).ms).slideY(begin: 0.04, end: 0);
  }
}

class _Pitch extends StatelessWidget {
  const _Pitch({required this.players});
  final List<LineupPlayer> players;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byRow = <int, List<LineupPlayer>>{};
    int maxRow = 1;
    for (final p in players) {
      final r = p.row ?? 1;
      byRow.putIfAbsent(r, () => []).add(p);
      if (r > maxRow) maxRow = r;
    }
    for (final list in byRow.values) {
      list.sort((a, b) => (a.col ?? 0).compareTo(b.col ?? 0));
    }
    // Row 1 = goalkeeper; render top-to-bottom with attackers at the top.
    final rowsTopToBottom = List.generate(maxRow, (i) => maxRow - i)
        .map((r) => byRow[r] ?? const <LineupPlayer>[])
        .toList();

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: CustomPaint(
        painter: _PitchPainter(theme.colorScheme),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              for (final row in rowsTopToBottom)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: row.map((p) => _PlayerDot(player: p)).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerDot extends StatelessWidget {
  const _PlayerDot({required this.player});
  final LineupPlayer player;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 68,
      child: InkWell(
        onTap: player.id.isEmpty ? null : () => context.push('/players/${player.id}'),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.primary, width: 2),
              boxShadow: [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.15), blurRadius: 8)],
            ),
            alignment: Alignment.center,
            child: Text('${player.number ?? ''}',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(player.displayName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      ),
    );
  }
}

class _SubChip extends StatelessWidget {
  const _SubChip({required this.player});
  final LineupPlayer player;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (player.number != null)
            Text('${player.number}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800)),
          if (player.number != null) const SizedBox(width: 6),
          Text(player.displayName, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  _PitchPainter(this.scheme);
  final ColorScheme scheme;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Paint()
      ..shader = LinearGradient(
        colors: [scheme.primary.withValues(alpha: 0.18), scheme.tertiary.withValues(alpha: 0.10)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(rect);
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(24));
    canvas.drawRRect(r, base);
    final line = Paint()
      ..color = scheme.onSurface.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(6), const Radius.circular(20)), line);
    canvas.drawLine(Offset(6, size.height / 2), Offset(size.width - 6, size.height / 2), line);
    canvas.drawCircle(rect.center, size.width * 0.10, line);
  }
  @override
  bool shouldRepaint(_) => false;
}
