import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/motion.dart';
import '../../../../core/widgets/live_dot.dart';
import '../../../../core/widgets/score_flip.dart';
import '../../../../core/widgets/team_crest.dart';
import '../../../highlights/highlight_link.dart';
import '../../../matches/presentation/widgets/match_share_card.dart';
import '../../../predictions/presentation/widgets/predict_sheet.dart';
import '../../data/models/match_dto.dart';

/// Premium match card. Live state gets a red status pill + score flip; finished
/// state shows the final score quietly; scheduled state shows kickoff time.
class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, this.indexInList = 0});
  final MatchDto match;
  final int indexInList;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPredict = !match.isLive &&
        !match.isFinished &&
        match.kickoffAt.isAfter(DateTime.now());
    final isLive = match.isLive;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: isLive
              ? theme.colorScheme.error.withValues(alpha: 0.45)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: isLive ? 1.4 : 1,
        ),
        boxShadow: isLive
            ? [
                BoxShadow(
                  color: theme.colorScheme.error.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/matches/${match.id}'),
          // Long-press to share a branded graphic of this fixture
          // (live/finished show the score, upcoming generates hype).
          onLongPress: () => shareMatchGraphic(context, match),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md, horizontal: AppSpacing.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    _StatusPill(match: match),
                    if (match.stage != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        match.stage!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (match.hasHighlight) HighlightChip(match: match, dense: true),
                    if (canPredict)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Predict the score',
                        icon: const Icon(Icons.psychology_alt_outlined, size: 20),
                        onPressed: () => showPredictSheet(
                          context,
                          matchId: match.id,
                          homeName: match.homeTeam.shortName ?? match.homeTeam.name,
                          awayName: match.awayTeam.shortName ?? match.awayTeam.name,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _TeamSide(
                        team: match.homeTeam,
                        alignEnd: false,
                        heroTag: 'home-${match.id}',
                      ),
                    ),
                    _Score(match: match),
                    Expanded(
                      child: _TeamSide(
                        team: match.awayTeam,
                        alignEnd: true,
                        heroTag: 'away-${match.id}',
                      ),
                    ),
                  ],
                ),
                if (match.venue != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.place_outlined,
                          size: 12, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        match.venue!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fade(
            duration: AppMotion.md,
            curve: AppMotion.enter,
            delay: (40 * indexInList).ms)
        .slideY(
            begin: 0.06,
            end: 0,
            duration: AppMotion.md,
            curve: AppMotion.enter,
            delay: (40 * indexInList).ms);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.match});
  final MatchDto match;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final live = match.isLive;
    final finished = match.isFinished;

    final label = live
        ? (match.status == MatchStatus.HALF_TIME ? 'HT' : match.minuteLabel)
        : finished
            ? 'FT'
            : DateFormat('EEE • h:mm a').format(match.kickoffAt.toLocal());

    final color = live
        ? theme.colorScheme.error
        : finished
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live) ...[
            const LiveDot(size: 7),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamSide extends StatelessWidget {
  const _TeamSide({
    required this.team,
    required this.alignEnd,
    required this.heroTag,
  });
  final TeamDto team;
  final bool alignEnd;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crest = Hero(tag: heroTag, child: TeamCrest(url: team.crestUrl, size: 36));
    final name = Flexible(
      child: Text(
        team.shortName ?? team.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
    return Row(
      mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignEnd
          ? [name, const SizedBox(width: 10), crest]
          : [crest, const SizedBox(width: 10), name],
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.match});
  final MatchDto match;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showScore = match.isLive || match.isFinished;
    if (!showScore) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Text(
          'vs',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ScoreFlip(
            value: match.homeScore,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          Container(
            width: 4, height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          ScoreFlip(
            value: match.awayScore,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
