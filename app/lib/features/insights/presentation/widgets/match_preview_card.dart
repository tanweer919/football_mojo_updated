import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/insights_repository.dart';
import '../../data/models/h2h_dto.dart';
import '../../data/models/match_preview_dto.dart';

/// Two-part match preview: a probability bar (home / draw / away) backed by
/// api-football's statistical model, plus a "last 5 H2H" chip strip.
/// Hidden once the match goes live — predictions are pre-kickoff context.
class MatchPreviewCard extends ConsumerWidget {
  const MatchPreviewCard({
    super.key,
    required this.fixtureId,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeName,
    required this.awayName,
  });

  final String fixtureId;
  final String homeTeamId, awayTeamId;
  final String homeName, awayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(matchPreviewProvider(fixtureId));
    final h2h = ref.watch(h2hProvider((team1: homeTeamId, team2: awayTeamId)));
    final theme = Theme.of(context);

    final hasContent = preview.maybeWhen(data: (v) => v != null, orElse: () => false)
                    || h2h.maybeWhen(data: (v) => v.isNotEmpty, orElse: () => false);
    if (!hasContent) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Match preview',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              preview.when(
                loading: () => const SizedBox(height: 32),
                error: (_, __) => const SizedBox.shrink(),
                data: (p) => p == null
                    ? const SizedBox.shrink()
                    : _ProbabilityBar(
                        preview: p, homeName: homeName, awayName: awayName,
                      ).animate().fade(duration: 320.ms).slideY(begin: 0.04, end: 0),
              ),
              preview.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (p) => (p?.advice == null || p!.advice!.isEmpty)
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.tips_and_updates_outlined, size: 16, color: theme.colorScheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(p.advice!,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            ),
                          ],
                        ),
                      ),
              ),
              h2h.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (rows) {
                  if (rows.isEmpty) return const SizedBox.shrink();
                  final last5 = rows.take(5).toList();
                  return Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recent meetings',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            )),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6, runSpacing: 6,
                          children: last5.map((m) => _H2HChip(match: m, perspectiveTeamId: homeTeamId)).toList(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProbabilityBar extends StatelessWidget {
  const _ProbabilityBar({required this.preview, required this.homeName, required this.awayName});
  final MatchPreviewDto preview;
  final String homeName, awayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = preview.homePercent;
    final d = preview.drawPercent;
    final a = preview.awayPercent;
    return Column(
      children: [
        SizedBox(
          height: 10,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: 520.ms,
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Row(
              children: [
                Expanded(
                  flex: (h * v * 100).round().clamp(1, 999),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(99)),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  flex: (d * v * 100).round().clamp(1, 999),
                  child: Container(color: theme.colorScheme.outlineVariant),
                ),
                const SizedBox(width: 3),
                Expanded(
                  flex: (a * v * 100).round().clamp(1, 999),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiary,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(99)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _Legend(label: homeName, percent: h, color: theme.colorScheme.primary)),
            _Legend(label: 'Draw', percent: d, color: theme.colorScheme.outline, alignCenter: true),
            Expanded(child: _Legend(label: awayName, percent: a, color: theme.colorScheme.tertiary, alignEnd: true)),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.percent, required this.color, this.alignEnd = false, this.alignCenter = false});
  final String label;
  final double percent;
  final Color color;
  final bool alignEnd;
  final bool alignCenter;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txt = Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : alignCenter
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
      children: [
        Text('${percent.toStringAsFixed(0)}%',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
    return alignCenter ? Center(child: txt) : txt;
  }
}

class _H2HChip extends StatelessWidget {
  const _H2HChip({required this.match, required this.perspectiveTeamId});
  final H2HMatchDto match;
  final String perspectiveTeamId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iAmHome = match.homeTeamId == perspectiveTeamId;
    final myScore  = iAmHome ? match.homeScore : match.awayScore;
    final oppScore = iAmHome ? match.awayScore : match.homeScore;
    final result = myScore > oppScore ? _Res.win : myScore < oppScore ? _Res.loss : _Res.draw;
    final (bg, fg, letter) = switch (result) {
      _Res.win  => (theme.colorScheme.primary,             theme.colorScheme.onPrimary,           'W'),
      _Res.draw => (theme.colorScheme.surfaceContainerHigh, theme.colorScheme.onSurfaceVariant,   'D'),
      _Res.loss => (theme.colorScheme.errorContainer,      theme.colorScheme.onErrorContainer,    'L'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(letter,
              style: theme.textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          Text('$myScore-$oppScore',
              style: theme.textTheme.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
        ],
      ),
    );
  }
}

enum _Res { win, draw, loss }
